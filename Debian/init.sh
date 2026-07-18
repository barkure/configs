#!/usr/bin/env bash

set -euo pipefail

XRAY_HTTP_PROXY="http://127.0.0.1:10809"
XRAY_SOCKS_PROXY="socks5://127.0.0.1:10808"
XRAY_NO_PROXY="127.0.0.1,localhost,::1"
PYPI_USTC_MIRROR="https://mirrors.ustc.edu.cn/pypi/simple"

WITH_PROXY=0
WITH_DOCKER=0
WITH_MIRROR=0
WITH_BASIC=0
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
  sudo ./init.sh [--proxy] [--docker] [--mirror]
  ./init.sh --basic [--proxy] [--mirror]

Options:
  --basic   User-space only setup (no root/sudo). Installs uv, bun,
            msedit, btop, and oh-my-zsh when possible.
  --proxy   Enable proxy environment only, without installing Xray.
  --docker  Install Docker (full mode only; requires root).
  --mirror  Configure mirrors. Full mode: apt + uv. Basic mode: uv only.
  -h, --help  Show this help message.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --basic)
        WITH_BASIC=1
        ;;
      --proxy)
        WITH_PROXY=1
        ;;
      --docker)
        WITH_DOCKER=1
        ;;
      --mirror)
        WITH_MIRROR=1
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

  if [[ "${WITH_BASIC}" -eq 1 && "${WITH_DOCKER}" -eq 1 ]]; then
    echo "--basic cannot be used with --docker." >&2
    exit 1
  fi
}

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run this script with sudo or as root." >&2
    echo "For machines without sudo, use: ./init.sh --basic" >&2
    exit 1
  fi
}

