# configs

我的个人配置仓库，主要用来保存 Debian/Ubuntu、macOS 和 Windows 上常用的环境初始化脚本、终端配置，以及 Xray 相关文件。

# 目录结构

```text
.
├── Debian/
│   ├── bootstrap.sh
│   └── xray/
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
- `xray/`：Xray 二进制、service、示例配置和 geofiles，geofiles 来自 [Loyalsoldier/v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat)

### bootstrap.sh

适合新装好的 Debian/Ubuntu 环境：

- 传入 `--with-xray` 时，脚本会先完成 Xray 部署并启用本地代理，再通过该代理执行后续联网安装流程
- 安装基础工具：`btop`、`curl`、`eza`、`fd-find`、`fzf`、`git`、`jq`、`nano`、`ripgrep`、`wget`、`zoxide`、`unzip`、`zsh`
- 安装 `oh-my-zsh` 和 zsh 插件：`zsh-autosuggestions`、`zsh-syntax-highlighting`
- 安装 `uv`、`fnm`、`Docker`、`LazyDocker`、`LazyGit`
- 使用 `fnm` 安装 Node.js 24，执行 `corepack enable` 启用 `pnpm`，并写入 `PNPM_HOME`

运行方式：
```bash
cd Debian
sudo ./bootstrap.sh
exec zsh
```

如需代理，请参照 `Debian/xray/config.json.example` 生成 `config.json`，并置于 `Debian/xray/` 目录下，然后运行：
```bash
cd Debian
sudo ./bootstrap.sh --with-xray
exec zsh
```

注意：

- 从目标用户下用 `sudo` 执行时，脚本会根据 `SUDO_USER` 配置对应账号
- 直接以 root 运行时，脚本会配置 root
- 关于 Xray 的更多操作和信息，详见 [XTLS/Xray-install](https://github.com/XTLS/Xray-install/blob/main/README_zh-Hans.md)

## macOS

`macOS/` 目前保存的是我在 macOS 上使用的终端和 shell 相关配置：

- `.zshrc`：macOS 下的 zsh 配置
- `ghostty/config`：Ghostty 配置
- `ghostty/themes/passion`：Ghostty 主题
- `zsh-theme/passion.zsh-theme`：自定义 zsh 主题

## Windows

`Windows/xray/` 保存的是 Windows 下使用 Xray 的示例配置和启停脚本：

1. 安装 Xray：`winget install XTLS.Xray-core`
2. 修改 `config.json.example`，置于 `$HOME\.config\xray\config.json`
3. `start-xray.ps1` 和 `stop-xray.ps1` 可放在桌面，便于操作
