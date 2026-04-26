# Homebrew
BREW_PREFIX="$(brew --prefix)"

# Editor settings
# Use Homebrew Edit as the default editor.
export VISUAL=/opt/homebrew/bin/edit
export EDITOR=/opt/homebrew/bin/edit

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

# User-local binaries (include uv/uvx).
export PATH="$HOME/.local/bin:$PATH"

# Android SDK platform-tools (adb).
export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"

# oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="passion"
plugins=(git)
source "$ZSH/oh-my-zsh.sh"

# uv / uvx completion.
eval "$(uv generate-shell-completion zsh)"
eval "$(uvx --generate-shell-completion zsh)"

# Vite+ bin (https://viteplus.dev)
. "$HOME/.vite-plus/env"

# Flutter
export PATH="/Users/barkure/Developer/flutter/bin:$PATH"

# zoxide
eval "$(zoxide init zsh)"

# eza
alias ls="eza --icons"
alias ll="eza -l --icons"
alias la="eza -la --icons"
alias tree="eza --tree"

# bat
alias cat="bat --style=plain --paging=never"

# directory
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

# utils
alias c="clear"
alias h="history"

# zsh-autosuggestions
source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

# zsh-syntax-highlighting
# Keep this near the end of .zshrc so it can observe final widgets/bindings.
source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
