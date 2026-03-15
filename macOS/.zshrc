# Homebrew
BREW_PREFIX="$(brew --prefix)"

# Editor settings
# Use Homebrew nano as the default editor.
alias nano="$BREW_PREFIX/bin/nano"
export VISUAL=nano
export EDITOR=nano

# Network proxy
# Proxy endpoints.
export http_proxy="http://127.0.0.1:10809"
export https_proxy="http://127.0.0.1:10809"
export all_proxy="socks5://127.0.0.1:10808"

# Uppercase variants for tools that expect them.
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"
export ALL_PROXY="$all_proxy"

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

# fnm: auto-switch Node version on directory change.
eval "$(fnm env --use-on-cd --shell zsh)"

# zoxide
eval "$(zoxide init zsh)"

# eza
alias ls="eza --icons"
alias ll="eza -l --icons"
alias la="eza -la --icons"
alias tree="eza --tree"

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
source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

# zsh-syntax-highlighting
# Keep this near the end of .zshrc so it can observe final widgets/bindings.
source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
