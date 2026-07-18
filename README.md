# configs

个人环境配置仓库，主要包含两部分：

- `Debian/`：Debian / Ubuntu 新机器初始化脚本
- `Xray/`：Xray 客户端与服务端配置示例

## 目录结构

```text
.
├── Debian/
│   └── init.sh
└── Xray/
    ├── client.json.example
    └── server.json.example
```

## Debian

`Debian/init.sh` 用于初始化一台新的 Debian / Ubuntu 机器。

特点：

- 支持 `Ubuntu 24.04+` 和 `Debian 13+`
- 完整模式需要 `root` 或 `sudo`；`--basic` 可在无 sudo 用户下运行
- 如果通过 `sudo` 运行，优先配置 `SUDO_USER`；否则配置 `root`
- 已安装的软件会自动跳过
- 单个步骤失败后会继续执行，最后统一汇总失败项
- 可选安装 `Docker`（完整模式）
- 可选配置镜像源：完整模式为 `apt` / `uv`；`--basic` 仅为 `uv`
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
    <td><code>ripgrep</code></td>
  </tr>
  <tr>
    <td><code>wget</code></td>
    <td><code>zoxide</code></td>
    <td><code>zsh</code></td>
  </tr>
  <tr>
    <td><code>unzip</code></td>
    <td><code>zstd</code></td>
    <td><code>oh-my-zsh</code></td>
  </tr>
  <tr>
    <td><code>bun</code></td>
    <td><code>msedit</code></td>
    <td><code>bubblewrap</code></td>
  </tr>
  <tr>
    <td><code>uv</code></td>
    <td><code>ca-certificates</code></td>
    <td></td>
  </tr>
</table>

脚本还会写入目标用户的 `~/.zshrc`，包含：

- 代理函数 `proxy` / `unproxy`
- 常用 `PATH`
- `oh-my-zsh`
- `zsh-autosuggestions` 和 `zsh-syntax-highlighting`
- `uv` / `uvx` 补全
- `zoxide`
- 常用别名

使用方式：

```bash
cd Debian

# 完整初始化（需要 root / sudo）
sudo ./init.sh [OPTIONS]
exec zsh

# 无 sudo 的受限服务器：只装用户态工具
./init.sh --basic [--proxy] [--mirror]
# 若已有 zsh：
exec zsh
# 否则：
source ~/.zshrc
```

可选参数：

```bash
--basic   User-space only (no root). Installs uv, bun, msedit, btop, oh-my-zsh when possible
--proxy   Enable proxy environment only, without installing Xray
--docker  Install Docker (full mode only)
--mirror  Configure mirrors (full: apt/uv; basic: uv only)
-h, --help  Show help message
```

### `--basic` 会装什么

不跑 `apt`、不改系统 shell、不装 Docker。尽量只写入当前用户 home：

| 项目 | 说明 |
|------|------|
| `uv` | 官方脚本，用户目录 |
| `bun` | 官方脚本；并链接 `~/.local/bin/node` → `bun` |
| `msedit` | 装到 `~/.local/bin`（无 jq 时也能解析下载地址） |
| `btop` | 官方 musl 静态二进制，装到 `~/.local/bin` |
| `oh-my-zsh` + 插件 | 仅当系统已有 `zsh` / `git` |
| `~/.zshrc` | 保守写法：PATH / 可选 oh-my-zsh / 可选补全，不依赖 eza、bat 等 apt 包 |

依赖：至少有 `curl` 和 `tar`（`btop` 的 `.tbz` 还需要 bzip2 支持）。系统若没有 `zsh` / `git`，相关步骤会跳过而不是整脚本失败。

## Xray

`Xray/` 提供客户端与服务端两套配置示例（VLESS + REALITY）。使用前复制并填入真实参数。

### `client.json.example`

本地客户端：

- 入站：SOCKS `127.0.0.1:10808`、HTTP `127.0.0.1:10809`
- 出站：VLESS + REALITY 连远端服务器
- 需填写：服务器地址 / 端口、用户 UUID、SNI、`publicKey`、`shortId` 等

### `server.json.example`

服务端：

- 入站：VLESS + REALITY（示例监听 `127.0.0.1:10443`，通常前面再挂反代或改监听）
- 出站：直连 / 黑洞
- 需填写：客户端 UUID、`privateKey`、`serverNames`、`shortIds`、`target` 等
