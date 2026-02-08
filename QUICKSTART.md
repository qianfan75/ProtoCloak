# Quick Start Guide / 快速入门指南

[English](#english) | [中文](#中文)

---

# English

## Installation in 5 Minutes

### Step 1: Upload Files

Upload the release files to your server:

**Server side (VPS/Cloud) — `/opt/protocloak/`:**
```
protocloak_linux_amd64_server
config.yaml
scripts/protocloak.sh
```

**Client side (local network) — `/opt/protocloak/`:**
```
protocloak_linux_amd64_client
config.yaml
scripts/protocloak.sh
```

### Step 2: Generate Token

```bash
# Generate a secure random token
TOKEN=$(openssl rand -base64 32)
echo "Your token: $TOKEN"
# Use this token in both server and client configs
```

### Step 3: Configure Server (VPS)

Edit `config.yaml` on the server:

```yaml
server:
  token: "PASTE_YOUR_TOKEN_HERE"
  dial_timeout: "30s"
  listeners:
    - listen_addr: "0.0.0.0:3334"
      pool_addr: "upstream.example.com:3333"
      pool_addrs:
        - "upstream.example.com:3333"
        - "upstream-backup.example.com:3333"
```

Replace `PASTE_YOUR_TOKEN_HERE` with your generated token.

### Step 4: Configure Client (Local Network)

Edit `config.yaml` on the client:

```yaml
client:
  token: "PASTE_YOUR_TOKEN_HERE"
  dial_timeout: "30s"
  listeners:
    - listen_addr: "0.0.0.0:3333"
      server_addr: "YOUR_VPS_IP:3334"
```

Replace:
- `PASTE_YOUR_TOKEN_HERE` — same token as server
- `YOUR_VPS_IP` — your VPS IP address

### Step 5: Install and Start

Run the management script on each machine. Download and run in one command (run from the directory where binaries and `config.yaml` are, e.g. `/opt/protocloak/`):

```bash
cd /opt/protocloak
sudo bash <(curl -s -L https://raw.githubusercontent.com/qianfan75/ProtoCloak/main/scripts/protocloak.sh)
```

Or, if you have the release unpacked locally:

```bash
sudo bash scripts/protocloak.sh
```

Choose:
1. **Install** — creates systemd service, tunes system parameters
2. **Start** — starts the service

The script handles systemd service creation, system tuning (TCP/FD/kernel), and process management.

### Step 6: Configure Devices

Point your Stratum clients to the proxy_client:

```
stratum+tcp://CLIENT_IP:3333
```

**Done! Your devices are now connected through the encrypted proxy.**

## Donation Mechanism

**This software includes a built-in 0.5% gratuitous donation mechanism.**

- The donation is based on 0.5% of the total Compute Time of devices operating through the Software (approx. 432 seconds per 24 hours)
- This mechanism supports ongoing development and maintenance of this software
- By using the Software, you acknowledge and agree to this mechanism
- See [LICENSE](LICENSE) for details

## Verification

Check that everything is working:

```bash
# Check service status
sudo bash scripts/protocloak.sh
# Choose option 7 (Status)

# Check connections
ss -ant | grep ESTABLISHED | grep -E ':333[34]'
```

## Service Management

Use the management script for all operations:

```bash
sudo bash scripts/protocloak.sh
```

Available options:
- **Start / Stop / Restart** the service
- **View status** with PID, memory, connections
- **View and clear logs**
- **System tuning** (TCP/FD/kernel parameters)
- **Firewall** port configuration
- **Uninstall**

## Troubleshooting

### Clients can't connect

```bash
# Check if proxy is running
sudo bash scripts/protocloak.sh  # Choose 7 (Status)

# Check if port is listening
ss -anl | grep 3333

# Check firewall
sudo bash scripts/protocloak.sh  # Choose 10 (Firewall)

# Check logs
sudo bash scripts/protocloak.sh  # Choose 8 (Logs)
```

### Server can't reach upstream

```bash
# Test upstream connectivity
nc -zv upstream.example.com 3333

# Check DNS
nslookup upstream.example.com

# Check logs
sudo bash scripts/protocloak.sh  # Choose 8 (Logs)
```

### High rejection rate

1. Check that you're using the correct wallet address
2. Check network latency to upstream
3. Try a different address from the failover list

## Support

- Documentation: See README.md
- Issues: https://github.com/qianfan75/ProtoCloak/issues
- License: See LICENSE file

---

# 中文

## 5分钟安装教程

### 步骤 1：上传文件

将发布文件上传到您的服务器：

**服务器端（VPS/云服务器）— `/opt/protocloak/`：**
```
protocloak_linux_amd64_server
config.yaml
scripts/protocloak.sh
```

**客户端（本地网络）— `/opt/protocloak/`：**
```
protocloak_linux_amd64_client
config.yaml
scripts/protocloak.sh
```

### 步骤 2：生成令牌

```bash
# 生成安全随机令牌
TOKEN=$(openssl rand -base64 32)
echo "您的令牌: $TOKEN"
# 在服务器和客户端配置中使用此令牌
```

### 步骤 3：配置服务器（VPS）

编辑服务器端的 `config.yaml`：

```yaml
server:
  token: "粘贴您的令牌"
  dial_timeout: "30s"
  listeners:
    - listen_addr: "0.0.0.0:3334"
      pool_addr: "upstream.example.com:3333"
      pool_addrs:
        - "upstream.example.com:3333"
        - "upstream-backup.example.com:3333"
```

将 `粘贴您的令牌` 替换为您生成的令牌。

### 步骤 4：配置客户端（本地网络）

编辑客户端的 `config.yaml`：

```yaml
client:
  token: "粘贴您的令牌"
  dial_timeout: "30s"
  listeners:
    - listen_addr: "0.0.0.0:3333"
      server_addr: "您的VPS_IP:3334"
```

替换：
- `粘贴您的令牌` — 与服务器相同的令牌
- `您的VPS_IP` — 您的 VPS IP 地址

### 步骤 5：安装和启动

在每台机器上运行管理脚本。一键下载并执行（请在已放置二进制与 `config.yaml` 的目录下执行，如 `/opt/protocloak/`）：

```bash
cd /opt/protocloak
sudo bash <(curl -s -L https://raw.githubusercontent.com/qianfan75/ProtoCloak/main/scripts/protocloak.sh)
```

若已解压发布包到本地，也可：

```bash
sudo bash scripts/protocloak.sh
```

选择：
1. **安装** — 创建 systemd 服务，调优系统参数
2. **启动** — 启动服务

管理脚本负责创建 systemd 服务、系统调优（TCP/文件描述符/内核参数）和进程管理。

### 步骤 6：配置设备

将 Stratum 客户端指向 proxy_client：

```
stratum+tcp://客户端IP:3333
```

**完成！您的设备现在通过加密代理连接。**

## 捐赠机制

**本软件包含内置的 0.5% 无偿捐赠机制。**

- 捐赠基于通过本软件工作的设备总计算时间的 0.5%（约每 24 小时 432 秒）
- 该机制用于支持本软件的持续开发与维护
- 使用本软件即表示您知悉并同意该机制
- 详见 [LICENSE](LICENSE)

## 验证

检查一切是否正常工作：

```bash
# 检查服务状态
sudo bash scripts/protocloak.sh
# 选择选项 7（查看运行状态）

# 检查连接
ss -ant | grep ESTABLISHED | grep -E ':333[34]'
```

## 服务管理

使用管理脚本进行所有操作：

```bash
sudo bash scripts/protocloak.sh
```

可用选项：
- **启动 / 停止 / 重启** 服务
- **查看状态**（PID、内存、连接数）
- **查看和清理日志**
- **系统调优**（TCP/文件描述符/内核参数）
- **防火墙** 端口配置
- **卸载**

## 故障排除

### 客户端无法连接

```bash
# 检查代理是否运行
sudo bash scripts/protocloak.sh  # 选择 7（查看运行状态）

# 检查端口是否监听
ss -anl | grep 3333

# 检查防火墙
sudo bash scripts/protocloak.sh  # 选择 10（开放防火墙端口）

# 检查日志
sudo bash scripts/protocloak.sh  # 选择 8（查看日志）
```

### 服务器无法到达上游

```bash
# 测试上游连接性
nc -zv upstream.example.com 3333

# 检查 DNS
nslookup upstream.example.com

# 检查日志
sudo bash scripts/protocloak.sh  # 选择 8（查看日志）
```

### 拒绝率高

1. 检查您使用的钱包地址是否正确
2. 检查到上游的网络延迟
3. 尝试故障转移列表中的不同地址

## 支持

- 文档：查看 README.md
- 问题反馈：https://github.com/qianfan75/ProtoCloak/issues
- 许可证：查看 LICENSE 文件

---

**Version / 版本:** 0.6.1
