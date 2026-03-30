#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
XRAY_SOCKS_PROXY="socks5://127.0.0.1:10808"
XRAY_HTTP_PROXY="http://127.0.0.1:10809"
XRAY_NO_PROXY="127.0.0.1,localhost,::1"

WITH_XRAY=0
TARGET_USER=""
TARGET_HOME=""
IS_ROOT_TARGET=0

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

usage() {
  cat <<'EOF'
Usage:
  sudo ./bootstrap.sh [--with-xray]

Options:
  --with-xray   Install and enable Xray proxy.
  -h, --help    Show this help message.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --with-xray)
        WITH_XRAY=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
    shift
  done
}

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run this script with sudo or as root." >&2
    exit 1
  fi
}

detect_target() {
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    TARGET_USER="${SUDO_USER}"
    TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
  else
    TARGET_USER="root"
    TARGET_HOME="/root"
    IS_ROOT_TARGET=1
  fi

  if [[ -z "${TARGET_HOME}" || ! -d "${TARGET_HOME}" ]]; then
    echo "Unable to determine home directory for ${TARGET_USER}." >&2
    exit 1
  fi
}

apt_install_if_available() {
  local package="$1"
  if apt-cache show "$package" >/dev/null 2>&1; then
    apt-get install -y "$package"
  else
    log "Skipping unavailable package: $package"
  fi
}

run_as_target_user() {
  if [[ "${IS_ROOT_TARGET}" -eq 1 ]]; then
    "$@"
  else
    sudo -u "${TARGET_USER}" -H "$@"
  fi
}

proxy_env_args() {
  cat <<EOF
http_proxy=${XRAY_HTTP_PROXY}
https_proxy=${XRAY_HTTP_PROXY}
HTTP_PROXY=${XRAY_HTTP_PROXY}
HTTPS_PROXY=${XRAY_HTTP_PROXY}
all_proxy=${XRAY_SOCKS_PROXY}
ALL_PROXY=${XRAY_SOCKS_PROXY}
no_proxy=${XRAY_NO_PROXY}
NO_PROXY=${XRAY_NO_PROXY}
EOF
}

run_as_target_user_with_proxy() {
  mapfile -t proxy_env < <(proxy_env_args)

  if [[ "${IS_ROOT_TARGET}" -eq 1 ]]; then
    env "${proxy_env[@]}" "$@"
  else
    sudo -u "${TARGET_USER}" -H env "${proxy_env[@]}" "$@"
  fi
}

run_as_target_user_for_network() {
  if [[ "${WITH_XRAY}" -eq 1 ]]; then
    run_as_target_user_with_proxy "$@"
  else
    run_as_target_user "$@"
  fi
}

wait_for_xray_proxy() {
  local attempts=30
  local sleep_seconds=1
  local socks_port=10808
  local http_port=10809

  if ! command -v ss >/dev/null 2>&1; then
    log "Skipping Xray readiness check: ss not available"
    return 0
  fi

  for ((i = 1; i <= attempts; i++)); do
    if ss -ltn '( sport = :10808 or sport = :10809 )' 2>/dev/null | grep -q "127.0.0.1:${socks_port}" &&
      ss -ltn '( sport = :10808 or sport = :10809 )' 2>/dev/null | grep -q "127.0.0.1:${http_port}"; then
      log "Xray proxy ports are ready"
      return 0
    fi

    sleep "${sleep_seconds}"
  done

  echo "Timed out waiting for Xray proxy ports ${socks_port} and ${http_port}." >&2
  exit 1
}

export_proxy_env() {
  while IFS= read -r env_var; do
    export "${env_var}"
  done < <(proxy_env_args)
}

