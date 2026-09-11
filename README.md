# configs

个人环境配置仓库：

- `Debian/`：Debian / Ubuntu 新机器初始化规格书
- `Xray/`：Xray 客户端与服务端配置示例
- `Shadowrocket/`：Shadowrocket 分流配置

## Debian

```text
按 github.com/barkure/configs/Debian/setup.md 配置这台机器
```

## Xray

VLESS + XHTTP + TLS 的客户端与服务端配置示例。
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
- `[Rule]`：新增 `# XAI/Grok` 段（x.ai / grok.com 走代理）；`# LAN` 段新增 `DOMAIN-SUFFIX,lan,DIRECT`（局域网域名直连）
- `[Host]`：apple / icloud 域名强制使用系统 DNS；`*.lan` 用系统 DNS（即当前路由器）解析
