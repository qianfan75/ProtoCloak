#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/../../VERSION"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE" 2>/dev/null | tr -d '[:space:]')
fi
[ -z "$VERSION" ] && VERSION="0.5.1"

INSTALL_DIR="/opt/protocloak"
SYSCTL_CONF="/etc/sysctl.d/99-protocloak.conf"
EXPECTED_DEVICES=50000
FD_MULTIPLIER=2
FD_BUFFER=10000
REQUIRED_FD=$((EXPECTED_DEVICES * FD_MULTIPLIER + FD_BUFFER))

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
BOLD="\033[1m"
DIM="\033[2m"
RESET="\033[0m"

ok()   { echo -e "  ${GREEN}[+]${RESET} $1"; }
warn() { echo -e "  ${YELLOW}[!]${RESET} $1"; }
err()  { echo -e "  ${RED}[X]${RESET} $1"; }
info() { echo -e "  ${CYAN}[*]${RESET} $1"; }
hl()   { echo -e "${CYAN}$1${RESET}"; }

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${RESET}"
echo -e "  ${BOLD}ProtoCloak${RESET} Manager ${DIM}v${VERSION}${RESET}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${RESET}"
echo ""
echo "选择语言 / Select language:"
echo "  1) 中文"
echo "  2) English"
echo "  0) 退出 / Exit"
echo ""
read -p "选择 / Choice [1]: " LANG_CHOICE
LANG_CHOICE=${LANG_CHOICE:-1}

case "$LANG_CHOICE" in
    0)    echo ""; exit 0 ;;
    1|"") UI_LANG="zh" ;;
    2)    UI_LANG="en" ;;
    *)    echo "Invalid choice, using Chinese (1)"; UI_LANG="zh" ;;
esac

echo ""
if [ "$UI_LANG" = "zh" ]; then
    echo "选择安装模式 / Select mode:"
    echo "  1) 服务器 (Server) — 部署在上游侧 VPS"
    echo "  2) 客户端 (Client) — 部署在设备侧"
    echo "  0) 退出"
else
    echo "Select mode:"
    echo "  1) Server — deploy on pool-side VPS"
    echo "  2) Client — deploy at device site"
    echo "  0) Exit"
fi
echo ""
read -p "$([ "$UI_LANG" = "zh" ] && echo '选择' || echo 'Choice') [1]: " MODE_CHOICE
MODE_CHOICE=${MODE_CHOICE:-1}

case "$MODE_CHOICE" in
    0)    echo ""; exit 0 ;;
    1|"") APP_MODE="server" ;;
    2)    APP_MODE="client" ;;
    *)    echo "Invalid choice, using Server (1)"; APP_MODE="server" ;;
esac

BINARY_NAME="protocloak_linux_amd64_${APP_MODE}"
SERVICE_NAME="protocloak-${APP_MODE}"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
CONFIG_FILE="config.yaml"
DEFAULT_CONFIG="config.${APP_MODE}.yaml"
ENV_FILE="${INSTALL_DIR}/${SERVICE_NAME}.env"
PID_FILE="${INSTALL_DIR}/${SERVICE_NAME}.pid"

