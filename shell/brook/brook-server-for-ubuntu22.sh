#!/bin/bash

# Brook 代理安装脚本
# 功能：下载、安装 Brook 代理并配置自动启动

set -euo pipefail

# ============================================================
# 常量
# ============================================================

BROOK_BIN="/usr/local/bin/brook"
BROOK_CONF="/etc/brook.conf"
BROOK_SERVICE="/etc/systemd/system/brook.service"
BROOK_PORT="9999"

# ============================================================
# 工具函数
# ============================================================

info()  { echo ">>> $*"; }
error() { echo "错误：$*" >&2; exit 1; }

# ============================================================
# 各阶段函数
# ============================================================

detect_arch() {
	local arch
	arch=$(uname -m)
	case "$arch" in
		x86_64)  BROOK_ARCH="amd64" ;;
		aarch64) BROOK_ARCH="arm64" ;;
		armv7l)  BROOK_ARCH="arm"   ;;
		*)       error "不支持的系统架构: $arch" ;;
	esac
	info "系统架构: $arch -> $BROOK_ARCH"
}

install_brook() {
	local url="https://github.com/txthinking/brook/releases/latest/download/brook_linux_${BROOK_ARCH}"
	info "下载 Brook: $url"
	wget -q -O /tmp/brook "$url"
	chmod +x /tmp/brook
	sudo mv /tmp/brook "$BROOK_BIN"
	info "Brook 安装完成，版本: $("$BROOK_BIN" --version)"
}

generate_password() {
	PASSWORD=$(tr -dc 'a-z0-9' </dev/urandom | head -c 10)
}

write_config() {
	sudo tee "$BROOK_CONF" >/dev/null <<EOF
# Brook 配置文件
LISTEN=0.0.0.0:${BROOK_PORT}
PASSWORD=${PASSWORD}
PROTOCOL=server
EOF
	sudo chmod 600 "$BROOK_CONF"
	info "配置文件已创建: $BROOK_CONF"
}

setup_systemd() {
	sudo tee "$BROOK_SERVICE" >/dev/null <<'EOF'
[Unit]
Description=Brook Proxy Service
After=network.target

[Service]
Type=simple
EnvironmentFile=/etc/brook.conf
ExecStart=/usr/local/bin/brook $PROTOCOL -l $LISTEN -p $PASSWORD
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
	sudo systemctl daemon-reload
	sudo systemctl enable brook
	info "systemd 服务已配置: $BROOK_SERVICE"
}

setup_firewall() {
	info "配置防火墙，开放 ${BROOK_PORT} 端口 (TCP/UDP)"
	if command -v ufw &>/dev/null; then
		sudo ufw allow "${BROOK_PORT}/tcp"
		sudo ufw allow "${BROOK_PORT}/udp"
	elif command -v firewall-cmd &>/dev/null; then
		sudo firewall-cmd --permanent --add-port="${BROOK_PORT}/tcp"
		sudo firewall-cmd --permanent --add-port="${BROOK_PORT}/udp"
		sudo firewall-cmd --reload
	elif command -v iptables &>/dev/null; then
		sudo iptables -A INPUT -p tcp --dport "$BROOK_PORT" -j ACCEPT
		sudo iptables -A INPUT -p udp --dport "$BROOK_PORT" -j ACCEPT
		sudo iptables-save >/etc/iptables/rules.v4 2>/dev/null || true
	else
		info "未检测到防火墙工具，跳过"
	fi
}

start_service() {
	sudo systemctl start brook
	sudo systemctl status brook --no-pager
	info "Brook 服务已启动"
}

print_summary() {
	echo ""
	echo "=== 安装完成 ==="
	echo "  密码:     $PASSWORD"
	echo "  端口:     $BROOK_PORT"
	echo "  配置文件: $BROOK_CONF"
	echo "  服务管理: sudo systemctl [start|stop|restart|status] brook"
	echo ""
	echo "请妥善保存密码，配置文件仅 root 可读。"
}

# ============================================================
# 入口
# ============================================================

main() {
	echo "=== Brook 代理安装脚本 ==="
	detect_arch
	install_brook
	generate_password
	write_config
	setup_systemd
	setup_firewall
	start_service
	print_summary
}

main
