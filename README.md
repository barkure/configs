# configs

我的个人配置仓库，主要用来保存 Debian/Ubuntu 和 macOS 上常用的环境初始化脚本、终端配置，以及 Xray 相关文件。

## 目录结构

```text
.
├── Debian/
│   ├── bootstrap-desktop.sh
│   ├── bootstrap-vps.sh
│   └── xray/
└── macOS/
    ├── .zshrc
    ├── ghostty/
    └── zsh-theme/
```

## Debian

`Debian/` 里主要是两类内容：

- `bootstrap-desktop.sh`：初始化本地 Debian/Ubuntu 桌面环境
- `bootstrap-vps.sh`：初始化 Debian/Ubuntu VPS
- `xray/`：Xray 二进制、service、示例配置和 geofiles

### bootstrap-desktop.sh

适合新装好的 Debian/Ubuntu 桌面设备，主要会做这些事：

- 安装 Xray 并设置代理
- 安装基础工具：`btop`、`curl`、`fd-find`、`git`、`unzip`、`zsh`
- 按系统可用性安装：`eza`、`zoxide`、`zsh-autosuggestions`、`zsh-syntax-highlighting`
- 安装和配置 Xray
- 安装 `uv`、`fnm`、`Docker`
- 使用 `fnm` 安装 Node.js 24，并执行 `corepack enable`
- 为 `pnpm` 写入 `PNPM_HOME`，让 `pnpm add -g` 可直接使用
- 安装 `oh-my-zsh`
- 为目标用户写入常用 `~/.zshrc`

**运行前请参照 `Debian/xray/config.json.example`，生成 `config.json`，并置于同一目录下。**

运行方式：
```bash
cd Debian
sudo ./bootstrap-desktop.sh
exec zsh
```

注意：

- 需要从目标用户下用 `sudo` 执行，脚本会根据 `SUDO_USER` 配置对应账号
- 关于 Xray 的更多操作和信息，详见 [XTLS/Xray-install](https://github.com/XTLS/Xray-install/blob/main/README_zh-Hans.md)

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

## macOS

`macOS/` 目前保存的是我在 macOS 上使用的终端和 shell 相关配置：

- `.zshrc`：macOS 下使用的 zsh 配置
- `ghostty/config`：Ghostty 主配置
- `ghostty/themes/passion`：Ghostty 主题
- `zsh-theme/passion.zsh-theme`：自定义 zsh 主题
