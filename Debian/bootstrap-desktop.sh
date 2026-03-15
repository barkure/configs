#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
XRAY_SOCKS_PROXY="socks5://127.0.0.1:10808"
XRAY_HTTP_PROXY="http://127.0.0.1:10809"
XRAY_NO_PROXY="127.0.0.1,localhost,::1"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run this script with sudo or as root." >&2
    exit 1
  fi
}

require_target_user() {
  if [[ -z "${SUDO_USER:-}" || "${SUDO_USER}" == "root" ]]; then
    cat >&2 <<'EOF'
Unable to detect the local user.
Run this script with sudo from the user account you want to configure, for example:
  sudo ./bootstrap-desktop.sh
EOF
    exit 1
  fi

  TARGET_USER="${SUDO_USER}"
  TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"

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
  sudo -u "${TARGET_USER}" -H "$@"
}

run_as_target_user_with_proxy() {
  sudo -u "${TARGET_USER}" -H env \
    http_proxy="${XRAY_HTTP_PROXY}" \
    https_proxy="${XRAY_HTTP_PROXY}" \
    HTTP_PROXY="${XRAY_HTTP_PROXY}" \
    HTTPS_PROXY="${XRAY_HTTP_PROXY}" \
    all_proxy="${XRAY_SOCKS_PROXY}" \
    ALL_PROXY="${XRAY_SOCKS_PROXY}" \
    no_proxy="${XRAY_NO_PROXY}" \
    NO_PROXY="${XRAY_NO_PROXY}" \
    "$@"
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
  export http_proxy="${XRAY_HTTP_PROXY}"
  export https_proxy="${XRAY_HTTP_PROXY}"
  export HTTP_PROXY="${XRAY_HTTP_PROXY}"
  export HTTPS_PROXY="${XRAY_HTTP_PROXY}"
  export all_proxy="${XRAY_SOCKS_PROXY}"
  export ALL_PROXY="${XRAY_SOCKS_PROXY}"
  export no_proxy="${XRAY_NO_PROXY}"
  export NO_PROXY="${XRAY_NO_PROXY}"
}

install_xray() {
  local xray_source_dir="${SCRIPT_DIR}/xray"
  local xray_binary_source="${xray_source_dir}/xray"
  local xray_service_source="${xray_source_dir}/xray.service"
  local xray_config_dir="/etc/xray"
  local xray_asset_dir="/usr/local/share/xray"

  if [[ ! -d "${xray_source_dir}" ]]; then
    log "Skipping Xray setup: ${xray_source_dir} not found"
    return 0
  fi

  if [[ ! -f "${xray_binary_source}" || ! -f "${xray_service_source}" ]]; then
    log "Skipping Xray setup: required files are missing in ${xray_source_dir}"
    return 0
  fi

  log "Installing Xray files"
  install -d -m 0755 "${xray_config_dir}" "${xray_asset_dir}"
  install -m 0755 "${xray_binary_source}" /usr/local/bin/xray

  if [[ -f "${xray_source_dir}/config.json" ]]; then
    install -m 0644 "${xray_source_dir}/config.json" "${xray_config_dir}/config.json"
  fi

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

  if getent group docker >/dev/null 2>&1; then
    usermod -aG docker "${TARGET_USER}"
  fi
}

install_uv() {
  if run_as_target_user command -v uv >/dev/null 2>&1; then
    return 0
  fi

  log "Installing uv for ${TARGET_USER}"
  run_as_target_user_with_proxy sh -c "$(curl -fsSL https://astral.sh/uv/install.sh)"
}

install_fnm() {
  if run_as_target_user command -v fnm >/dev/null 2>&1; then
    return 0
  fi

  log "Installing fnm for ${TARGET_USER}"
  run_as_target_user_with_proxy SHELL=/usr/bin/zsh bash -c "$(curl -fsSL https://fnm.vercel.app/install)"
}

install_node_with_fnm() {
  log "Installing Node.js 24 and enabling corepack for ${TARGET_USER}"
  run_as_target_user_with_proxy PATH="${TARGET_HOME}/.local/share/fnm:${TARGET_HOME}/.local/bin:${PATH}" \
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
  run_as_target_user env RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

install_user_scripts() {
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

write_zshrc() {
  cat >"${TARGET_HOME}/.zshrc" <<'EOF'
# Editor settings
if command -v nano >/dev/null 2>&1; then
  alias nano="$(command -v nano)"
  export VISUAL=nano
  export EDITOR=nano
fi

# Network proxy
export http_proxy="http://127.0.0.1:10809"
export https_proxy="http://127.0.0.1:10809"
export all_proxy="socks5://127.0.0.1:10808"

# Uppercase variants for tools that expect them.
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"
export ALL_PROXY="socks5://127.0.0.1:10808"
export no_proxy="127.0.0.1,localhost,::1"
export NO_PROXY="127.0.0.1,localhost,::1"

# User-local binaries (include uv/uvx).
export PATH="$HOME/.local/bin:$PATH"

# fnm
export FNM_PATH="$HOME/.local/share/fnm"
if [[ -d "$FNM_PATH" ]]; then
  export PATH="$FNM_PATH:$PATH"
fi

# oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="candy"
plugins=(git)

source "$ZSH/oh-my-zsh.sh"

autoload -Uz add-zsh-hook
_newline_precmd() { print; }
add-zsh-hook precmd _newline_precmd

# uv / uvx completion.
if command -v uv >/dev/null 2>&1; then
  eval "$(uv generate-shell-completion zsh)"
fi
if command -v uvx >/dev/null 2>&1; then
  eval "$(uvx --generate-shell-completion zsh)"
fi

# fnm: auto-switch Node version on directory change.
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# zoxide
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# eza
if command -v eza >/dev/null 2>&1; then
  alias ls="eza --icons"
  alias ll="eza -l --icons"
  alias la="eza -la --icons"
  alias tree="eza --tree"
fi

if command -v fdfind >/dev/null 2>&1; then
  alias fd="fdfind"
fi

alias j="z"
alias ji="zi"

alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

alias c="clear"
alias h="history"

if [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Keep this near the end of .zshrc so it can observe final widgets/bindings.
if [[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
EOF

  chown "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.zshrc"
}

main() {
  require_root
  require_target_user

  if ! command -v apt-get >/dev/null 2>&1; then
    echo "This script currently supports Debian/Ubuntu only." >&2
    exit 1
  fi

  export DEBIAN_FRONTEND=noninteractive

  install_xray
  wait_for_xray_proxy
  export_proxy_env

  log "Updating apt cache"
  apt-get update

  log "Installing base packages"
  apt-get install -y btop ca-certificates curl fd-find git nano zsh unzip
  apt_install_if_available zoxide
  apt_install_if_available eza
  apt_install_if_available zsh-autosuggestions
  apt_install_if_available zsh-syntax-highlighting

  install_docker
  install_uv
  install_fnm
  install_node_with_fnm
  install_oh_my_zsh
  install_user_scripts
  write_zshrc

  log "Setting ${TARGET_USER} shell to zsh"
  chsh -s /usr/bin/zsh "${TARGET_USER}"

  log "Local device shell setup complete"
  printf '\nNext steps:\n'
  printf '  newgrp docker   # optional, if you want Docker group changes immediately\n'
  printf '  exec zsh\n'
}

main "$@"