T() {
    local key="$1"; shift
    if [ "$UI_LANG" = "zh" ]; then
        case "$key" in
            menu_title)       echo "---------- 管理菜单 ----------" ;;
            menu_install)     if [ "$APP_MODE" = "server" ]; then echo "安装 ProtoCloak 服务器"; else echo "安装 ProtoCloak 客户端"; fi ;;
            menu_update)      echo "更新版本" ;;
            menu_start)       echo "启动服务" ;;
            menu_stop)        echo "停止服务" ;;
            menu_restart)     echo "重启服务" ;;
            menu_tune)        echo "系统调优（TCP/文件描述符/内核参数）" ;;
            menu_status)      echo "查看运行状态" ;;
            menu_logs)        echo "查看日志" ;;
            menu_clear_logs)  echo "清理日志" ;;
            menu_firewall)    echo "开放防火墙端口" ;;
            menu_uninstall)   echo "卸载" ;;
            menu_choose)      echo "请选择" ;;
            menu_invalid)     echo "无效的选项，请重新输入" ;;

            need_root)        echo "需要 root 权限执行此操作" ;;
            run_as)           echo "请使用以下命令运行:" ;;

            install_begin)    echo "开始安装 ProtoCloak..." ;;
            install_detect)   echo "检测系统架构..." ;;
            install_arch)     echo "系统架构: $1" ;;
            install_dir)      echo "创建安装目录 ${INSTALL_DIR}..." ;;
            install_dir_ok)   echo "安装目录已就绪" ;;
            install_copy)     echo "请将以下文件复制到 ${INSTALL_DIR}/" ;;
            install_copy_bin) echo "  二进制文件: ${BINARY_NAME}" ;;
            install_copy_cfg) echo "  配置文件:   ${DEFAULT_CONFIG} → ${CONFIG_FILE}" ;;
            install_manual)   echo "手动复制文件后，运行此脚本选择 [3] 启动服务" ;;
            install_done)     echo "安装环境准备完成" ;;
            install_running)  echo "检测到 ProtoCloak 正在运行" ;;
            install_stop_q)   echo "是否先停止运行？ (y/n)" ;;

            update_begin)     echo "开始更新 ProtoCloak..." ;;
            update_stop)      echo "停止当前服务..." ;;
            update_copy)      echo "请将新版本二进制文件复制到:" ;;
            update_restart)   echo "更新完成，正在重启..." ;;
            update_done)      echo "更新完成" ;;

            start_begin)      echo "启动 ProtoCloak..." ;;
            start_already)    echo "ProtoCloak 已在运行中 (PID: $1)" ;;
            start_no_bin)     echo "未找到二进制文件: ${INSTALL_DIR}/${BINARY_NAME}" ;;
            start_no_cfg)     echo "未找到配置文件: ${INSTALL_DIR}/${CONFIG_FILE}" ;;
            start_systemd)    echo "通过 systemd 启动..." ;;
            start_nohup)      echo "通过 nohup 启动（systemd 不可用）..." ;;
            start_ok)         echo "ProtoCloak 启动成功 (PID: $1)" ;;
            start_fail)       echo "ProtoCloak 启动失败" ;;
            start_check)      echo "请检查日志: journalctl -u ${SERVICE_NAME} -n 50" ;;

            stop_begin)       echo "停止 ProtoCloak..." ;;
            stop_not_running) echo "ProtoCloak 未在运行" ;;
            stop_pid)         echo "正在停止进程 (PID: $1)..." ;;
            stop_ok)          echo "ProtoCloak 已停止" ;;
            stop_force)       echo "进程未响应，强制终止..." ;;

            restart_begin)    echo "重启 ProtoCloak..." ;;

            status_title)     echo "ProtoCloak 运行状态" ;;
            status_running)   echo "状态: ${GREEN}运行中${RESET} (PID: $1)" ;;
            status_stopped)   echo "状态: ${RED}已停止${RESET}" ;;
            status_version)   echo "版本: $1" ;;
            status_uptime)    echo "运行时间: $1" ;;
            status_memory)    echo "内存使用: $1" ;;
            status_conns)     echo "活跃连接数: $1" ;;
            status_fd)        echo "文件描述符: $1" ;;

            logs_title)       echo "ProtoCloak 日志" ;;
            logs_follow)      echo "按 Ctrl+C 退出日志查看" ;;
            logs_empty)       echo "暂无日志" ;;
            logs_clear)       echo "日志已清理" ;;

            tune_title)       echo "系统调优 - ${EXPECTED_DEVICES} 设备优化" ;;
            tune_step1)       echo "[1/6] 配置文件描述符..." ;;
            tune_step2)       echo "[2/6] 配置内核 TCP 参数..." ;;
            tune_step3)       echo "[3/6] 配置 PAM 模块..." ;;
            tune_step4)       echo "[4/6] 配置 NTP 时间同步..." ;;
            tune_step5)       echo "[5/6] 创建 systemd 服务..." ;;
            tune_step6)       echo "[6/6] 创建环境变量文件..." ;;
            tune_cur_limits)  echo "当前限制:" ;;
            tune_req_fd)      echo "${EXPECTED_DEVICES} 设备所需: ${REQUIRED_FD} 文件描述符" ;;
            tune_tcp_target)  echo "TCP 缓冲: ~2 GB (Stratum 优化) | 端口: 1024-65535" ;;
            tune_sysctl_ok)   echo "所有内核参数已成功应用" ;;
            tune_sysctl_err)  echo "部分参数无法应用（可能缺少内核模块）" ;;
            tune_pam_ok)      echo "PAM pam_limits.so 已配置" ;;
            tune_pam_skip)    echo "PAM 配置不适用（非 Debian/Ubuntu）" ;;
            tune_ntp_ok)      echo "NTP 时间同步已激活" ;;
            tune_ntp_enabled) echo "已启用 NTP 时间同步: $1" ;;
            tune_ntp_install) echo "正在安装 NTP 客户端..." ;;
            tune_ntp_fail)    echo "无法自动配置 NTP，请手动安装 chrony 或 ntp" ;;
            tune_mem_detect)  echo "系统内存: ${1} GB → GOMEMLIMIT: ${2} GiB (75%)" ;;
            tune_user_new)    echo "已创建用户: protocloak" ;;
            tune_user_exist)  echo "用户 protocloak 已存在" ;;
            tune_user_fail)   echo "创建用户失败，使用 root" ;;
            tune_svc_created) echo "systemd 服务已创建: ${SERVICE_FILE}" ;;
            tune_svc_user)    echo "服务运行用户: $1" ;;
            tune_env_created) echo "环境变量文件已创建: ${ENV_FILE}" ;;
            tune_done)        echo "系统调优完成" ;;

            fw_title)         echo "配置防火墙..." ;;
            fw_open)          echo "开放端口: $1" ;;
            fw_ufw)           echo "检测到 UFW，正在配置..." ;;
            fw_firewalld)     echo "检测到 firewalld，正在配置..." ;;
            fw_iptables)      echo "使用 iptables 配置..." ;;
            fw_none)          echo "未检测到防火墙管理工具" ;;
            fw_done)          echo "防火墙配置完成" ;;

            uninstall_title)  echo "卸载 ProtoCloak" ;;
            uninstall_confirm) echo "确认卸载？将删除 ${INSTALL_DIR} 中的所有文件 (y/n)" ;;
            uninstall_cancel) echo "取消卸载" ;;
            uninstall_done)   echo "卸载完成" ;;

            box_conn_addr)    echo "设备连接地址" ;;
            box_next_steps)   echo "下一步" ;;
            box_important)    echo "重要提示" ;;
            box_config)       echo "配置参数" ;;
            box_reboot)       echo "重启系统使文件描述符限制生效" ;;
            box_fw_ports)     echo "开放防火墙端口: 3333 (设备), 3334 (内部)" ;;
            box_install_bin)  echo "安装二进制文件到 /opt/protocloak/" ;;
        esac
    else
        case "$key" in
            menu_title)       echo "---------- Management Menu ----------" ;;
            menu_install)     if [ "$APP_MODE" = "server" ]; then echo "Install ProtoCloak Server"; else echo "Install ProtoCloak Client"; fi ;;
            menu_update)      echo "Update Version" ;;
            menu_start)       echo "Start Service" ;;
            menu_stop)        echo "Stop Service" ;;
            menu_restart)     echo "Restart Service" ;;
            menu_tune)        echo "System Tuning (TCP/FD/Kernel)" ;;
            menu_status)      echo "Check Status" ;;
            menu_logs)        echo "View Logs" ;;
            menu_clear_logs)  echo "Clear Logs" ;;
            menu_firewall)    echo "Open Firewall Ports" ;;
            menu_uninstall)   echo "Uninstall" ;;
            menu_choose)      echo "Choose option" ;;
            menu_invalid)     echo "Invalid option, please try again" ;;

            need_root)        echo "Root privileges required" ;;
            run_as)           echo "Run as:" ;;

            install_begin)    echo "Installing ProtoCloak..." ;;
            install_detect)   echo "Detecting system architecture..." ;;
            install_arch)     echo "Architecture: $1" ;;
            install_dir)      echo "Creating install directory ${INSTALL_DIR}..." ;;
            install_dir_ok)   echo "Install directory ready" ;;
            install_copy)     echo "Copy the following files to ${INSTALL_DIR}/" ;;
            install_copy_bin) echo "  Binary: ${BINARY_NAME}" ;;
            install_copy_cfg) echo "  Config: ${DEFAULT_CONFIG} → ${CONFIG_FILE}" ;;
            install_manual)   echo "After copying files, run this script and choose [3] to start" ;;
            install_done)     echo "Installation environment ready" ;;
            install_running)  echo "ProtoCloak is currently running" ;;
            install_stop_q)   echo "Stop it first? (y/n)" ;;

            update_begin)     echo "Updating ProtoCloak..." ;;
            update_stop)      echo "Stopping current service..." ;;
            update_copy)      echo "Copy the new binary to:" ;;
            update_restart)   echo "Update complete, restarting..." ;;
            update_done)      echo "Update complete" ;;

            start_begin)      echo "Starting ProtoCloak..." ;;
            start_already)    echo "ProtoCloak is already running (PID: $1)" ;;
            start_no_bin)     echo "Binary not found: ${INSTALL_DIR}/${BINARY_NAME}" ;;
            start_no_cfg)     echo "Config not found: ${INSTALL_DIR}/${CONFIG_FILE}" ;;
            start_systemd)    echo "Starting via systemd..." ;;
            start_nohup)      echo "Starting via nohup (systemd unavailable)..." ;;
            start_ok)         echo "ProtoCloak started (PID: $1)" ;;
            start_fail)       echo "ProtoCloak failed to start" ;;
            start_check)      echo "Check logs: journalctl -u ${SERVICE_NAME} -n 50" ;;

            stop_begin)       echo "Stopping ProtoCloak..." ;;
            stop_not_running) echo "ProtoCloak is not running" ;;
            stop_pid)         echo "Stopping process (PID: $1)..." ;;
            stop_ok)          echo "ProtoCloak stopped" ;;
            stop_force)       echo "Process not responding, forcing kill..." ;;

            restart_begin)    echo "Restarting ProtoCloak..." ;;

            status_title)     echo "ProtoCloak Status" ;;
            status_running)   echo "Status: ${GREEN}Running${RESET} (PID: $1)" ;;
            status_stopped)   echo "Status: ${RED}Stopped${RESET}" ;;
            status_version)   echo "Version: $1" ;;
            status_uptime)    echo "Uptime: $1" ;;
            status_memory)    echo "Memory: $1" ;;
            status_conns)     echo "Active connections: $1" ;;
            status_fd)        echo "File descriptors: $1" ;;

            logs_title)       echo "ProtoCloak Logs" ;;
            logs_follow)      echo "Press Ctrl+C to exit" ;;
            logs_empty)       echo "No logs available" ;;
            logs_clear)       echo "Logs cleared" ;;

            tune_title)       echo "System Tuning - Optimized for ${EXPECTED_DEVICES} devices" ;;
            tune_step1)       echo "[1/6] Configuring File Descriptors..." ;;
            tune_step2)       echo "[2/6] Configuring Kernel TCP parameters..." ;;
            tune_step3)       echo "[3/6] Configuring PAM module..." ;;
            tune_step4)       echo "[4/6] Configuring NTP time sync..." ;;
            tune_step5)       echo "[5/6] Creating systemd service..." ;;
            tune_step6)       echo "[6/6] Creating environment file..." ;;
            tune_cur_limits)  echo "Current limits:" ;;
            tune_req_fd)      echo "Required for ${EXPECTED_DEVICES} devices: ${REQUIRED_FD} file descriptors" ;;
            tune_tcp_target)  echo "TCP buffers: ~2 GB (Stratum optimized) | Ports: 1024-65535" ;;
            tune_sysctl_ok)   echo "All kernel parameters applied successfully" ;;
            tune_sysctl_err)  echo "Some parameters not applied (missing kernel modules)" ;;
            tune_pam_ok)      echo "PAM pam_limits.so configured" ;;
            tune_pam_skip)    echo "PAM config not applicable (not Debian/Ubuntu)" ;;
            tune_ntp_ok)      echo "NTP time sync is active" ;;
            tune_ntp_enabled) echo "NTP time sync enabled: $1" ;;
            tune_ntp_install) echo "Installing NTP client..." ;;
            tune_ntp_fail)    echo "Cannot auto-configure NTP, please install chrony or ntp manually" ;;
            tune_mem_detect)  echo "System RAM: ${1} GB → GOMEMLIMIT: ${2} GiB (75%)" ;;
            tune_user_new)    echo "Created user: protocloak" ;;
            tune_user_exist)  echo "User protocloak already exists" ;;
            tune_user_fail)   echo "Failed to create user, using root" ;;
            tune_svc_created) echo "Systemd service created: ${SERVICE_FILE}" ;;
            tune_svc_user)    echo "Service user: $1" ;;
            tune_env_created) echo "Environment file created: ${ENV_FILE}" ;;
            tune_done)        echo "System tuning complete" ;;

            fw_title)         echo "Configuring firewall..." ;;
            fw_open)          echo "Opening port: $1" ;;
            fw_ufw)           echo "Detected UFW, configuring..." ;;
            fw_firewalld)     echo "Detected firewalld, configuring..." ;;
            fw_iptables)      echo "Using iptables..." ;;
            fw_none)          echo "No firewall manager detected" ;;
            fw_done)          echo "Firewall configured" ;;

            uninstall_title)  echo "Uninstall ProtoCloak" ;;
            uninstall_confirm) echo "Confirm? All files in ${INSTALL_DIR} will be deleted (y/n)" ;;
            uninstall_cancel) echo "Uninstall cancelled" ;;
            uninstall_done)   echo "Uninstall complete" ;;

            box_conn_addr)    echo "Miner Connection" ;;
            box_next_steps)   echo "Next Steps" ;;
            box_important)    echo "Important" ;;
            box_config)       echo "Configuration" ;;
            box_reboot)       echo "Restart system for FD limits to take effect" ;;
            box_fw_ports)     echo "Open firewall: 3333 (devices), 3334 (internal)" ;;
            box_install_bin)  echo "Install binaries to /opt/protocloak/" ;;
        esac
    fi
}

