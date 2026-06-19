# configs

个人环境配置仓库，主要包含三部分：

- `Debian/`：Debian / Ubuntu 新机器初始化脚本
- `macOS/`：macOS 下使用的 `zsh` 和 Ghostty 配置
- `Xray/`：Xray 客户端配置示例

## 目录结构

```text
.
├── Debian/
│   └── init.sh
├── macOS/
│   ├── .zshrc
│   └── ghostty/
│       └── config
└── Xray/
    └── config.json.example
```

## Debian

`Debian/init.sh` 用于初始化一台新的 Debian / Ubuntu 机器。

特点：

- 支持 `Ubuntu 24.04+` 和 `Debian 13+`
- 需要以 `root` 或 `sudo` 运行
- 如果通过 `sudo` 运行，优先配置 `SUDO_USER`；否则配置 `root`
- 已安装的软件会自动跳过
- 单个步骤失败后会继续执行，最后统一汇总失败项
- 可选安装 `Docker`
- 可选切换 `apt` 源到中科大镜像
- 可选为脚本执行过程和生成的 `~/.zshrc` 启用代理
- 安装 `bun` 后会创建 `~/.local/bin/node` 指向 `bun`

代理参数：

- HTTP(S): `http://127.0.0.1:10809`
- SOCKS5: `socks5://127.0.0.1:10808`
- NO_PROXY: `127.0.0.1,localhost,::1`

脚本会安装一组常用工具，包括：

<table>
  <tr>
    <td><code>bat</code></td>
    <td><code>btop</code></td>
    <td><code>curl</code></td>
  </tr>
  <tr>
    <td><code>eza</code></td>
    <td><code>fd-find</code></td>
    <td><code>fzf</code></td>
  </tr>
  <tr>
    <td><code>git</code></td>
    <td><code>jq</code></td>
    <td><code>mosh</code></td>
  </tr>
  <tr>
    <td><code>ripgrep</code></td>
    <td><code>wget</code></td>
    <td><code>zoxide</code></td>
  </tr>
  <tr>
    <td><code>zsh</code></td>
    <td><code>unzip</code></td>
    <td><code>zstd</code></td>
  </tr>
  <tr>
    <td><code>oh-my-zsh</code></td>
    <td><code>pixi</code></td>
    <td><code>bun</code></td>
  </tr>
  <tr>
    <td><code>bubblewrap</code></td>
    <td><code>uv</code></td>
    <td><code>msedit</code></td>
  </tr>
  <tr>
    <td colspan="3"><code>ca-certificates</code></td>
  </tr>
  <tr>
    <td colspan="3"><code>zsh-autosuggestions</code></td>
  </tr>
  <tr>
    <td colspan="3"><code>zsh-syntax-highlighting</code></td>
  </tr>
</table>

脚本还会写入目标用户的 `~/.zshrc`，包含：

- 代理函数 `proxy` / `unproxy`
- 常用 `PATH`
- `oh-my-zsh`
- `uv` / `uvx` 补全
- `zoxide`
- 常用别名

使用方式：

```bash
cd Debian
sudo ./init.sh [OPTIONS]
exec zsh
```

可选参数：

```bash
--proxy   Enable proxy environment only, without installing Xray
--docker  Install Docker
--ustc    Switch Debian/Ubuntu apt sources to USTC mirror
-h, --help  Show help message
```

## macOS

`macOS/` 目录保存我在 macOS 上使用的终端与 Shell 配置。

### `macOS/.zshrc`

当前配置包含：

- 使用 Homebrew 安装的 `edit` 作为默认编辑器
- 默认启用本地代理
- 增加用户本地二进制目录和 Go 用户二进制目录
- 启用 `oh-my-zsh`
- 启用 `uv` / `uvx` 补全
- 增加 `bun` 的 PATH
- 启用 `zoxide`
- 提供 `eza`、`bat`、目录跳转等常用别名
- 启用 `zsh-autosuggestions` 和 `zsh-syntax-highlighting`

### `macOS/ghostty/config`

当前 Ghostty 配置包含：

- 字体：`Maple Mono NF CN`
- 主题：`Vercel`
- 半透明背景
- 自定义窗口内边距
- 启用部分 shell integration
- `macOS-option-as-alt` 键绑定
