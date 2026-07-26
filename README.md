# configs

个人环境配置仓库：

- `Debian/`：Debian / Ubuntu 新机器初始化脚本
- `Xray/`：Xray 客户端与服务端配置示例
- `Shadowrocket/`：Shadowrocket 分流配置

## Debian

`Debian/init.sh` 初始化新机器（支持 Ubuntu 24.04+ / Debian 13+），安装常用工具并写入 `~/.zshrc`。

```bash
sudo ./init.sh [OPTIONS]          # 完整初始化（root / sudo）
./init.sh --basic [--proxy] [--mirror]   # 无 sudo：只装用户态工具
```

可选参数：`--basic`（免 root）、`--proxy`（只配代理环境）、`--docker`、`--mirror`（镜像源）、`-h`。

## Xray

`Xray/` 提供 VLESS + REALITY 的客户端与服务端配置示例，复制 `.example` 文件并填入真实参数（UUID、密钥、SNI 等）后使用。

## Shadowrocket

官方默认配置 + 少量补丁，不使用第三方大型规则集。

- `default.conf`：官方内置配置副本，仅作基准参考
- `custom.conf`：实际使用的配置，订阅地址：

```text
https://raw.githubusercontent.com/barkure/configs/main/Shadowrocket/custom.conf
```

`custom.conf` 相对官方的改动：

- `dns-server`：改用加密 DNS（doh.pub / alidns DoH），抗污染
- `dns-direct-fallback-proxy = true`：直连域名解析失败自动走代理
- `block-quic = all-proxy`：屏蔽走代理连接的 QUIC，回退 TCP
- `skip-proxy`：追加银行域名（ccb / abchina / psbc）
- `[Rule]`：新增 `# XAI/Grok` 段（x.ai / grok.com 走代理）
- `[Host]`：apple / icloud 域名强制使用系统 DNS

官方 App 更新后，用 `diff default.conf custom.conf` 对比决定是否同步。
