#!/usr/bin/env bash

set -euo pipefail

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run this script as root." >&2
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

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker already installed"
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
  if [[ -z "$codename" ]]; then
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
}

install_uv() {
  if command -v uv >/dev/null 2>&1; then
    return 0
  fi

  log "Installing uv"
  env HOME=/root sh -c "$(curl -fsSL https://astral.sh/uv/install.sh)"
}

install_oh_my_zsh() {
  if [[ -d /root/.oh-my-zsh ]]; then
    return 0
  fi

  log "Installing oh-my-zsh"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

write_zshrc() {
  cat >/root/.zshrc <<'EOF'
# User-local binaries (include uv/uvx).
export PATH="$HOME/.local/bin:$PATH"

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

# zoxide
alias j="z"
alias ji="zi"

# directory
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

# utils
alias c="clear"
alias h="history"

# zsh-autosuggestions
if [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# zsh-syntax-highlighting
# Keep this near the end of .zshrc so it can observe final widgets/bindings.
if [[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
EOF
}

main() {
  require_root

  if ! command -v apt-get >/dev/null 2>&1; then
    echo "This script currently supports Debian/Ubuntu only." >&2
    exit 1
  fi

  export DEBIAN_FRONTEND=noninteractive

  log "Updating apt cache"
  apt-get update

  log "Installing base packages"
  apt-get install -y btop ca-certificates curl fd-find git zsh unzip
  apt_install_if_available zoxide
  apt_install_if_available eza
  apt_install_if_available zsh-autosuggestions
  apt_install_if_available zsh-syntax-highlighting

  install_docker
  install_uv
  install_oh_my_zsh
  write_zshrc

  log "Setting root shell to zsh"
  chsh -s /usr/bin/zsh root

  log "Shell setup complete"
  printf '\nNext step:\n'
  printf '  exec zsh\n'
}

main "$@"
