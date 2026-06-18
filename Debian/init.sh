#!/usr/bin/env bash

set -euo pipefail

XRAY_HTTP_PROXY="http://127.0.0.1:10809"
XRAY_SOCKS_PROXY="socks5://127.0.0.1:10808"
XRAY_NO_PROXY="127.0.0.1,localhost,::1"

WITH_PROXY=0
WITH_DOCKER=0
WITH_USTC_MIRROR=0
TARGET_USER=""
TARGET_HOME=""
IS_ROOT_TARGET=0
FAILED_STEPS=()

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

record_failure() {
  FAILED_STEPS+=("$1")
}

run_step() {
  local step_name="$1"
  shift

  log "Starting: ${step_name}"
  if "$@"; then
    log "Completed: ${step_name}"
    return 0
  fi

  log "Failed: ${step_name}"
  record_failure "${step_name}"
  return 0
}

report_failures() {
  local failed_step

  if [[ "${#FAILED_STEPS[@]}" -eq 0 ]]; then
    return 0
  fi

  printf '\nThe following steps failed:\n' >&2
  for failed_step in "${FAILED_STEPS[@]}"; do
    printf '  - %s\n' "${failed_step}" >&2
  done

  return 1
}

usage() {
  cat <<'EOF'
Usage:
  sudo ./init.sh [--proxy] [--docker] [--ustc]

Options:
  --proxy   Enable proxy environment only, without installing Xray.
  --docker  Install Docker.
  --ustc    Switch Debian/Ubuntu apt sources to USTC mirror.
  -h, --help  Show this help message.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --proxy)
        WITH_PROXY=1
        ;;
      --docker)
        WITH_DOCKER=1
        ;;
      --ustc)
        WITH_USTC_MIRROR=1
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
  if [[ "${WITH_PROXY}" -eq 1 ]]; then
    run_as_target_user_with_proxy "$@"
  else
    run_as_target_user "$@"
  fi
}

export_proxy_env() {
  while IFS= read -r env_var; do
    export "${env_var}"
  done < <(proxy_env_args)
}

zsh_proxy_block() {
  if [[ "${WITH_PROXY}" -ne 1 ]]; then
    return 0
  fi

  cat <<'EOF'
# Network proxy
export PROXY_URL="http://127.0.0.1:10809"
export NO_PROXY_LIST="127.0.0.1,localhost,::1"

proxy() {
  export http_proxy="$PROXY_URL"
  export https_proxy="$PROXY_URL"
  export all_proxy="$PROXY_URL"
  export ws_proxy="$PROXY_URL"
  export wss_proxy="$PROXY_URL"
  export no_proxy="$NO_PROXY_LIST"

  export HTTP_PROXY="$http_proxy"
  export HTTPS_PROXY="$https_proxy"
  export ALL_PROXY="$all_proxy"
  export WS_PROXY="$PROXY_URL"
  export WSS_PROXY="$PROXY_URL"
  export NO_PROXY="$no_proxy"
}

unproxy() {
  unset http_proxy https_proxy all_proxy ws_proxy wss_proxy no_proxy
  unset HTTP_PROXY HTTPS_PROXY ALL_PROXY WS_PROXY WSS_PROXY NO_PROXY
}

proxy

EOF
}
configure_proxy_if_requested() {
  if [[ "${WITH_PROXY}" -ne 1 ]]; then
    return 0
  fi

  log "Enabling proxy environment"
  export_proxy_env
}

backup_apt_source_file() {
  local path="$1"
  local backup_path="${path}.bak"

  if [[ ! -f "${path}" ]]; then
    return 0
  fi

  if [[ -f "${backup_path}" ]]; then
    rm -f "${path}"
  else
    mv "${path}" "${backup_path}"
  fi
}

remove_apt_source_file() {
  local path="$1"

  if [[ -f "${path}" ]]; then
    rm -f "${path}"
  fi
}