zsh_proxy_block() {
  if [[ "${WITH_XRAY}" -ne 1 ]]; then
    return 0
  fi

  cat <<'EOF'
# Network proxy
export http_proxy="http://127.0.0.1:10809"
export https_proxy="http://127.0.0.1:10809"
export all_proxy="socks5://127.0.0.1:10808"
export no_proxy="127.0.0.1,localhost,::1"

# Uppercase variants for tools that expect them.
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"
export ALL_PROXY="$all_proxy"
export NO_PROXY="$no_proxy"

EOF
}

install_xray() {
  local xray_source_dir="${SCRIPT_DIR}/xray"
  local xray_binary_source="${xray_source_dir}/xray"
  local xray_service_source="${xray_source_dir}/xray.service"
  local xray_config_source="${xray_source_dir}/config.json"
  local xray_config_dir="/usr/local/etc/xray"
  local xray_asset_dir="/usr/local/share/xray"

  if [[ ! -d "${xray_source_dir}" ]]; then
    echo "Xray directory not found: ${xray_source_dir}" >&2
    exit 1
  fi

  if [[ ! -f "${xray_binary_source}" || ! -f "${xray_service_source}" || ! -f "${xray_config_source}" ]]; then
    echo "Missing required Xray files in ${xray_source_dir}." >&2
    exit 1
  fi

  log "Installing Xray files"
  install -d -m 0755 "${xray_config_dir}" "${xray_asset_dir}"
  install -m 0755 "${xray_binary_source}" /usr/local/bin/xray
  install -m 0644 "${xray_config_source}" "${xray_config_dir}/config.json"

  for asset in geoip.dat geosite.dat; do
    if [[ -f "${xray_source_dir}/${asset}" ]]; then
      install -m 0644 "${xray_source_dir}/${asset}" "${xray_asset_dir}/${asset}"
    fi
  done

  install -m 0644 "${xray_service_source}" /etc/systemd/system/xray.service

  if command -v systemctl >/dev/null 2>&1; then
    log "Registering Xray systemd service"
    systemctl daemon-reload
    systemctl enable xray
    systemctl restart xray
  else
    log "Skipping Xray service registration: systemctl not available"
  fi
}

configure_xray_if_requested() {
  if [[ "${WITH_XRAY}" -ne 1 ]]; then
    return 0
  fi

  install_xray
  wait_for_xray_proxy
  export_proxy_env
}

install_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    if [[ ! -f /etc/os-release ]]; then
      log "Skipping Docker install: /etc/os-release not found"
      return 0
    fi

    . /etc/os-release
    case "${ID:-}" in
      debian|ubuntu)
        ;;
      *)
        log "Skipping Docker install on unsupported distro: ${ID:-unknown}"
        return 0
        ;;
    esac

    log "Installing Docker"
    apt-get install -y ca-certificates curl
    install -d -m 0755 /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    local arch codename
    arch="$(dpkg --print-architecture)"
    codename="${VERSION_CODENAME:-}"
    if [[ -z "${codename}" ]]; then
      echo "Unable to detect distribution codename for Docker repo." >&2
      exit 1
    fi

    cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${ID} ${codename} stable
EOF

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    if command -v systemctl >/dev/null 2>&1; then
      systemctl enable --now docker
    fi
  else
    log "Docker already installed"
  fi

  if [[ "${IS_ROOT_TARGET}" -eq 0 ]] && getent group docker >/dev/null 2>&1; then
    usermod -aG docker "${TARGET_USER}"
  fi
}