detect_target() {
  if [[ "${WITH_BASIC}" -eq 1 ]]; then
    TARGET_USER="$(id -un)"
    TARGET_HOME="${HOME:-}"
    if [[ -z "${TARGET_HOME}" ]]; then
      TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
    fi
    if [[ "${TARGET_USER}" == "root" ]]; then
      IS_ROOT_TARGET=1
    else
      IS_ROOT_TARGET=0
    fi
  elif [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
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

running_as_target_user() {
  [[ "${IS_ROOT_TARGET}" -eq 1 ]] || [[ "$(id -un)" == "${TARGET_USER}" ]]
}

run_as_target_user() {
  if running_as_target_user; then
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

  if running_as_target_user; then
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
export PROXY_HTTP_URL="http://127.0.0.1:10809"
export PROXY_SOCKS_URL="socks5://127.0.0.1:10808"
export NO_PROXY_LIST="127.0.0.1,localhost,::1"

proxy() {
  export http_proxy="$PROXY_HTTP_URL"
  export https_proxy="$PROXY_HTTP_URL"
  export all_proxy="$PROXY_SOCKS_URL"
  export ws_proxy="$PROXY_SOCKS_URL"
  export wss_proxy="$PROXY_SOCKS_URL"
  export no_proxy="$NO_PROXY_LIST"

  export HTTP_PROXY="$http_proxy"
  export HTTPS_PROXY="$https_proxy"
  export ALL_PROXY="$all_proxy"
  export WS_PROXY="$ws_proxy"
  export WSS_PROXY="$wss_proxy"
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

configure_apt_mirror_if_requested() {
  local distro codename

  if [[ "${WITH_MIRROR}" -ne 1 ]]; then
    return 0
  fi

  if [[ ! -f /etc/os-release ]]; then
    echo "Unable to configure apt mirror: /etc/os-release not found." >&2
    exit 1
  fi

  . /etc/os-release
  distro="${ID:-}"
  codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"

  if [[ -z "${codename}" ]]; then
    echo "Unable to configure apt mirror: distribution codename not found." >&2
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
      echo "Apt mirror is only supported on Debian/Ubuntu. Current distro: ${distro:-unknown}." >&2
      exit 1
      ;;
  esac
}

configure_tool_mirrors_if_requested() {
  if [[ "${WITH_MIRROR}" -ne 1 ]]; then
    return 0
  fi

  log "Configuring uv mirror for ${TARGET_USER}"

  install -d -m 0755 "${TARGET_HOME}/.config/uv"

  cat >"${TARGET_HOME}/.config/uv/uv.toml" <<EOF
[[index]]
url = "${PYPI_USTC_MIRROR}"
default = true
EOF

  if [[ "$(id -u)" -eq 0 && "${IS_ROOT_TARGET}" -eq 0 ]]; then
    chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.config/uv"
  fi
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

detect_linux_cpu_arch() {
  local arch=""

  if command -v dpkg >/dev/null 2>&1; then
    arch="$(dpkg --print-architecture)"
  else
    arch="$(uname -m)"
  fi

  case "${arch}" in
    amd64|x86_64)
      printf '%s\n' "x86_64"
      ;;
    arm64|aarch64)
      printf '%s\n' "aarch64"
      ;;
    *)
      return 1
      ;;
  esac
}

resolve_edit_download() {
  local asset_arch="$1"
  local latest_api asset_json
  local -a edit_asset_info

  latest_api="https://api.github.com/repos/microsoft/edit/releases/latest"
  asset_json="$(curl -fsSL "${latest_api}")"

  if command -v jq >/dev/null 2>&1; then
    mapfile -t edit_asset_info < <(
      printf '%s\n' "${asset_json}" |
        jq -r --arg arch "${asset_arch}" '
          .assets[]
          | select(.name | test("-" + $arch + "-linux-gnu\\.tar\\.(gz|zst)$"))
          | .name, .browser_download_url
        ' |
        head -n2
    )
    EDIT_ASSET_NAME="${edit_asset_info[0]:-}"
    EDIT_DOWNLOAD_URL="${edit_asset_info[1]:-}"
  else
    # Prefer .tar.gz when jq is unavailable (common on locked-down hosts).
    EDIT_DOWNLOAD_URL="$(
      printf '%s\n' "${asset_json}" |
        grep -oE "https://[^\"]+-${asset_arch}-linux-gnu\\.tar\\.gz" |
        head -n1
    )"
    EDIT_ASSET_NAME="$(basename "${EDIT_DOWNLOAD_URL}")"
  fi

  if [[ -z "${EDIT_ASSET_NAME}" || -z "${EDIT_DOWNLOAD_URL}" || "${EDIT_DOWNLOAD_URL}" == "null" ]]; then
    return 1
  fi
}

install_edit() {
  local asset_arch download_url asset_name tmp_dir bin_dir

  if command -v edit >/dev/null 2>&1 || command -v msedit >/dev/null 2>&1; then
    log "Using existing Microsoft Edit"
    return 0
  fi

  if [[ -x "${TARGET_HOME}/.local/bin/msedit" || -x "${TARGET_HOME}/.local/bin/edit" ]]; then
    log "Using existing Microsoft Edit in ${TARGET_HOME}/.local/bin"
    return 0
  fi

  if ! asset_arch="$(detect_linux_cpu_arch)"; then
    log "Skipping Microsoft Edit install on unsupported architecture: $(uname -m)"
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    log "Skipping Microsoft Edit install: curl not found"
    return 0
  fi

  EDIT_ASSET_NAME=""
  EDIT_DOWNLOAD_URL=""
  if ! resolve_edit_download "${asset_arch}"; then
    echo "Unable to determine Microsoft Edit download URL for ${asset_arch}." >&2
    return 1
  fi

  asset_name="${EDIT_ASSET_NAME}"
  download_url="${EDIT_DOWNLOAD_URL}"
  tmp_dir="$(mktemp -d)"

  log "Installing latest Microsoft Edit from ${asset_name}"
  curl -fsSL "${download_url}" -o "${tmp_dir}/${asset_name}"

  case "${asset_name}" in
    *.tar.gz)
      tar -xzf "${tmp_dir}/${asset_name}" -C "${tmp_dir}" edit
      ;;
    *.tar.zst)
      if ! tar --zstd -xf "${tmp_dir}/${asset_name}" -C "${tmp_dir}" edit; then
        echo "Failed to extract Microsoft Edit archive (zstd may be missing)." >&2
        rm -rf "${tmp_dir}"
        return 1
      fi
      ;;
    *)
      echo "Unsupported Microsoft Edit archive format: ${asset_name}" >&2
      rm -rf "${tmp_dir}"
      return 1
      ;;
  esac

  if [[ "${WITH_BASIC}" -eq 1 ]]; then
    bin_dir="${TARGET_HOME}/.local/bin"
    run_as_target_user mkdir -p "${bin_dir}"
    install -m 0755 "${tmp_dir}/edit" "${bin_dir}/msedit"
    ln -sfn "${bin_dir}/msedit" "${bin_dir}/edit"
    if [[ "${IS_ROOT_TARGET}" -eq 0 ]]; then
      chown -h "${TARGET_USER}:${TARGET_USER}" "${bin_dir}/msedit" "${bin_dir}/edit" 2>/dev/null || true
    fi
  else
    install -m 0755 "${tmp_dir}/edit" /usr/local/bin/msedit
    ln -sf /usr/local/bin/msedit /usr/local/bin/edit
  fi

  rm -rf "${tmp_dir}"
}