configure_ustc_mirror_if_requested() {
  local distro codename

  if [[ "${WITH_USTC_MIRROR}" -ne 1 ]]; then
    return 0
  fi

  if [[ ! -f /etc/os-release ]]; then
    echo "Unable to configure USTC mirror: /etc/os-release not found." >&2
    exit 1
  fi

  . /etc/os-release
  distro="${ID:-}"
  codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"

  if [[ -z "${codename}" ]]; then
    echo "Unable to configure USTC mirror: distribution codename not found." >&2
    exit 1
  fi

  case "${distro}" in
    debian)
      log "Configuring Debian apt sources to use USTC mirror (DEB822)"
      backup_apt_source_file /etc/apt/sources.list
      backup_apt_source_file /etc/apt/sources.list.d/debian.sources
      remove_apt_source_file /etc/apt/sources.list
      cat >/etc/apt/sources.list.d/debian.sources <<EOF
Types: deb
URIs: https://mirrors.ustc.edu.cn/debian
Suites: ${codename} ${codename}-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://mirrors.ustc.edu.cn/debian-security
Suites: ${codename}-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
      ;;
    ubuntu)
      log "Configuring Ubuntu apt sources to use USTC mirror (DEB822)"
      backup_apt_source_file /etc/apt/sources.list
      backup_apt_source_file /etc/apt/sources.list.d/ubuntu.sources
      remove_apt_source_file /etc/apt/sources.list
      cat >/etc/apt/sources.list.d/ubuntu.sources <<EOF
Types: deb
URIs: https://mirrors.ustc.edu.cn/ubuntu
Suites: ${codename} ${codename}-updates ${codename}-backports ${codename}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
      ;;
    *)
      echo "USTC mirror is only supported on Debian/Ubuntu. Current distro: ${distro:-unknown}." >&2
      exit 1
      ;;
  esac
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Using existing Docker"
    return 0
  fi

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

  if [[ "${IS_ROOT_TARGET}" -eq 0 ]] && getent group docker >/dev/null 2>&1; then
    usermod -aG docker "${TARGET_USER}"
  fi
}

install_edit() {
  local arch asset_arch latest_api asset_name download_url tmp_dir
  local -a edit_asset_info

  if command -v edit >/dev/null 2>&1 || command -v msedit >/dev/null 2>&1; then
    log "Using existing Microsoft Edit"
    return 0
  fi

  arch="$(dpkg --print-architecture)"
  case "${arch}" in
    amd64)
      asset_arch="x86_64"
      ;;
    arm64)
      asset_arch="aarch64"
      ;;
    *)
      log "Skipping Microsoft Edit install on unsupported architecture: ${arch}"
      return 0
      ;;
  esac

  latest_api="https://api.github.com/repos/microsoft/edit/releases/latest"
  mapfile -t edit_asset_info < <(
    curl -fsSL "${latest_api}" |
      jq -r --arg arch "${asset_arch}" '
        .assets[]
        | select(.name | test("-" + $arch + "-linux-gnu\\.tar\\.(gz|zst)$"))
        | .name, .browser_download_url
      ' |
      head -n2
  )

  asset_name="${edit_asset_info[0]:-}"
  download_url="${edit_asset_info[1]:-}"

  if [[ -z "${asset_name}" || -z "${download_url}" || "${download_url}" == "null" ]]; then
    echo "Unable to determine Microsoft Edit download URL for ${arch}." >&2
    exit 1
  fi

  tmp_dir="$(mktemp -d)"

  log "Installing latest Microsoft Edit from ${asset_name}"
  curl -fsSL "${download_url}" -o "${tmp_dir}/${asset_name}"

  case "${asset_name}" in
    *.tar.gz)
      tar -xzf "${tmp_dir}/${asset_name}" -C "${tmp_dir}" edit
      ;;
    *.tar.zst)
      tar --zstd -xf "${tmp_dir}/${asset_name}" -C "${tmp_dir}" edit
      ;;
    *)
      echo "Unsupported Microsoft Edit archive format: ${asset_name}" >&2
      exit 1
      ;;
  esac

  install -m 0755 "${tmp_dir}/edit" /usr/local/bin/msedit
  ln -sf /usr/local/bin/msedit /usr/local/bin/edit
  rm -rf "${tmp_dir}"
}

