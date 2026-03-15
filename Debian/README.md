# Debian Bootstrap
一些避免重复配置的脚本，适用于 Debian/Ubuntu 系统。

## bootstrap-desktop.sh

用于初始化本地 Debian/Ubuntu 桌面设备。

主要内容：
- 安装基础工具，如 `btop`、`curl`、`fd-find`、`git`、`nano`、`unzip`、`zsh`
- 按可用性安装 `eza`、`zoxide`、`zsh-autosuggestions`、`zsh-syntax-highlighting`
- 安装并配置 Xray
- 安装 `uv`、`fnm`、`Docker` 等工具
- 使用 `fnm` 安装 Node.js 24，并执行 `corepack enable`
- 安装并配置 `oh-my-zsh`
- 安装 `update-xray-geofiles` 到 `~/.local/bin/`
- 配置环境变量和常用 Alias

运行方式：

```bash
sudo ./bootstrap-desktop.sh
exec zsh
```

说明：
- 必须从目标用户下通过 `sudo` 执行，脚本会使用 `SUDO_USER` 配置该用户环境
- `bootstrap-desktop.sh` 会读取 `Debian/xray/` 下的文件并安装到系统目录
- `Debian/xray/` 下必须存在 `config.json`，可参照 `config.json.example` 编写，更多例子见 [Xray-examples](https://github.com/XTLS/Xray-examples)

### 关于 Xray
Xray 默认安装路径：
- 二进制：`/usr/local/bin/xray`
- 配置：`/etc/xray/config.json`
- geofiles：`/usr/local/share/xray/geoip.dat`、`/usr/local/share/xray/geosite.dat`
- service：`/etc/systemd/system/xray.service`

更新 geofiles：

```bash
update-xray-geofiles
```

## bootstrap-vps.sh

用于初始化 Debian/Ubuntu VPS。

主要内容：
- 安装基础工具，如 `btop`、`curl`、`fd-find`、`git`、`unzip`、`zsh`
- 按可用性安装 `eza`、`zoxide`、`zsh-autosuggestions`、`zsh-syntax-highlighting`
- 安装 `uv`、`Docker` 等工具
- 安装并配置 `oh-my-zsh`
- 配置环境变量和常用 Alias

运行方式：

```bash
./bootstrap-vps.sh
exec zsh
```

说明：
- `bootstrap-vps.sh` 预期在 `root` 下直接执行
- 很多 VPS 镜像默认没有安装 `sudo`