get_all_ips() {
    local all_ips pub_ips ext_ip
    all_ips=$(ip addr 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | grep -v '^169\.254\.')
    pub_ips=$(echo "$all_ips" | grep -v '^10\.' | grep -v '^172\.1[6-9]\.' | grep -v '^172\.2[0-9]\.' | grep -v '^172\.3[0-2]\.' | grep -v '^192\.168\.' | grep -v '^$')

    if [ -n "$pub_ips" ]; then
        echo "$pub_ips"
        return
    fi

    if command -v curl &>/dev/null; then
        ext_ip=$(curl -s --connect-timeout 3 --max-time 5 ifconfig.me 2>/dev/null)
        [ -z "$ext_ip" ] && ext_ip=$(curl -s --connect-timeout 3 --max-time 5 ipinfo.io/ip 2>/dev/null)
        if [ -n "$ext_ip" ]; then
            echo "$ext_ip"
            return
        fi
    fi

    if [ -n "$all_ips" ]; then
        echo "$all_ips" | head -1
        return
    fi

    echo "<server-ip>"
}

get_public_ip() {
    get_all_ips | head -1
}

get_listen_ports() {
    local cfg="${INSTALL_DIR}/${CONFIG_FILE}"
    if [ -f "$cfg" ]; then
        local ports
        ports=$(grep -E '^\s*listen_addr:\s*' "$cfg" 2>/dev/null | sed 's/#.*//' | grep -oE ':[0-9]+' | tr -d ':' | sort -un)
        if [ -n "$ports" ]; then
            echo "$ports"
            return
        fi
    fi
    [ "$APP_MODE" = "server" ] && echo "3334" || echo "3333"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        warn "$(T need_root)"
        echo ""
        echo "  $(T run_as)"
        echo -e "    ${CYAN}sudo $0${RESET}"
        echo ""
        exit 1
    fi
}