install_lazydocker() {
  if command -v lazydocker >/dev/null 2>&1; then
    log "lazydocker already installed"
    return 0
  fi

  local arch archive_arch version latest_api tmp_dir
  arch="$(dpkg --print-architecture)"

  case "${arch}" in
    amd64)
      archive_arch="x86_64"
      ;;
    arm64)
      archive_arch="arm64"
      ;;
    armhf)
      archive_arch="armv7"
      ;;
    *)
      log "Skipping lazydocker install on unsupported architecture: ${arch}"
      return 0
      ;;
  esac

  latest_api="https://api.github.com/repos/jesseduffield/lazydocker/releases/latest"
  version="$(curl -fsSL "${latest_api}" | sed -n 's/.*"tag_name":[[:space:]]*"v\([^"]*\)".*/\1/p' | head -n1)"
  if [[ -z "${version}" ]]; then
    echo "Unable to determine latest lazydocker version." >&2
    exit 1
  fi

  tmp_dir="$(mktemp -d)"

  log "Installing lazydocker ${version}"
  curl -fsSL \
    "https://github.com/jesseduffield/lazydocker/releases/download/v${version}/lazydocker_${version}_Linux_${archive_arch}.tar.gz" \
    -o "${tmp_dir}/lazydocker.tar.gz"
  tar -xzf "${tmp_dir}/lazydocker.tar.gz" -C "${tmp_dir}" lazydocker
  install -m 0755 "${tmp_dir}/lazydocker" /usr/local/bin/lazydocker
  rm -rf "${tmp_dir}"
}

install_lazygit() {
  if command -v lazygit >/dev/null 2>&1; then
    log "lazygit already installed"
    return 0
  fi

  local arch archive_arch version latest_api tmp_dir
  arch="$(dpkg --print-architecture)"

  case "${arch}" in
    amd64)
      archive_arch="x86_64"
      ;;
    arm64)
      archive_arch="arm64"
      ;;
    armhf)
      archive_arch="armv6"
      ;;
    *)
      log "Skipping lazygit install on unsupported architecture: ${arch}"
      return 0
      ;;
  esac

  latest_api="https://api.github.com/repos/jesseduffield/lazygit/releases/latest"
  version="$(curl -fsSL "${latest_api}" | sed -n 's/.*"tag_name":[[:space:]]*"v\([^"]*\)".*/\1/p' | head -n1)"
  if [[ -z "${version}" ]]; then
    echo "Unable to determine latest lazygit version." >&2
    exit 1
  fi

  tmp_dir="$(mktemp -d)"

  log "Installing lazygit ${version}"
  curl -fsSL \
    "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_${archive_arch}.tar.gz" \
    -o "${tmp_dir}/lazygit.tar.gz"
  tar -xzf "${tmp_dir}/lazygit.tar.gz" -C "${tmp_dir}" lazygit
  install -m 0755 "${tmp_dir}/lazygit" /usr/local/bin/lazygit
  rm -rf "${tmp_dir}"
}

install_uv() {
  if run_as_target_user command -v uv >/dev/null 2>&1; then
    return 0
  fi

  log "Installing uv for ${TARGET_USER}"
  if [[ "${IS_ROOT_TARGET}" -eq 1 ]]; then
    run_as_target_user_for_network env HOME=/root sh -c "$(curl -fsSL https://astral.sh/uv/install.sh)"
  else
    run_as_target_user_for_network sh -c "$(curl -fsSL https://astral.sh/uv/install.sh)"
  fi
}

install_fnm() {
  if run_as_target_user command -v fnm >/dev/null 2>&1; then
    return 0
  fi

  log "Installing fnm for ${TARGET_USER}"
  run_as_target_user_for_network env SHELL=/usr/bin/zsh bash -c "$(curl -fsSL https://fnm.vercel.app/install)"
}

install_node_with_fnm() {
  log "Installing Node.js 24 and enabling corepack for ${TARGET_USER}"
  run_as_target_user_for_network env PATH="${TARGET_HOME}/.local/share/fnm:${TARGET_HOME}/.local/bin:${PATH}" \
    bash -lc '
      export FNM_PATH="$HOME/.local/share/fnm"
      export PATH="$FNM_PATH:$PATH"
      eval "$(fnm env --shell bash)"
      fnm install 24
      fnm default 24
      corepack enable
    '
}

install_oh_my_zsh() {
  if [[ -d "${TARGET_HOME}/.oh-my-zsh" ]]; then
    return 0
  fi

  log "Installing oh-my-zsh for ${TARGET_USER}"
  run_as_target_user_for_network env RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

install_user_scripts() {
  if [[ "${IS_ROOT_TARGET}" -eq 1 ]]; then
    return 0
  fi

  local script_source="${SCRIPT_DIR}/xray/update-xray-geofiles"
  local script_target_dir="${TARGET_HOME}/.local/bin"
  local script_target="${script_target_dir}/update-xray-geofiles"

  if [[ ! -f "${script_source}" ]]; then
    log "Skipping user script install: ${script_source} not found"
    return 0
  fi

  install -d -m 0755 "${script_target_dir}"
  install -m 0755 "${script_source}" "${script_target}"
  chown "${TARGET_USER}:${TARGET_USER}" "${script_target}"
}

write_target_zshrc() {
  local zshrc_path="${TARGET_HOME}/.zshrc"
  local proxy_block

  proxy_block="$(zsh_proxy_block)"

  cat >"${zshrc_path}" <<EOF
${proxy_block}
# Editor settings
alias nano="\$(command -v nano)"
export VISUAL=nano
export EDITOR=nano

# User-local binaries (include uv/uvx).
export PATH="\$HOME/.local/bin:\$PATH"

# pnpm global bin directory.
export PNPM_HOME="\$HOME/.local/share/pnpm"
case ":\$PATH:" in
  *":\$PNPM_HOME:"*) ;;
  *) export PATH="\$PNPM_HOME:\$PATH" ;;
esac

# fnm
export FNM_PATH="\$HOME/.local/share/fnm"
export PATH="\$FNM_PATH:\$PATH"
eval "\$(fnm env --use-on-cd --shell zsh)"

# oh-my-zsh
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="candy"
plugins=(git)

source "\$ZSH/oh-my-zsh.sh"

autoload -Uz add-zsh-hook
_newline_precmd() { print; }
add-zsh-hook precmd _newline_precmd

# uv / uvx completion.
eval "\$(uv generate-shell-completion zsh)"
eval "\$(uvx --generate-shell-completion zsh)"

# zoxide
eval "\$(zoxide init zsh)"

# eza
alias ls="eza --icons"
alias ll="eza -l --icons"
alias la="eza -la --icons"
alias tree="eza --tree"

# fd
alias fd="fdfind"

# directory
alias j="z"
alias ji="zi"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

# utils
alias c="clear"
alias h="history"

# zsh-autosuggestions
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# zsh-syntax-highlighting
# Keep this near the end of .zshrc so it can observe final widgets/bindings.
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
EOF

  if [[ "${IS_ROOT_TARGET}" -eq 0 ]]; then
    chown "${TARGET_USER}:${TARGET_USER}" "${zshrc_path}"
  fi
}

main() {
  parse_args "$@"
  require_root
  detect_target

  if ! command -v apt-get >/dev/null 2>&1; then
    echo "This script currently supports Debian/Ubuntu only." >&2
    exit 1
  fi

  export DEBIAN_FRONTEND=noninteractive

  configure_xray_if_requested

  log "Updating apt cache"
  apt-get update

  log "Installing base packages"
  apt-get install -y btop ca-certificates curl eza fd-find fzf git jq nano ripgrep wget zoxide zsh unzip
  apt-get install -y zsh-autosuggestions zsh-syntax-highlighting

  install_docker
  install_lazydocker
  install_lazygit
  install_uv
  install_fnm
  install_node_with_fnm
  install_oh_my_zsh
  install_user_scripts
  write_target_zshrc

  log "Setting ${TARGET_USER} shell to zsh"
  chsh -s /usr/bin/zsh "${TARGET_USER}"

  if [[ "${IS_ROOT_TARGET}" -eq 1 ]]; then
    log "Root shell setup complete"
    printf '\nNext step:\n'
  else
    log "User shell setup complete"
    printf '\nNext steps:\n'
    printf '  newgrp docker   # optional, if you want Docker group changes immediately\n'
  fi
  printf '  exec zsh\n'
}

main "$@"
