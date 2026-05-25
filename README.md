# configs

个人配置仓库，主要保存 Debian/Ubuntu 和 macOS 上常用的环境初始化脚本、Shell 配置。

## 目录结构

```text
.
├── Debian/
│   ├── init.sh
│   └── config.json.example
└── macOS/
    ├── .zshrc
    ├── ghostty/
    │   ├── config
    │   └── themes/
    │       └── passion
    └── zsh-theme/
        └── passion.zsh-theme
```

## Debian

`Debian/init.sh` 用于初始化一台新的 Debian/Ubuntu 机器。

- 支持 Ubuntu 24.04+ and Debian 13+.
- 需要以 `root` 或 `sudo` 运行，`sudo` 运行时优先配置 `SUDO_USER`，否则配置 `root`
- 已有软件直接跳过，单个步骤失败后继续执行，最后汇总失败项
- `--docker` 会安装 `Docker` 和 `LazyDocker`
- `--ustc` 会将 Debian/Ubuntu 的 `apt` 源切换到中科大源
- `--proxy` 会为脚本执行过程和生成的 zsh 配置启用代理：
  - HTTP: `http://127.0.0.1:10809`
  - SOCKS5: `socks5://127.0.0.1:10808`
  - NO_PROXY: `127.0.0.1,localhost,::1`

- 安装清单：`bat`、`btop`、`bubblewrap`、`ca-certificates`、`curl`、`eza`、`fd-find`、`fzf`、`git`、`jq`、`ripgrep`、`wget`、`zoxide`、`zsh`、`unzip`、`zstd`、`zsh-autosuggestions`、`zsh-syntax-highlighting`、`oh-my-zsh`、`uv`、`pixi`、`Vite+`、`LazyGit`、`Microsoft Edit`、`@openai/codex`

脚本也会写入目标用户的 `~/.zshrc`，包含代理函数、常用 PATH、补全和别名。

使用方式：

```bash
cd Debian
sudo ./init.sh [OPTIONS]
exec zsh
```
可选：

```bash
--proxy, -p   Enable proxy
--docker, -d  Install Docker and LazyDocker
--ustc, -u    Use USTC apt mirror
```

## macOS

`macOS/` 保存的是我在 macOS 上使用的终端和 shell 配置。
