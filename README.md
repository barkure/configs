# configs

我的个人配置仓库，主要用来保存 Debian/Ubuntu、macOS 和 Windows 上常用的环境初始化脚本、终端配置，以及 Windows 下的 Xray 相关文件。

# 目录结构

```text
.
├── Debian/
│   └── bootstrap.sh
├── Windows/
│   └── xray/
└── macOS/
    ├── .zshrc
    ├── ghostty/
    └── zsh-theme/
```

## Debian

`Debian/` 里主要是这些内容：

- `bootstrap.sh`：统一的 Debian/Ubuntu 初始化脚本

### bootstrap.sh

适合新装好的 Debian/Ubuntu 环境：

- 脚本可重复运行；每次运行都会重新拉取并安装可获取到的最新版本
- 传入 `--with-proxy` 时，脚本会启用代理环境；默认使用 `http://127.0.0.1:10809` 和 `socks5://127.0.0.1:10808`
- 安装基础工具：`bat`、`btop`、`curl`、`eza`、`fd-find`、`fzf`、`git`、`jq`、`ripgrep`、`wget`、`zoxide`、`unzip`、`zsh`、`zstd`
- 安装 `oh-my-zsh` 和 zsh 插件：`zsh-autosuggestions`、`zsh-syntax-highlighting`
- 安装 `uv`、`pixi`、`viteplus`、`Docker`、`LazyDocker`、`LazyGit`
- 通过 `vp add -g @openai/codex` 安装或更新 Codex CLI
- 写入与本机 `.zshrc` 风格接近的 shell 环境，并加载 `~/.pixi/bin` 和 `~/.vite-plus/env`
- 安装 `Microsoft Edit`，将默认编辑器设置为 `msedit`，并链接到 `edit`

运行方式：
```bash
cd Debian
sudo ./bootstrap.sh
exec zsh
```

如果代理已由其他环境提供，例如 WSL 中复用宿主机代理，则直接运行：
```bash
cd Debian
sudo ./bootstrap.sh --with-proxy
exec zsh
```

注意：

- 从目标用户下用 `sudo` 执行时，脚本会根据 `SUDO_USER` 配置对应账号
- 直接以 root 运行时，脚本会配置 root

## macOS

`macOS/` 目前保存的是我在 macOS 上使用的终端和 shell 相关配置：

- `.zshrc`：macOS 下的 zsh 配置
- `ghostty/config`：Ghostty 配置
- `ghostty/themes/passion`：Ghostty 主题
- `zsh-theme/passion.zsh-theme`：自定义 zsh 主题

## Windows

`Windows/xray/` 保存的是 Windows 下使用 Xray 的示例配置和启停脚本，你可以把它们放到任意目录，例如 `/path/xray`：

- `config.json.example`：Xray 配置示例，默认监听 `10808`(SOCKS) 和 `10809`(HTTP)
- `start-xray.ps1`：从脚本所在目录读取 `*.json` 配置；如果有多个配置文件，会先让你选择，再启动 Xray
- `stop-xray.ps1`：停止 Xray，并清理当前用户的代理设置

使用方式：

1. 安装 Xray：`winget install XTLS.Xray-core`
2. 复制 `config.json.example` 为一个或多个 `.json` 配置文件，并放在 `/path/xray` 目录下
3. 运行 `start-xray.ps1`

`start-xray.ps1` 会做这些事情：

- 停掉已有的 `xray.exe` 进程
- 将当前用户的 `HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY`、`NO_PROXY` 写入环境变量
- 将 Windows 系统代理切换到 `127.0.0.1:10809`
- 当目录中存在多个配置文件时，提示选择要启动的配置

运行 `stop-xray.ps1` 时，会停止 `xray.exe`，并关闭系统代理、删除上述用户级代理环境变量。