install_btop_binary() {
  local asset_arch download_url tmp_dir bin_dir btop_bin

  if command -v btop >/dev/null 2>&1; then
    log "Using existing btop: $(command -v btop)"
    return 0
  fi

  if [[ -x "${TARGET_HOME}/.local/bin/btop" ]]; then
    log "Using existing btop in ${TARGET_HOME}/.local/bin"
    return 0
  fi

  if ! asset_arch="$(detect_linux_cpu_arch)"; then
    log "Skipping btop binary install on unsupported architecture: $(uname -m)"
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    log "Skipping btop binary install: curl not found"
    return 0
  fi

  download_url="https://github.com/aristocratos/btop/releases/latest/download/btop-${asset_arch}-linux-musl.tbz"
  tmp_dir="$(mktemp -d)"
  bin_dir="${TARGET_HOME}/.local/bin"

  log "Installing btop binary from ${download_url}"
  if ! curl -fsSL "${download_url}" -o "${tmp_dir}/btop.tbz"; then
    echo "Failed to download btop binary." >&2
    rm -rf "${tmp_dir}"
    return 1
  fi

  # .tbz needs bzip2 support in tar.
  if ! tar -xjf "${tmp_dir}/btop.tbz" -C "${tmp_dir}" 2>/dev/null; then
    log "Skipping btop binary install: failed to extract .tbz (is bzip2 available?)"
    rm -rf "${tmp_dir}"
    return 0
  fi

  if [[ -x "${tmp_dir}/bin/btop" ]]; then
    btop_bin="${tmp_dir}/bin/btop"
  else
    btop_bin="$(find "${tmp_dir}" -type f -name btop -perm -u+x 2>/dev/null | head -n1)"
  fi

  if [[ -z "${btop_bin}" || ! -x "${btop_bin}" ]]; then
    echo "Unable to locate btop binary in archive." >&2
    rm -rf "${tmp_dir}"
    return 1
  fi

  run_as_target_user mkdir -p "${bin_dir}"
  install -m 0755 "${btop_bin}" "${bin_dir}/btop"
  if [[ "$(id -u)" -eq 0 && "${IS_ROOT_TARGET}" -eq 0 ]]; then
    chown "${TARGET_USER}:${TARGET_USER}" "${bin_dir}/btop"
  fi

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

install_bun() {
  if [[ -x "${TARGET_HOME}/.bun/bin/bun" ]]; then
    log "Using existing Bun for ${TARGET_USER}: ${TARGET_HOME}/.bun/bin/bun"
  else
    log "Installing Bun for ${TARGET_USER}"
    run_as_target_user_for_network bash -lc 'curl -fsSL https://bun.com/install | bash'
  fi

  log "Linking Bun as node for ${TARGET_USER}"
  run_as_target_user bash -lc '
    mkdir -p "$HOME/.local/bin"
    bun_path="$(command -v bun || true)"
    if [[ -z "${bun_path}" && -x "$HOME/.bun/bin/bun" ]]; then
      bun_path="$HOME/.bun/bin/bun"
    fi
    if [[ -z "${bun_path}" ]]; then
      echo "Unable to locate bun for node symlink." >&2
      exit 1
    fi
    ln -sfn "${bun_path}" "$HOME/.local/bin/node"
  '
}

install_oh_my_zsh() {
  if [[ -d "${TARGET_HOME}/.oh-my-zsh" ]]; then
    log "Using existing oh-my-zsh for ${TARGET_USER}"
    return 0
  fi

  if ! command -v zsh >/dev/null 2>&1; then
    log "Skipping oh-my-zsh: zsh not found"
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    log "Skipping oh-my-zsh: curl not found"
    return 0
  fi

  log "Installing oh-my-zsh for ${TARGET_USER}"
  run_as_target_user_for_network env RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

install_oh_my_zsh_plugin() {
  local name="$1"
  local repo="$2"
  local plugin_dir="${TARGET_HOME}/.oh-my-zsh/custom/plugins/${name}"

  if [[ ! -d "${TARGET_HOME}/.oh-my-zsh" ]]; then
    log "Skipping ${name}: oh-my-zsh not installed"
    return 0
  fi

  if [[ -d "${plugin_dir}" ]]; then
    log "Using existing ${name} for ${TARGET_USER}"
    return 0
  fi

  if ! command -v git >/dev/null 2>&1; then
    log "Skipping ${name}: git not found"
    return 0
  fi

  log "Installing ${name} for ${TARGET_USER}"
  run_as_target_user mkdir -p "${TARGET_HOME}/.oh-my-zsh/custom/plugins"
  run_as_target_user_for_network git clone --depth 1 "${repo}" "${plugin_dir}"
}

install_zsh_plugins() {
  install_oh_my_zsh_plugin \
    zsh-autosuggestions \
    https://github.com/zsh-users/zsh-autosuggestions.git
  install_oh_my_zsh_plugin \
    zsh-syntax-highlighting \
    https://github.com/zsh-users/zsh-syntax-highlighting.git
}

write_target_zshrc() {
  local zshrc_path="${TARGET_HOME}/.zshrc"
  {
    zsh_proxy_block
    if [[ "${WITH_PROXY}" -eq 1 ]]; then
      printf '\n'
    fi

    if [[ "${WITH_BASIC}" -eq 1 ]]; then
      cat <<'EOF'
# User-local binaries (include uv/uvx, msedit).
export PATH="$HOME/.local/bin:$PATH"

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Editor (only if installed).
if command -v msedit >/dev/null 2>&1; then
  export VISUAL=msedit
  export EDITOR=msedit
elif command -v edit >/dev/null 2>&1; then
  export VISUAL=edit
  export EDITOR=edit
fi

# oh-my-zsh (optional on locked-down hosts).
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  export ZSH="$HOME/.oh-my-zsh"
  ZSH_THEME="ys"
  plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
  source "$ZSH/oh-my-zsh.sh"
fi

# uv / uvx completion.
if command -v uv >/dev/null 2>&1; then
  eval "$(uv generate-shell-completion zsh 2>/dev/null)" || true
fi
if command -v uvx >/dev/null 2>&1; then
  eval "$(uvx --generate-shell-completion zsh 2>/dev/null)" || true
fi

# directory
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

# utils
alias c="clear"
alias h="history"
EOF
    else
      cat <<'EOF'
# Editor settings
export VISUAL=msedit
export EDITOR=msedit

# User-local binaries (include uv/uvx).
export PATH="$HOME/.local/bin:$PATH"

# oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="ys"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source "$ZSH/oh-my-zsh.sh"

# uv / uvx completion.
eval "$(uv generate-shell-completion zsh)"
eval "$(uvx --generate-shell-completion zsh)"

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
EOF
    fi
  } >"${zshrc_path}"

  if [[ "${IS_ROOT_TARGET}" -eq 0 && "$(id -u)" -eq 0 ]]; then
    chown "${TARGET_USER}:${TARGET_USER}" "${zshrc_path}"
  fi
}

require_basic_prereqs() {
  local missing=()

  if ! command -v curl >/dev/null 2>&1; then
    missing+=("curl")
  fi
  if ! command -v tar >/dev/null 2>&1; then
    missing+=("tar")
  fi

  if [[ "${#missing[@]}" -gt 0 ]]; then
    echo "--basic requires: ${missing[*]}" >&2
    exit 1
  fi
}

run_basic_setup() {
  log "Running basic user-space setup for ${TARGET_USER} (no root/apt)"

  require_basic_prereqs
  configure_proxy_if_requested

  run_step "Install Microsoft Edit" install_edit
  run_step "Install btop binary" install_btop_binary
  run_step "Install uv" install_uv
  run_step "Install Bun" install_bun
  run_step "Configure tool mirrors" configure_tool_mirrors_if_requested
  run_step "Install oh-my-zsh" install_oh_my_zsh
  run_step "Install zsh plugins" install_zsh_plugins
  run_step "Write .zshrc" write_target_zshrc

  log "Basic setup complete for ${TARGET_USER}"
  printf '\nNotes:\n'
  printf '  - No apt packages were installed (needs root).\n'
  printf '  - Shell was not changed with chsh (needs permission).\n'
  if command -v zsh >/dev/null 2>&1; then
    printf '  - zsh is available: exec zsh\n'
  else
    printf '  - zsh not found; source ~/.zshrc from bash or install zsh later.\n'
    printf '  - source ~/.zshrc\n'
  fi
}

run_full_setup() {
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "This script currently supports Debian/Ubuntu only." >&2
    exit 1
  fi

  export DEBIAN_FRONTEND=noninteractive

  configure_proxy_if_requested
  run_step "Configure apt mirror" configure_apt_mirror_if_requested

  run_step "Update apt cache" apt-get update

  run_step "Install base packages" apt-get install -y bat btop bubblewrap ca-certificates curl eza fd-find fzf git jq ripgrep wget zoxide zsh unzip zstd

  if [[ "${WITH_DOCKER}" -eq 1 ]]; then
    run_step "Install Docker" install_docker
  fi
  run_step "Install Microsoft Edit" install_edit
  run_step "Install uv" install_uv
  run_step "Install Bun" install_bun
  run_step "Configure tool mirrors" configure_tool_mirrors_if_requested
  run_step "Install oh-my-zsh" install_oh_my_zsh
  run_step "Install zsh plugins" install_zsh_plugins
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
}

main() {
  parse_args "$@"
  detect_target

  if [[ "${WITH_BASIC}" -eq 1 ]]; then
    run_basic_setup
  else
    require_root
    run_full_setup
  fi

  report_failures
}

main "$@"
