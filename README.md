# configs

个人配置仓库，主要保存 Debian/Ubuntu 和 macOS 上常用的环境初始化脚本、Shell 配置。

## 目录结构

```text
.
├── Debian/
│   ├── bootstrap.sh
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

`Debian/bootstrap.sh` 用于初始化一台新的 Debian/Ubuntu 机器，目标是尽快得到一套可直接使用的命令行环境。

脚本特点：

- 需要以 `root` 或 `sudo` 运行
- 可重复执行，已有组件会尽量更新到最新可获取版本
- 如果通过 `sudo` 运行，会优先配置 `SUDO_USER` 对应用户；否则配置 `root`
- `--with-proxy` 会为脚本执行过程和生成的 zsh 环境启用代理
- `--with-docker` 才会安装 Docker 和 LazyDocker

默认代理地址：

- HTTP: `http://127.0.0.1:10809`
- SOCKS5: `socks5://127.0.0.1:10808`
- NO_PROXY: `127.0.0.1,localhost,::1`

安装内容大致包括：

- 基础工具：`bat`、`btop`、`curl`、`eza`、`fd-find`、`fzf`、`git`、`jq`、`ripgrep`、`wget`、`zoxide`、`unzip`、`zsh`、`zstd`
- zsh 生态：`oh-my-zsh`、`zsh-autosuggestions`、`zsh-syntax-highlighting`
- 开发工具：`uv`、`pixi`、`LazyGit`
- 可选开发工具：`Docker`、`LazyDocker`（仅在传入 `--with-docker` 时安装）
- 其他工具：`Microsoft Edit`
- 全局安装 Codex CLI：`vp add -g @openai/codex`

脚本还会写入一份目标用户的 `~/.zshrc`，其中包含：

- 代理开关函数 `proxy` / `unproxy`
- `uv`、`pixi`、`Vite+`、`zoxide` 的初始化
- `eza`、`bat` 等常用别名

使用方式：

```bash
cd Debian
sudo ./bootstrap.sh
exec zsh
```

如果当前环境需要通过本地代理访问外网：

```bash
cd Debian
sudo ./bootstrap.sh --with-proxy
exec zsh
```

参数说明：

- `--with-proxy`：为脚本执行过程和生成的 zsh 环境启用代理
- `--with-docker`：安装 Docker 和 LazyDocker

## macOS

`macOS/` 保存的是我在 macOS 上使用的终端和 shell 配置。