get_pid() {
    local pid=""
    if command -v systemctl &>/dev/null && systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        pid=$(systemctl show -p MainPID --value "$SERVICE_NAME" 2>/dev/null)
        [ "$pid" = "0" ] && pid=""
    fi
    if [ -z "$pid" ] && [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
            pid=""
            rm -f "$PID_FILE"
        fi
    fi
    if [ -z "$pid" ]; then
        pid=$(pgrep -f "${INSTALL_DIR}/${BINARY_NAME}" 2>/dev/null | head -1)
    fi
    echo "$pid"
}

is_running() {
    local pid
    pid=$(get_pid)
    [ -n "$pid" ]
}

do_install() {
    check_root

    echo ""
    info "$(T install_begin)"
    echo ""

    if is_running; then
        warn "$(T install_running)"
        read -p "  $(T install_stop_q) " ans
        if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
            do_stop
        else
            return
        fi
    fi

    info "$(T install_detect)"
    local ARCH
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        *)       ARCH="$ARCH" ;;
    esac
    ok "$(T install_arch "$ARCH")"

    info "$(T install_dir)"
    if ! id -u protocloak &>/dev/null; then
        useradd -r -s /bin/false protocloak 2>/dev/null && {
            SERVICE_USER="protocloak"
            ok "$(T tune_user_new)"
        } || {
            SERVICE_USER="root"
            warn "$(T tune_user_fail)"
        }
    else
        SERVICE_USER="protocloak"
        ok "$(T tune_user_exist)"
    fi

    mkdir -p "${INSTALL_DIR}"
    if [ "$SERVICE_USER" = "protocloak" ]; then
        chown protocloak:protocloak "${INSTALL_DIR}" 2>/dev/null || true
    fi
    ok "$(T install_dir_ok)"

    echo ""
    do_tune_system
    echo ""

    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${RESET}"
    if [ "$UI_LANG" = "zh" ]; then
        echo -e "${GREEN}║${RESET}  ${BOLD}${GREEN}✓ 安装环境准备完成${RESET}                                    ${GREEN}║${RESET}"
    else
        echo -e "${GREEN}║${RESET}  ${BOLD}${GREEN}✓ Installation environment ready${RESET}                       ${GREEN}║${RESET}"
    fi
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${GREEN}║${RESET}                                                               ${GREEN}║${RESET}"
    echo -e "${GREEN}║${RESET}  $(T install_copy)  ${GREEN}║${RESET}"
    echo -e "${GREEN}║${RESET}  $(T install_copy_bin)         ${GREEN}║${RESET}"
    echo -e "${GREEN}║${RESET}  $(T install_copy_cfg)  ${GREEN}║${RESET}"
    echo -e "${GREEN}║${RESET}                                                               ${GREEN}║${RESET}"
    echo -e "${GREEN}║${RESET}  $(T install_manual)  ${GREEN}║${RESET}"
    echo -e "${GREEN}║${RESET}                                                               ${GREEN}║${RESET}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

do_update() {
    check_root

    echo ""
    info "$(T update_begin)"
    echo ""

    if is_running; then
        info "$(T update_stop)"
        do_stop
    fi

    echo ""
    echo -e "  $(T update_copy)"
    echo -e "    ${CYAN}${INSTALL_DIR}/${BINARY_NAME}${RESET}"
    echo ""

    if [ "$UI_LANG" = "zh" ]; then
        read -p "  复制完成后按回车继续... " _
    else
        read -p "  Press Enter after copying... " _
    fi

    if [ -f "${INSTALL_DIR}/${BINARY_NAME}" ]; then
        chmod 750 "${INSTALL_DIR}/${BINARY_NAME}"
        if id -u protocloak &>/dev/null; then
            chown protocloak:protocloak "${INSTALL_DIR}/${BINARY_NAME}" 2>/dev/null || true
        fi
    fi

    info "$(T update_restart)"
    do_start_inner
    echo ""
    ok "$(T update_done)"
    echo ""
}

do_start() {
    check_root

    echo ""
    info "$(T start_begin)"
    echo ""

    local pid
    pid=$(get_pid)
    if [ -n "$pid" ]; then
        warn "$(T start_already "$pid")"
        return
    fi

    do_start_inner
    echo ""
}

do_start_inner() {
    if [ ! -f "${INSTALL_DIR}/${BINARY_NAME}" ]; then
        err "$(T start_no_bin)"
        return 1
    fi

    if [ ! -f "${INSTALL_DIR}/${CONFIG_FILE}" ]; then
        err "$(T start_no_cfg)"
        return 1
    fi

    local ARCH_CURRENT
    ARCH_CURRENT=$(uname -m)
    if command -v file &>/dev/null; then
        local binary_arch
        binary_arch=$(file "${INSTALL_DIR}/${BINARY_NAME}" 2>/dev/null)
        if [[ "$ARCH_CURRENT" == "x86_64" ]] && ! echo "$binary_arch" | grep -q "x86-64"; then
            err "Binary architecture mismatch: expected x86_64"
            return 1
        elif [[ "$ARCH_CURRENT" == "aarch64" ]] && ! echo "$binary_arch" | grep -q "ARM aarch64"; then
            err "Binary architecture mismatch: expected ARM64"
            return 1
        fi
    fi

    chmod 750 "${INSTALL_DIR}/${BINARY_NAME}" 2>/dev/null

    if command -v systemctl &>/dev/null && [ -f "$SERVICE_FILE" ]; then
        info "$(T start_systemd)"
        systemctl daemon-reload 2>/dev/null
        systemctl start "$SERVICE_NAME"
        sleep 2

        if systemctl is-active --quiet "$SERVICE_NAME"; then
            local pid
            pid=$(systemctl show -p MainPID --value "$SERVICE_NAME" 2>/dev/null)
            ok "$(T start_ok "$pid")"
            show_start_banner
        else
            err "$(T start_fail)"
            warn "$(T start_check)"
        fi
    else
        info "$(T start_nohup)"
        cd "${INSTALL_DIR}" || return 1

        local GOMEMLIMIT_VAL TOTAL_MEM_KB TOTAL_MEM_GB
        TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 4194304)
        TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
        GOMEMLIMIT_VAL=$(( (TOTAL_MEM_GB * 75) / 100 ))
        [ "$GOMEMLIMIT_VAL" -lt 1 ] && GOMEMLIMIT_VAL=1

        GOGC=200 GOMEMLIMIT="${GOMEMLIMIT_VAL}GiB" \
            nohup "${INSTALL_DIR}/${BINARY_NAME}" --accept-license -config "${INSTALL_DIR}/${CONFIG_FILE}" \
            >> "${INSTALL_DIR}/stdout.log" 2>&1 &

        local pid=$!
        echo "$pid" > "$PID_FILE"
        sleep 2

        local actual_pid
        actual_pid=$(pgrep -f "${INSTALL_DIR}/${BINARY_NAME}" 2>/dev/null | head -1)
        if [ -n "$actual_pid" ]; then
            echo "$actual_pid" > "$PID_FILE"
            ok "$(T start_ok "$actual_pid")"
            show_start_banner
        elif kill -0 "$pid" 2>/dev/null; then
            ok "$(T start_ok "$pid")"
            show_start_banner
        else
            err "$(T start_fail)"
            rm -f "$PID_FILE"
        fi
    fi
}