install_uv() {
  local uv_path=""

  if run_as_target_user command -v uv >/dev/null 2>&1; then
    uv_path="$(run_as_target_user sh -lc 'command -v uv')"
    log "Using existing uv for ${TARGET_USER}: ${uv_path}"
    return 0
  fi

  log "Installing uv for ${TARGET_USER}"
  if [[ "${IS_ROOT_TARGET}" -eq 1 ]]; then
    run_as_target_user_for_network env HOME=/root sh -c "$(curl -fsSL https://astral.sh/uv/install.sh)"
  else
    run_as_target_user_for_network sh -c "$(curl -fsSL https://astral.sh/uv/install.sh)"
  fi
}

install_pixi() {
  if [[ -x "${TARGET_HOME}/.pixi/bin/pixi" ]]; then
    log "Using existing pixi for ${TARGET_USER}: ${TARGET_HOME}/.pixi/bin/pixi"
    return 0
  fi

  log "Installing pixi for ${TARGET_USER}"
  run_as_target_user_for_network bash -lc 'curl -fsSL https://pixi.sh/install.sh | bash'
}

install_bun() {
  if [[ -x "${TARGET_HOME}/.bun/bin/bun" ]]; then
    log "Using existing Bun for ${TARGET_USER}: ${TARGET_HOME}/.bun/bin/bun"
    return 0
  fi

  log "Installing Bun for ${TARGET_USER}"
  run_as_target_user_for_network bash -lc 'curl -fsSL https://bun.com/install | bash'
}

install_oh_my_zsh() {
  if [[ -d "${TARGET_HOME}/.oh-my-zsh" ]]; then
    log "Using existing oh-my-zsh for ${TARGET_USER}"
    return 0
  fi

  log "Installing oh-my-zsh for ${TARGET_USER}"
  run_as_target_user_for_network env RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

write_target_zshrc() {
  local zshrc_path="${TARGET_HOME}/.zshrc"
  {
    zsh_proxy_block
    if [[ "${WITH_PROXY}" -eq 1 ]]; then
      printf '\n'
    fi
    cat <<'EOF'
# Editor settings
export VISUAL=msedit
export EDITOR=msedit

# User-local binaries (include uv/uvx).
export PATH="$HOME/.local/bin:$PATH"

# oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="candy"
plugins=(git)

source "$ZSH/oh-my-zsh.sh"

# uv / uvx completion.
eval "$(uv generate-shell-completion zsh)"
eval "$(uvx --generate-shell-completion zsh)"

# pixi
export PATH="$HOME/.pixi/bin:$PATH"

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# zoxide
eval "$(zoxide init zsh)"

# eza
alias ls="eza"
alias ll="eza -l"
alias la="eza -la"
alias tree="eza --tree"

# bat
alias cat="batcat --style=plain --paging=never"

# fd
alias fd="fdfind"

# directory
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
  } >"${zshrc_path}"

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

  configure_proxy_if_requested
  run_step "Configure USTC apt mirror" configure_ustc_mirror_if_requested

  run_step "Update apt cache" apt-get update

  run_step "Install base packages" apt-get install -y bat btop bubblewrap ca-certificates curl eza fd-find fzf git jq mosh ripgrep wget zoxide zsh unzip zstd
  run_step "Install zsh plugins" apt-get install -y zsh-autosuggestions zsh-syntax-highlighting

  if [[ "${WITH_DOCKER}" -eq 1 ]]; then
    run_step "Install Docker" install_docker
  fi
  run_step "Install Microsoft Edit" install_edit
  run_step "Install uv" install_uv
  run_step "Install pixi" install_pixi
  run_step "Install Bun" install_bun
  run_step "Install oh-my-zsh" install_oh_my_zsh
  run_step "Write .zshrc" write_target_zshrc

  run_step "Set ${TARGET_USER} shell to zsh" chsh -s /usr/bin/zsh "${TARGET_USER}"

  if [[ "${IS_ROOT_TARGET}" -eq 1 ]]; then
    log "Root shell setup complete"
    printf '\nNext step:\n'
  else
    log "User shell setup complete"
    printf '\nNext steps:\n'
    if [[ "${WITH_DOCKER}" -eq 1 ]]; then
      printf '  newgrp docker   # optional, if you want Docker group changes immediately\n'
    fi
  fi
  printf '  exec zsh\n'

  report_failures
}

main "$@"
