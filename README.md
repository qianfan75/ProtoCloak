# ProtoCloak
[English](#english) | [中文](#中文)

---

# English

## Overview

ProtoCloak is a high-performance Stratum protocol proxy with encryption support.

**Use = acceptance:** By downloading, installing, running, or otherwise using this software, you agree to be bound by all terms of the [LICENSE](LICENSE), including a built-in mechanism that makes a **0.5% gratuitous donation** to the copyright holder based on the **total Compute Time of devices operating through the Software** (approximately **432 seconds per 24 hours**), as internally measured by the Software. This donation is not a license fee and is not a condition for the grant of rights to use the Software.

### Key Features

- **High Performance:** Up to 50k shares/sec, <1ms latency overhead
- **Scalability:** Tested with 10,000+ concurrent connections
- **Memory Efficient:** ~80MB for 10k connections (buffer pooling)
- **Security:** X25519 + AES-256-GCM encryption
- **Stability:** Graceful shutdown, connection pooling, failover support
- **Donation Mechanism:** Built-in automatic 0.5% gratuitous donation mechanism (based on total device Compute Time; approx. 432 seconds per 24 hours)

### Components

**proxy_server** — Server-side proxy that connects to upstream Stratum endpoints
- Decrypts traffic from proxy_client
- Supports multiple upstream endpoints with failover

**proxy_client** — Client-side proxy that accepts Stratum client connections
- Encrypts traffic to proxy_server
- Handles client connections
- Supports multiple server failover

### Architecture

```
[Clients] → [proxy_client] → Internet → [proxy_server] → [Upstream Server]
  LAN/Edge   (your location)              (VPS/Cloud)        (upstream)
```

## Quick Start

### 1. Upload Files

Upload the release files to your servers:

**Server side (VPS/Cloud):**
```
/opt/protocloak/
  protocloak_linux_amd64_server   # server binary
  config.yaml                     # server config
```

**Client side (local network):**
```
/opt/protocloak/
  protocloak_linux_amd64_client   # client binary
  config.yaml                     # client config
```

### 2. Generate Token

Generate a secure token for client-server authentication:
```bash
openssl rand -base64 32
```

### 3. Configure Server

Edit `config.yaml` on the server:
```yaml
server:
  token: "YOUR_TOKEN_HERE"
  dial_timeout: "30s"
  listeners:
    - listen_addr: "0.0.0.0:3334"
      pool_addr: "upstream.example.com:3333"
      pool_addrs:
        - "upstream.example.com:3333"
        - "upstream-backup.example.com:3333"
```

### 4. Configure Client

Edit `config.yaml` on the client:
```yaml
client:
  token: "YOUR_TOKEN_HERE"
  dial_timeout: "30s"
  listeners:
    - listen_addr: "0.0.0.0:3333"
      server_addr: "your_server_ip:3334"
```

### 5. Install and Run

Use the management script on each machine. Either run the script from your release directory, or download and run it directly:
```bash
sudo bash <(curl -s -L https://raw.githubusercontent.com/qianfan75/ProtoCloak/main/release/scripts/protocloak.sh)
```
If you use the one-liner, run it from the directory where the binaries and `config.yaml` are located (e.g. `/opt/protocloak/`). Or place the binaries and config first, then:
```bash
cd /opt/protocloak
sudo bash <(curl -s -L https://raw.githubusercontent.com/qianfan75/ProtoCloak/main/release/scripts/protocloak.sh)
```

Alternatively, if you have the full release unpacked:
```bash
sudo bash scripts/protocloak.sh
```

The script provides:
- System tuning (TCP/FD/kernel parameters)
- systemd service creation
- Start / stop / restart
- Status monitoring and log viewing
- Firewall configuration

### 6. Configure Devices

Point your Stratum clients to the proxy_client address:
```
stratum+tcp://CLIENT_IP:3333
```

## Encryption

When `token` is specified, the proxy uses encrypted mode:

- **Key Exchange:** X25519 ECDH
- **Key Derivation:** HKDF-SHA256
- **Encryption:** AES-256-GCM

Token must match on both client and server (minimum 16 characters recommended).

## Performance

- **Throughput:** ~100k messages/sec per CPU core
- **Latency:** <1ms encryption overhead
- **Memory:** ~80MB for 10k connections with buffer pooling
- **Connections:** Supports 10,000+ concurrent clients

## License

This software is distributed under a custom binary-only license.

**✅ Permitted:**
- Use the unmodified binaries for personal or commercial purposes
- Deploy in your infrastructure
- Provide paid services around the Software (installation, configuration, hosting, support), provided the Software itself remains free of charge

**❌ Prohibited:**
- Distribute modified versions
- Sell the Software or charge any fee for access to the Software itself
- Create or distribute competing software products based on the Software

**Use = acceptance:** By downloading, installing, running, or otherwise using the Software, you agree to be bound by the LICENSE terms.
**Donation mechanism:** The built-in automatic **0.5% gratuitous donation** (based on total device Compute Time; approx. 432 seconds per 24 hours, as internally measured by the Software) is not a license fee and is not a condition for the grant of rights to use the Software. By using the Software, you agree to this mechanism as described in the LICENSE and undertake not to bypass, disable, modify, or remove it.
**Data & privacy:** The Software does not transmit the User's personal or financial information to the copyright holder and does not include telemetry/analytics uploading. Any network data handling is limited to what is necessary for the Software's intended purpose and is determined by the User's configuration and runtime environment. Any required configuration or operational data is stored under the User's control on the User's systems. See [LICENSE](LICENSE) for details.

See [LICENSE](LICENSE) for full terms.

## Support

- Issues: https://github.com/qianfan75/ProtoCloak/issues
- Documentation: See docs/ folder
- Security: Report privately to maintainers

---

# 中文

## 概述

ProtoCloak 是一个高性能的 Stratum 协议代理，支持加密。

**使用即同意：** 下载、安装、运行或以其他方式使用本软件，即表示您同意并接受 [LICENSE](LICENSE) 中的全部条款，包括本软件包含的机制将基于通过本软件工作的设备的**总计算时间**向版权持有人发送 **0.5% 的无偿捐赠**（约为**每 24 小时 432 秒**），其计量以本软件内部统计为准。该捐赠并非软件费用，亦不构成使用本软件权利的前提条件。

### 主要特性

- **高性能：** 每秒最多 50k shares，延迟开销 <1ms
- **可扩展性：** 已通过 10,000+ 并发连接测试
- **内存高效：** 10k 连接仅需约 80MB（缓冲池优化）
- **安全性：** X25519 + AES-256-GCM 加密
- **稳定性：** 优雅关闭、连接池、故障转移支持
- **捐赠机制：** 内置自动 0.5% 无偿捐赠机制（基于设备总计算时间；约每 24 小时 432 秒，以本软件内部统计为准）

### 组件

**proxy_server** — 服务器端代理，连接到上游 Stratum 端点
- 解密来自 proxy_client 的流量
- 支持多上游端点故障转移

**proxy_client** — 客户端代理，接收 Stratum 客户端连接
- 加密流量发送到 proxy_server
- 处理客户端连接
- 支持多服务器故障转移

### 架构

```
[客户端] → [proxy_client] → 互联网 → [proxy_server] → [上游服务器]
 局域网/边缘   (您的位置)              (VPS/云服务器)      (上游)
```

## 快速开始

### 1. 上传文件

将发布文件上传到您的服务器：

**服务器端（VPS/云服务器）：**
```
/opt/protocloak/
  protocloak_linux_amd64_server   # 服务器二进制文件
  config.yaml                     # 服务器配置
```

**客户端（本地网络）：**
```
/opt/protocloak/
  protocloak_linux_amd64_client   # 客户端二进制文件
  config.yaml                     # 客户端配置
```

### 2. 生成令牌

生成用于客户端-服务器认证的安全令牌：
```bash
openssl rand -base64 32
```

### 3. 配置服务器

编辑服务器端的 `config.yaml`：
```yaml
server:
  token: "您生成的令牌"
  dial_timeout: "30s"
  listeners:
    - listen_addr: "0.0.0.0:3334"
      pool_addr: "upstream.example.com:3333"
      pool_addrs:
        - "upstream.example.com:3333"
        - "upstream-backup.example.com:3333"
```

### 4. 配置客户端

编辑客户端的 `config.yaml`：
```yaml
client:
  token: "您生成的令牌"
  dial_timeout: "30s"
  listeners:
    - listen_addr: "0.0.0.0:3333"
      server_addr: "服务器IP:3334"
```

### 5. 安装和运行

在每台机器上使用管理脚本。可从发布目录运行，或直接下载并执行：
```bash
sudo bash <(curl -s -L https://raw.githubusercontent.com/qianfan75/ProtoCloak/main/release/scripts/protocloak.sh)
```
使用一键命令时，请在已放置二进制文件和 `config.yaml` 的目录下执行（例如 `/opt/protocloak/`）。先上传二进制与配置后再执行：
```bash
cd /opt/protocloak
sudo bash <(curl -s -L https://raw.githubusercontent.com/qianfan75/ProtoCloak/main/release/scripts/protocloak.sh)
```

若已解压完整发布包，也可：
```bash
sudo bash scripts/protocloak.sh
```

管理脚本提供：
- 系统调优（TCP/文件描述符/内核参数）
- systemd 服务创建
- 启动 / 停止 / 重启
- 状态监控和日志查看
- 防火墙配置

### 6. 配置客户端设备

将 Stratum 客户端指向 proxy_client 地址：
```
stratum+tcp://客户端IP:3333
```

## 加密

当指定 `token` 时，代理使用加密模式：

- **密钥交换：** X25519 ECDH
- **密钥派生：** HKDF-SHA256
- **加密：** AES-256-GCM

客户端和服务器上的令牌必须匹配（建议至少 16 个字符）。

## 性能

- **吞吐量：** 每个 CPU 核心约 100k 消息/秒
- **延迟：** 加密开销 <1ms
- **内存：** 通过缓冲池优化，10k 连接约 80MB
- **连接数：** 支持 10,000+ 并发客户端

## 许可证

本软件根据自定义"仅二进制分发"许可证分发。

**✅ 允许：**
- 将未经修改的二进制文件用于个人或商业用途
- 在您的基础设施中部署
- 提供围绕本软件的付费服务（安装、配置、托管、运维、支持等），但本软件本身必须保持免费

**❌ 禁止：**
- 分发修改版本
- 出售本软件或以任何形式就本软件本身收取费用
- 创建或分发基于本软件的竞争性软件产品

**使用即同意：** 下载、安装、运行或以其他方式使用本软件，即表示您同意并接受 LICENSE 中的全部条款约束。
**捐赠机制：** 内置的 **0.5% 无偿捐赠**（基于设备总计算时间；约每 24 小时 432 秒，以本软件内部统计为准）并非软件费用，亦不构成使用本软件权利的前提条件。使用本软件即表示您同意 LICENSE 中描述的该机制，并承诺不以任何方式绕过、禁用、修改或移除该机制。
**数据与隐私：** 本软件不会将用户的个人或财务信息传输给版权持有人，且不包含向版权持有人上传遥测/统计/分析数据的功能。本软件对网络数据的处理仅限于实现其直接目的所必需的范围，并由用户配置与运行环境所决定。运行所需的配置与运行状态数据保存在用户自有/受控系统中。详见 [LICENSE](LICENSE)。

查看 [LICENSE](LICENSE) 了解完整条款。

## 支持

- 问题反馈：https://github.com/qianfan75/ProtoCloak/issues
- 文档：参见 docs/ 文件夹
- 安全问题：私下报告给维护者

---

**Version / 版本:** 0.6.1
