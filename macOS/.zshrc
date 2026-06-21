# Homebrew
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
eval "$(/opt/homebrew/bin/brew shellenv)"
BREW_PREFIX="$HOMEBREW_PREFIX"

# Editor settings
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

# User-local binaries.
export PATH="$PATH:$HOME/.local/bin"

# oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="ys"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source "$ZSH/oh-my-zsh.sh"

# uv / uvx completion.
eval "$(uv generate-shell-completion zsh)"
eval "$(uvx --generate-shell-completion zsh)"

# bun
export PATH="/Users/barkure/.bun/bin:$PATH"

# go
export PATH=$PATH:$(go env GOPATH)/bin
export GOPROXY=https://mirrors.cloud.tencent.com/go,direct

# zoxide
eval "$(zoxide init zsh)"

# eza
alias ls="eza"
alias ll="eza -l"
alias la="eza -la"
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

# bucketctl
alias bkt="bucketctl"
