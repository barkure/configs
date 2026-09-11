# Debian / Ubuntu 新机器配置

## 1. apt 包

```
bat btop bubblewrap ca-certificates curl eza fd-find fzf git jq ripgrep wget zoxide zsh unzip
```

## 2. 工具

```bash
# uv
curl -fsSL https://astral.sh/uv/install.sh | sh

# pnpm
curl -fsSL https://get.pnpm.io/install.sh | sh -

# node LTS，由 pnpm 管
pnpm runtime set node lts -g
```

**msedit** —— 取 `github.com/microsoft/edit` 最新 release 里 `*-{x86_64,aarch64}-linux-gnu.tar.gz`，解出 `edit`：

```bash
curl -fsSL <url> -o /tmp/edit.tgz && tar -xzf /tmp/edit.tgz -C /tmp edit
install -m 0755 /tmp/edit /usr/local/bin/msedit && ln -sf /usr/local/bin/msedit /usr/local/bin/edit
```

oh-my-zsh 和插件（已存在就跳过）：

```bash
RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
  "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
  ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting \
  ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
```

最后 `chsh -s /usr/bin/zsh <user>`。

## 3. `~/.zshrc`

按这台机器上**实际装成了什么**写，不要照抄。下面只是风格示例：

- 每个工具一段，段头注释写上工具名
- 机器上有这个工具就写那一段，没装上就整段不写（没装 msedit 就别写 Editor settings，没装 fd 就别写 fd 那段）
- 多装了别的也照这个格式往下接
- 一行一个，不要合并成 `export A=1 B=2` 这种

覆盖写入：

```zsh
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

# Editor settings
export VISUAL=msedit
export EDITOR=msedit

# User-local binaries (include uv/uvx).
export PATH="$HOME/.local/bin:$PATH"

# oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="candy"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source "$ZSH/oh-my-zsh.sh"

# uv / uvx completion.
eval "$(uv generate-shell-completion zsh)"
eval "$(uvx --generate-shell-completion zsh)"

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

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
```