show_start_banner() {
    local ips ports
    ips=$(get_all_ips)
    ports=$(get_listen_ports)

    echo ""
    local mode_label
    if [ "$UI_LANG" = "zh" ]; then
        [ "$APP_MODE" = "server" ] && mode_label="服务器" || mode_label="客户端"
    else
        [ "$APP_MODE" = "server" ] && mode_label="Server" || mode_label="Client"
    fi

    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${RESET}"
    if [ "$UI_LANG" = "zh" ]; then
        echo -e "${GREEN}║${RESET}  ${BOLD}${GREEN}✓ ProtoCloak ${mode_label} 启动成功${RESET}                           ${GREEN}║${RESET}"
        echo -e "${GREEN}║${RESET}                                                               ${GREEN}║${RESET}"
        echo -e "${GREEN}║${RESET}  ${BLUE}连接地址:${RESET}                                              ${GREEN}║${RESET}"
    else
        echo -e "${GREEN}║${RESET}  ${BOLD}${GREEN}✓ ProtoCloak ${mode_label} Started${RESET}                           ${GREEN}║${RESET}"
        echo -e "${GREEN}║${RESET}                                                               ${GREEN}║${RESET}"
        echo -e "${GREEN}║${RESET}  ${BLUE}Connection addresses:${RESET}                                   ${GREEN}║${RESET}"
    fi

    while IFS= read -r ip; do
        [ -z "$ip" ] && continue
        while IFS= read -r port; do
            [ -z "$port" ] && continue
            local line="stratum+tcp://${ip}:${port}"
            local padding=$((59 - ${#line}))
            [ $padding -lt 0 ] && padding=0
            printf "${GREEN}║${RESET}    ${BOLD}%s${RESET}%*s${GREEN}║${RESET}\n" "$line" "$padding" ""
        done <<< "$ports"
    done <<< "$ips"

    echo -e "${GREEN}║${RESET}                                                               ${GREEN}║${RESET}"
    if [ "$UI_LANG" = "zh" ]; then
        echo -e "${GREEN}║${RESET}  ${DIM}版本: v${VERSION}${RESET}                                              ${GREEN}║${RESET}"
    else
        echo -e "${GREEN}║${RESET}  ${DIM}Version: v${VERSION}${RESET}                                            ${GREEN}║${RESET}"
    fi
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${RESET}"
}

do_stop() {
    check_root

    echo ""
    info "$(T stop_begin)"

    local pid
    pid=$(get_pid)

    if [ -z "$pid" ]; then
        warn "$(T stop_not_running)"
        echo ""
        return
    fi

    info "$(T stop_pid "$pid")"

    if command -v systemctl &>/dev/null && systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl stop "$SERVICE_NAME" 2>/dev/null
    else
        kill -TERM "$pid" 2>/dev/null
    fi

    local waited=0
    while kill -0 "$pid" 2>/dev/null && [ $waited -lt 10 ]; do
        sleep 1
        waited=$((waited + 1))
    done

    if kill -0 "$pid" 2>/dev/null; then
        warn "$(T stop_force)"
        kill -9 "$pid" 2>/dev/null
        sleep 1
    fi

    rm -f "$PID_FILE"
    ok "$(T stop_ok)"
    echo ""
}

do_restart() {
    check_root

    echo ""
    info "$(T restart_begin)"
    echo ""

    do_stop
    do_start_inner
    echo ""
}

do_status() {
    echo ""
    echo -e "  ${BOLD}$(T status_title)${RESET}"
    echo -e "  ────────────────────────────────────────"

    local pid
    pid=$(get_pid)

    if [ -n "$pid" ]; then
        ok "$(T status_running "$pid")"

        local uptime_str mem_str conn_count fd_count

        if [ -d "/proc/$pid" ]; then
            local start_time
            start_time=$(stat -c %Y "/proc/$pid" 2>/dev/null || echo "")
            if [ -n "$start_time" ]; then
                local now
                now=$(date +%s)
                local diff=$((now - start_time))
                local days=$((diff / 86400))
                local hours=$(( (diff % 86400) / 3600 ))
                local mins=$(( (diff % 3600) / 60 ))
                if [ $days -gt 0 ]; then
                    uptime_str="${days}d ${hours}h ${mins}m"
                elif [ $hours -gt 0 ]; then
                    uptime_str="${hours}h ${mins}m"
                else
                    uptime_str="${mins}m"
                fi
            fi

            mem_str=$(awk '/VmRSS/ {printf "%.1f MB", $2/1024}' "/proc/$pid/status" 2>/dev/null)
            fd_count=$(ls -1 "/proc/$pid/fd" 2>/dev/null | wc -l)
        fi

        local port_pattern
        port_pattern=$(get_listen_ports | sed 's/^/:/' | paste -sd'|' -)
        if [ -n "$port_pattern" ]; then
            conn_count=$(ss -ant 2>/dev/null | grep -cE "${port_pattern}" || echo "0")
        else
            conn_count="0"
        fi

        [ -n "$uptime_str" ] && info "$(T status_uptime "$uptime_str")"
        [ -n "$mem_str" ] && info "$(T status_memory "$mem_str")"
        [ -n "$conn_count" ] && info "$(T status_conns "$conn_count")"
        [ -n "$fd_count" ] && info "$(T status_fd "$fd_count")"
    else
        warn "$(T status_stopped)"
    fi

    info "$(T status_version "$VERSION")"
    echo ""
}

do_logs() {
    echo ""
    echo -e "  ${BOLD}$(T logs_title)${RESET}"
    info "$(T logs_follow)"
    echo ""

    if command -v journalctl &>/dev/null && [ -f "$SERVICE_FILE" ]; then
        journalctl -u "$SERVICE_NAME" -f --no-pager -n 100
    elif [ -f "${INSTALL_DIR}/stdout.log" ]; then
        tail -f "${INSTALL_DIR}/stdout.log"
    elif [ -f "${INSTALL_DIR}/error.log" ]; then
        tail -f "${INSTALL_DIR}/error.log"
    else
        warn "$(T logs_empty)"
    fi
}

do_clear_logs() {
    check_root

    echo ""
    rm -f "${INSTALL_DIR}/stdout.log" 2>/dev/null
    rm -f "${INSTALL_DIR}/error.log" 2>/dev/null
    rm -f "${INSTALL_DIR}/debug.log" 2>/dev/null

    if command -v journalctl &>/dev/null; then
        journalctl --rotate 2>/dev/null
        journalctl --vacuum-time=1s -u "$SERVICE_NAME" 2>/dev/null
    fi

    ok "$(T logs_clear)"
    echo ""
}

do_tune_system() {
    check_root

    echo ""
    echo -e "  ${BOLD}$(T tune_title)${RESET}"
    echo -e "  ════════════════════════════════════════════════════"
    echo ""

    info "$(T tune_step1)"
    echo -e "    $(T tune_cur_limits)"
    echo -e "      Soft: ${CYAN}$(ulimit -Sn)${RESET}  Hard: ${CYAN}$(ulimit -Hn)${RESET}"
    info "$(T tune_req_fd)"
    echo ""

    if [ -f /etc/security/limits.conf ]; then
        if grep -q "^# BEGIN ProtoCloak" /etc/security/limits.conf 2>/dev/null; then
            sed -i.bak '/^# BEGIN ProtoCloak/,/^# END ProtoCloak/d' /etc/security/limits.conf
        elif grep -q "^# ProtoCloak: File descriptors" /etc/security/limits.conf 2>/dev/null; then
            sed -i.bak '/^# ProtoCloak: File descriptors/,/^root.*hard.*nofile/d' /etc/security/limits.conf
        fi
        cat >> /etc/security/limits.conf <<EOF

# BEGIN ProtoCloak
# File descriptors for ${EXPECTED_DEVICES} devices
*               soft    nofile          $REQUIRED_FD
*               hard    nofile          $REQUIRED_FD
root            soft    nofile          $REQUIRED_FD
root            hard    nofile          $REQUIRED_FD
# END ProtoCloak
EOF
        ok "limits.conf"
    fi

    if [ -f /etc/systemd/system.conf ]; then
        grep -q "^DefaultLimitNOFILE=$REQUIRED_FD" /etc/systemd/system.conf 2>/dev/null || {
            sed -i.bak "s/^#\?DefaultLimitNOFILE=.*/DefaultLimitNOFILE=$REQUIRED_FD/" /etc/systemd/system.conf
            grep -q "^DefaultLimitNOFILE=" /etc/systemd/system.conf || \
                echo "DefaultLimitNOFILE=$REQUIRED_FD" >> /etc/systemd/system.conf
            ok "systemd system.conf"
        }
    fi

    ulimit -n $REQUIRED_FD 2>/dev/null || true
    echo ""

    info "$(T tune_step2)"
    info "$(T tune_tcp_target)"
    echo ""

    cat > "$SYSCTL_CONF" <<'SYSCTL_EOF'
# ProtoCloak Network Tuning
# Optimized for Stratum proxy (low bandwidth, high connection count)

fs.file-max = 300000

net.core.rmem_max = 262144
net.core.wmem_max = 262144
net.ipv4.tcp_rmem = 4096 8192 65536
net.ipv4.tcp_wmem = 4096 8192 65536

net.ipv4.tcp_mem = 524288 786432 1048576

net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 8192
net.core.somaxconn = 4096

net.netfilter.nf_conntrack_max = 262144
net.netfilter.nf_conntrack_tcp_timeout_established = 3600

net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_tw_reuse = 1

net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1

net.ipv4.ip_local_port_range = 1024 65535
SYSCTL_EOF

    local tmpfile=$(mktemp /tmp/pc_sysctl.XXXXXX)
    trap "rm -f $tmpfile" EXIT
    
    if sysctl -p "$SYSCTL_CONF" > "$tmpfile" 2>&1; then
        ok "$(T tune_sysctl_ok)"
    else
        warn "$(T tune_sysctl_err)"
        grep -iE "cannot|error|invalid|No such" "$tmpfile" 2>/dev/null || true
    fi
    rm -f "$tmpfile"
    trap - EXIT
    echo ""

    info "$(T tune_step3)"
    if [ -f /etc/pam.d/common-session ]; then
        grep -q '^session.*pam_limits.so' /etc/pam.d/common-session 2>/dev/null || {
            echo 'session required pam_limits.so' >> /etc/pam.d/common-session
        }
        ok "$(T tune_pam_ok)"
    else
        info "$(T tune_pam_skip)"
    fi
    echo ""

    info "$(T tune_step4)"
    local ntp_active=false

    if command -v timedatectl &>/dev/null; then
        local ntp_status
        ntp_status=$(timedatectl show --property=NTPSynchronized --value 2>/dev/null || echo "")
        if [ "$ntp_status" = "yes" ]; then
            ntp_active=true
        fi
    fi

    if [ "$ntp_active" = false ]; then
        if systemctl is-active --quiet chronyd 2>/dev/null || systemctl is-active --quiet chrony 2>/dev/null; then
            ntp_active=true
        elif systemctl is-active --quiet systemd-timesyncd 2>/dev/null; then
            ntp_active=true
        elif systemctl is-active --quiet ntpd 2>/dev/null || systemctl is-active --quiet ntp 2>/dev/null; then
            ntp_active=true
        fi
    fi

    if [ "$ntp_active" = true ]; then
        ok "$(T tune_ntp_ok)"
    else
        if command -v timedatectl &>/dev/null; then
            timedatectl set-ntp true 2>/dev/null && {
                sleep 1
                ok "$(T tune_ntp_enabled "systemd-timesyncd")"
                ntp_active=true
            }
        fi

        if [ "$ntp_active" = false ]; then
            info "$(T tune_ntp_install)"
            if command -v apt-get &>/dev/null; then
                apt-get install -y chrony >/dev/null 2>&1 && {
                    systemctl enable --now chrony 2>/dev/null
                    ok "$(T tune_ntp_enabled "chrony")"
                    ntp_active=true
                }
            elif command -v yum &>/dev/null; then
                yum install -y chrony >/dev/null 2>&1 && {
                    systemctl enable --now chronyd 2>/dev/null
                    ok "$(T tune_ntp_enabled "chrony")"
                    ntp_active=true
                }
            elif command -v dnf &>/dev/null; then
                dnf install -y chrony >/dev/null 2>&1 && {
                    systemctl enable --now chronyd 2>/dev/null
                    ok "$(T tune_ntp_enabled "chrony")"
                    ntp_active=true
                }
            elif command -v apk &>/dev/null; then
                apk add chrony >/dev/null 2>&1 && {
                    rc-update add chronyd default 2>/dev/null
                    service chronyd start 2>/dev/null
                    ok "$(T tune_ntp_enabled "chrony")"
                    ntp_active=true
                }
            fi
        fi

        if [ "$ntp_active" = false ]; then
            warn "$(T tune_ntp_fail)"
        fi
    fi
    echo ""

    info "$(T tune_step5)"

    local TOTAL_MEM_KB TOTAL_MEM_GB GOMEMLIMIT_GB
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 4194304)
    TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
    GOMEMLIMIT_GB=$(( (TOTAL_MEM_GB * 75) / 100 ))
    [ "$GOMEMLIMIT_GB" -lt 1 ] && GOMEMLIMIT_GB=1

    info "$(T tune_mem_detect "$TOTAL_MEM_GB" "$GOMEMLIMIT_GB")"

    local SERVICE_USER
    if id -u protocloak &>/dev/null; then
        SERVICE_USER="protocloak"
    else
        SERVICE_USER="root"
    fi

    mkdir -p "${INSTALL_DIR}"
    if [ "$SERVICE_USER" = "protocloak" ]; then
        chown protocloak:protocloak "${INSTALL_DIR}" 2>/dev/null || true
    fi

    local svc_desc
    [ "$APP_MODE" = "server" ] && svc_desc="ProtoCloak Stratum Proxy Server" || svc_desc="ProtoCloak Stratum Proxy Client"

    cat > "$SERVICE_FILE" <<SVCEOF
[Unit]
Description=${svc_desc}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
WorkingDirectory=${INSTALL_DIR}

LimitNOFILE=${REQUIRED_FD}

Environment="GOGC=200"
Environment="GOMEMLIMIT=${GOMEMLIMIT_GB}GiB"

ExecStart=${INSTALL_DIR}/${BINARY_NAME} --accept-license -config ${INSTALL_DIR}/${CONFIG_FILE}

Restart=always
RestartSec=5
StartLimitBurst=5
StartLimitIntervalSec=60

NoNewPrivileges=true
PrivateTmp=true

StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

[Install]
WantedBy=multi-user.target
SVCEOF

    ok "$(T tune_svc_created)"
    ok "$(T tune_svc_user "$SERVICE_USER")"

    if command -v systemctl &>/dev/null; then
        systemctl daemon-reload 2>/dev/null
        systemctl enable "$SERVICE_NAME" 2>/dev/null
    fi
    echo ""

    info "$(T tune_step6)"

    cat > "$ENV_FILE" <<ENVEOF
#!/bin/bash

TOTAL_MEM_KB=\$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print \$2}' || echo 4194304)
TOTAL_MEM_GB=\$((TOTAL_MEM_KB / 1024 / 1024))
GOMEMLIMIT_GB=\$(( (TOTAL_MEM_GB * 75) / 100 ))
[ "\$GOMEMLIMIT_GB" -lt 1 ] && GOMEMLIMIT_GB=1

export GOGC=200
export GOMEMLIMIT="\${GOMEMLIMIT_GB}GiB"

CURRENT_FD=\$(ulimit -n)
if [ "\$CURRENT_FD" -lt ${REQUIRED_FD} ]; then
    ulimit -n ${REQUIRED_FD} 2>/dev/null || {
        echo -e "${YELLOW}[!]${RESET} Failed to set ulimit. Edit /etc/security/limits.conf and re-login."
        return 1
    }
fi

echo -e "${GREEN}[+]${RESET} ProtoCloak env ready | RAM: \${TOTAL_MEM_GB}G | GOMEMLIMIT: \${GOMEMLIMIT_GB}G | FD: \$(ulimit -n)"
ENVEOF
    chmod 750 "$ENV_FILE"
    ok "$(T tune_env_created)"

    echo ""
    ok "$(T tune_done)"
    echo ""
}

do_firewall() {
    check_root

    echo ""
    info "$(T fw_title)"
    echo ""

    local ports=()
    while IFS= read -r p; do
        [ -n "$p" ] && ports+=("${p}/tcp")
    done < <(get_listen_ports)
    if [ ${#ports[@]} -eq 0 ]; then
        [ "$APP_MODE" = "server" ] && ports=("3334/tcp") || ports=("3333/tcp")
    fi

    if command -v ufw &>/dev/null; then
        info "$(T fw_ufw)"
        for p in "${ports[@]}"; do
            ufw allow "$p" 2>/dev/null
            ok "$(T fw_open "$p")"
        done
        ufw reload 2>/dev/null
    elif command -v firewall-cmd &>/dev/null; then
        info "$(T fw_firewalld)"
        for p in "${ports[@]}"; do
            firewall-cmd --permanent --add-port="$p" 2>/dev/null
            ok "$(T fw_open "$p")"
        done
        firewall-cmd --reload 2>/dev/null
    elif command -v iptables &>/dev/null; then
        info "$(T fw_iptables)"
        for p in "${ports[@]}"; do
            local port_num="${p%/*}"
            iptables -C INPUT -p tcp --dport "$port_num" -j ACCEPT 2>/dev/null || \
                iptables -I INPUT -p tcp --dport "$port_num" -j ACCEPT 2>/dev/null
            ok "$(T fw_open "$p")"
        done
    else
        warn "$(T fw_none)"
    fi

    echo ""
    ok "$(T fw_done)"
    echo ""
}

do_uninstall() {
    check_root

    echo ""
    echo -e "  ${BOLD}${RED}$(T uninstall_title)${RESET}"
    echo ""

    read -p "  $(T uninstall_confirm) " ans
    if [ "$ans" != "y" ] && [ "$ans" != "Y" ]; then
        info "$(T uninstall_cancel)"
        echo ""
        return
    fi

    if is_running; then
        do_stop
    fi

    if command -v systemctl &>/dev/null; then
        systemctl disable "$SERVICE_NAME" 2>/dev/null
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload 2>/dev/null
    fi

    rm -f "$SYSCTL_CONF"
    sysctl --system 2>/dev/null || true

    if [ -f /etc/security/limits.conf ]; then
        if grep -q "^# BEGIN ProtoCloak" /etc/security/limits.conf 2>/dev/null; then
            sed -i.bak '/^# BEGIN ProtoCloak/,/^# END ProtoCloak/d' /etc/security/limits.conf
        fi
    fi

    rm -f "${INSTALL_DIR}/${BINARY_NAME}"
    rm -f "${INSTALL_DIR}/${CONFIG_FILE}"
    rm -f "${ENV_FILE}"
    rm -f "${PID_FILE}"
    rm -f "${INSTALL_DIR}/stdout.log"
    rm -f "${INSTALL_DIR}/error.log"
    rm -f "${INSTALL_DIR}/debug.log"

    local other_mode
    [ "$APP_MODE" = "server" ] && other_mode="client" || other_mode="server"
    local other_bin="protocloak_linux_amd64_${other_mode}"
    if [ ! -f "${INSTALL_DIR}/${other_bin}" ]; then
        rm -rf "${INSTALL_DIR}"
    fi

    ok "$(T uninstall_done)"
    echo ""
}

show_menu() {
    local mode_tag
    if [ "$UI_LANG" = "zh" ]; then
        [ "$APP_MODE" = "server" ] && mode_tag="服务器" || mode_tag="客户端"
    else
        [ "$APP_MODE" = "server" ] && mode_tag="Server" || mode_tag="Client"
    fi

    clear
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${RESET}"
    echo -e "  ${BOLD}ProtoCloak${RESET} Manager ${DIM}v${VERSION}${RESET}  ${YELLOW}[${mode_tag}]${RESET}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${RESET}"
    echo ""
    echo -e "  ${BOLD}$(T menu_title)${RESET}"
    echo ""
    echo -e "   ${GREEN} 1.${RESET} $(T menu_install)"
    echo -e "   ${GREEN} 2.${RESET} $(T menu_update)"
    echo -e "   ${CYAN} 3.${RESET} $(T menu_start)"
    echo -e "   ${CYAN} 4.${RESET} $(T menu_stop)"
    echo -e "   ${CYAN} 5.${RESET} $(T menu_restart)"
    echo -e "   ${BLUE} 6.${RESET} $(T menu_tune)"
    echo -e "   ${BLUE} 7.${RESET} $(T menu_status)"
    echo -e "   ${BLUE} 8.${RESET} $(T menu_logs)"
    echo -e "   ${BLUE} 9.${RESET} $(T menu_clear_logs)"
    echo -e "   ${YELLOW}10.${RESET} $(T menu_firewall)"
    echo -e "   ${RED}11.${RESET} $(T menu_uninstall)"
    echo ""
    if [ "$UI_LANG" = "zh" ]; then
        echo -e "   ${DIM} 0.${RESET} 退出"
    else
        echo -e "   ${DIM} 0.${RESET} Exit"
    fi
    echo ""

    local running_text=""
    if is_running; then
        local pid
        pid=$(get_pid)
        if [ "$UI_LANG" = "zh" ]; then
            running_text="${GREEN}● 运行中${RESET} (PID: ${pid})"
        else
            running_text="${GREEN}● Running${RESET} (PID: ${pid})"
        fi
    else
        if [ "$UI_LANG" = "zh" ]; then
            running_text="${RED}● 已停止${RESET}"
        else
            running_text="${RED}● Stopped${RESET}"
        fi
    fi
    echo -e "  ${DIM}Status:${RESET} ${running_text}"
    echo ""
}

show_menu

read -p "  $(T menu_choose) [0-11]: " choice

case $choice in
    0)  echo "" ; exit 0 ;;
    1)  do_install ;;
    2)  do_update ;;
    3)  do_start ;;
    4)  do_stop ;;
    5)  do_restart ;;
    6)  do_tune_system ;;
    7)  do_status ;;
    8)  do_logs ;;
    9)  do_clear_logs ;;
    10) do_firewall ;;
    11) do_uninstall ;;
    "")  err "$(T menu_invalid)" ; echo "" ;;
    *)  err "$(T menu_invalid)" ; echo "" ;;
esac
