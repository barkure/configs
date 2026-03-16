# configs

我的个人配置仓库，主要用来保存 Debian/Ubuntu 和 macOS 上常用的环境初始化脚本、终端配置，以及 Xray 相关文件。

## 目录结构

```text
.
├── Debian/
│   ├── bootstrap-desktop.sh
│   ├── bootstrap-vps.sh
│   ├── xray/
│   └── README.md
└── macOS/
    ├── .zshrc
    ├── ghostty/
    ├── scripts/
    └── zsh-theme/
```

## Debian

`Debian/` 里主要是两类内容：

- `bootstrap-desktop.sh`：初始化本地 Debian/Ubuntu 桌面环境
- `bootstrap-vps.sh`：初始化 Debian/Ubuntu VPS
- `xray/`：Xray 二进制、service、示例配置和 geofiles

更详细的脚本说明见 [Debian/README.md](./Debian/README.md)。

### bootstrap-desktop.sh

适合新装好的 Debian/Ubuntu 桌面设备，主要会做这些事：

- 安装基础工具：`btop`、`curl`、`fd-find`、`git`、`unzip`、`zsh`
- 按系统可用性安装：`eza`、`zoxide`、`zsh-autosuggestions`、`zsh-syntax-highlighting`
- 安装和配置 Xray
- 安装 `uv`、`fnm`、`Docker`
- 使用 `fnm` 安装 Node.js 24，并执行 `corepack enable`
- 为 `pnpm` 写入 `PNPM_HOME`，让 `pnpm add -g` 可直接使用
- 安装 `oh-my-zsh`
- 为目标用户写入常用 `~/.zshrc`

运行方式：

```bash
cd Debian
sudo ./bootstrap-desktop.sh
exec zsh
```

注意：

- 需要从目标用户下用 `sudo` 执行，脚本会根据 `SUDO_USER` 配置对应账号
- 如果要安装 Xray，请先准备 `Debian/xray/config.json`
- 仓库里只保留了 `config.json.example`，真实配置不会提交到 Git

### bootstrap-vps.sh

适合在 Debian/Ubuntu VPS 上直接初始化 root 环境，主要包含：

- 安装基础工具和 shell 增强组件
- 安装 `uv`
- 安装 Docker
- 在 `~/.zshrc` 中预留 `PNPM_HOME`
- 安装 `oh-my-zsh`
- 写入 root 的 `~/.zshrc`

运行方式：

```bash
cd Debian
sudo ./bootstrap-vps.sh
exec zsh
```

说明：

- 该脚本预期在 `root` 环境中运行
- 某些 VPS 镜像默认没有 `sudo`，这时可直接以 root 执行

### Xray

仓库中提供了 Xray 相关的安装文件和更新脚本。

Debian 桌面脚本会默认把这些文件安装到：

- 二进制：`/usr/local/bin/xray`
- 配置：`/etc/xray/config.json`
- geofiles：`/usr/local/share/xray/geoip.dat`、`/usr/local/share/xray/geosite.dat`
- systemd 服务：`/etc/systemd/system/xray.service`

如果只想更新 geofiles，可在安装完成后执行：

```bash
update-xray-geofiles
```

## macOS

`macOS/` 目前保存的是我在 macOS 上使用的终端和 shell 相关配置：

- `.zshrc`：macOS 下使用的 zsh 配置
- `ghostty/config`：Ghostty 主配置
- `ghostty/themes/passion`：Ghostty 主题
- `zsh-theme/passion.zsh-theme`：自定义 zsh 主题
- `scripts/update-xray-geofiles.sh`：更新 Homebrew 安装的 Xray geofiles，并重启服务

### Ghostty

当前 Ghostty 配置里主要包括：

- 字体：`Maple Mono NF CN`
- 主题：`passion`
- 半透明背景
- 简单的窗口边距和 shell integration 配置

如果你也在使用 Ghostty，可以将对应文件链接或复制到自己的配置目录中。

如果你在 macOS 上使用 `pnpm` 全局安装命令，shell 配置里至少要有这一段：

```zsh
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
```

这样 `pnpm add -g <pkg>` 安装出的可执行文件才会直接进入 `PATH`。

### macOS 下更新 Xray geofiles

脚本路径：

```bash
macOS/scripts/update-xray-geofiles.sh
```

它默认依赖这些 Homebrew 路径：

- `brew`：`/opt/homebrew/bin/brew`
- `xray`：`/opt/homebrew/opt/xray/bin/xray`
- 配置：`/opt/homebrew/etc/xray/config.json`

运行前请先确认你的本机安装路径一致。

## 本地私有文件

以下文件不会被提交：

- `config.json`

这是为了避免把敏感配置直接放进仓库。需要时可以参考 `Debian/xray/config.json.example` 自行生成本地版本。

## 使用建议

- 先阅读 [Debian/README.md](./Debian/README.md) 再执行初始化脚本
- 在新机器上使用前，先检查脚本里的软件版本、安装路径和代理相关配置是否符合当前环境
- 这是偏个人习惯的配置仓库，直接复用前建议按自己的系统情况调整
