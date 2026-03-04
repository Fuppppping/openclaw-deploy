#!/bin/bash
# OpenClaw 一键部署脚本 - Linux 版本
# 支持：Ubuntu 20.04+, Debian 11+, CentOS 8+, Fedora 35+
# 用法：curl -fsSL https://example.com/install-linux.sh | bash

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# 检测 Linux 发行版
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        DISTRO_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        DISTRO="rhel"
    else
        error "无法检测 Linux 发行版"
    fi
    
    info "检测到 Linux 发行版：$DISTRO $DISTRO_VERSION"
}

# 检查包管理器
check_package_manager() {
    if command -v apt &> /dev/null; then
        PM="apt"
        UPDATE_CMD="apt update"
        INSTALL_CMD="apt install -y"
    elif command -v dnf &> /dev/null; then
        PM="dnf"
        UPDATE_CMD="dnf update -y"
        INSTALL_CMD="dnf install -y"
    elif command -v yum &> /dev/null; then
        PM="yum"
        UPDATE_CMD="yum update -y"
        INSTALL_CMD="yum install -y"
    elif command -v pacman &> /dev/null; then
        PM="pacman"
        UPDATE_CMD="pacman -Sy"
        INSTALL_CMD="pacman -S --noconfirm"
    elif command -v zypper &> /dev/null; then
        PM="zypper"
        UPDATE_CMD="zypper refresh"
        INSTALL_CMD="zypper install -y"
    else
        error "不支持的包管理器"
    fi
    
    info "使用包管理器：$PM"
}

# 检查是否以 root 运行
check_root() {
    if [ "$EUID" -eq 0 ]; then
        warn "检测到 root 权限，将继续安装"
        return
    fi
    
    # 检查 sudo
    if ! command -v sudo &> /dev/null; then
        error "需要 root 权限或 sudo，请以 root 运行或使用 sudo"
    fi
    
    SUDO_CMD="sudo"
}

# 安装系统依赖
install_dependencies() {
    info "更新包列表..."
    $SUDO_CMD $UPDATE_CMD
    
    info "安装系统依赖..."
    case $PM in
        apt)
            $SUDO_CMD $INSTALL_CMD curl git ca-certificates gnupg
            ;;
        dnf|yum)
            $SUDO_CMD $INSTALL_CMD curl git ca-certificates
            ;;
        pacman)
            $SUDO_CMD $INSTALL_CMD curl git ca-certificates
            ;;
        zypper)
            $SUDO_CMD $INSTALL_CMD curl git ca-certificates
            ;;
    esac
    
    success "系统依赖安装完成"
}

# 安装 Node.js 22
install_node() {
    local required_version=22
    
    if command -v node &> /dev/null; then
        local current_version=$(node -v | cut -d. -f1 | tr -d 'v')
        if [ "$current_version" -ge "$required_version" ]; then
            success "Node.js $current_version 已安装"
            return
        fi
        warn "Node.js 版本过低 ($current_version)，需要 $required_version+"
    fi
    
    info "正在安装 Node.js $required_version..."
    
    case $DISTRO in
        ubuntu|debian)
            # NodeSource repository
            curl -fsSL https://deb.nodesource.com/setup_22.x | $SUDO_CMD -E bash -
            $SUDO_CMD $INSTALL_CMD nodejs
            ;;
        rhel|centos|fedora|almalinux|rocky)
            # NodeSource repository for RHEL-based
            curl -fsSL https://rpm.nodesource.com/setup_22.x | $SUDO_CMD bash -
            $SUDO_CMD $INSTALL_CMD nodejs
            ;;
        arch|manjaro)
            $SUDO_CMD $INSTALL_CMD nodejs npm
            ;;
        opensuse|suse)
            curl -fsSL https://rpm.nodesource.com/setup_22.x | $SUDO_CMD bash -
            $SUDO_CMD $INSTALL_CMD nodejs
            ;;
        *)
            # 通用方法：使用预编译二进制
            local node_version="22.12.0"
            local arch=$(uname -m)
            local node_arch="x64"
            
            if [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
                node_arch="arm64"
            fi
            
            cd /tmp
            curl -fsSL https://nodejs.org/dist/v${node_version}/node-v${node_version}-linux-${node_arch}.tar.xz -o node.tar.xz
            $SUDO_CMD tar -xf node.tar.xz -C /usr/local --strip-components=1
            rm node.tar.xz
            
            success "Node.js $node_version 安装完成"
            ;;
    esac
    
    # 验证
    local installed_version=$(node -v | cut -d. -f1 | tr -d 'v')
    success "Node.js $installed_version 安装完成"
    
    # 安装 npm 全局包权限修复
    if [ -z "$SUDO_CMD" ]; then
        mkdir -p ~/.npm-global
        npm config set prefix '~/.npm-global'
        if ! grep -q "npm-global" ~/.bashrc 2>/dev/null; then
            echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
            source ~/.bashrc
        fi
    fi
}

# 安装 Git
install_git() {
    if command -v git &> /dev/null; then
        success "Git 已安装"
        return
    fi
    
    info "正在安装 Git..."
    $SUDO_CMD $INSTALL_CMD git
    success "Git 安装完成"
}

# 安装 OpenClaw
install_openclaw() {
    info "正在安装 OpenClaw..."
    
    # 使用 npm 全局安装
    if [ -n "$SUDO_CMD" ]; then
        $SUDO_CMD npm install -g openclaw@latest
    else
        npm install -g openclaw@latest
    fi
    
    # 验证安装
    if command -v openclaw &> /dev/null; then
        local version=$(openclaw --version)
        success "OpenClaw $version 安装完成"
    else
        error "OpenClaw 安装失败"
    fi
}

# 创建系统服务 (systemd)
create_systemd_service() {
    if [ ! -d /etc/systemd/system ]; then
        warn "系统不支持 systemd，跳过服务创建"
        return
    fi
    
    info "创建 systemd 服务..."
    
    cat > /tmp/openclaw.service << 'EOF'
[Unit]
Description=OpenClaw Gateway
After=network.target

[Service]
Type=simple
User=%USER%
WorkingDirectory=%HOME%
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
ExecStart=/usr/local/bin/openclaw gateway --port 18789
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # 替换占位符
    local current_user=$(whoami)
    local current_home=$HOME
    
    sed -i "s/%USER%/$current_user/g" /tmp/openclaw.service
    sed -i "s|%HOME%|$current_home|g" /tmp/openclaw.service
    
    # 安装服务
    $SUDO_CMD mv /tmp/openclaw.service /etc/systemd/system/
    $SUDO_CMD systemctl daemon-reload
    $SUDO_CMD systemctl enable openclaw
    
    success "Systemd 服务创建完成"
    info "启动服务：sudo systemctl start openclaw"
    info "查看状态：sudo systemctl status openclaw"
}

# 创建配置文件
create_config() {
    local config_dir="$HOME/.openclaw"
    
    if [ -f "$config_dir/openclaw.json" ]; then
        warn "配置文件已存在，跳过创建"
        return
    fi
    
    info "创建配置文件..."
    mkdir -p "$config_dir"
    
    cat > "$config_dir/openclaw.json" << 'EOF'
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-opus-4-6",
        "fallbacks": ["anthropic/claude-sonnet-4-5"]
      },
      "maxConcurrent": 2
    },
    "list": [
      { "id": "main", "default": true }
    ]
  },
  "gateway": {
    "mode": "local",
    "bind": "loopback"
  },
  "meta": {
    "lastTouchedVersion": "2026.3.4"
  }
}
EOF
    
    success "配置文件创建完成"
}

# 配置防火墙
configure_firewall() {
    info "配置防火墙..."
    
    if command -v ufw &> /dev/null && sudo ufw status | grep -q "Status: active"; then
        info "检测到 UFW，添加规则..."
        $SUDO_CMD ufw allow 18789/tcp comment "OpenClaw Gateway"
        success "UFW 规则添加完成"
    elif command -v firewall-cmd &> /dev/null; then
        info "检测到 firewalld，添加规则..."
        $SUDO_CMD firewall-cmd --permanent --add-port=18789/tcp
        $SUDO_CMD firewall-cmd --reload
        success "Firewalld 规则添加完成"
    else
        warn "未检测到活动的防火墙，请手动配置"
    fi
}

# 运行 Onboarding
run_onboarding() {
    echo ""
    info "是否现在运行 onboarding 向导？"
    read -p "运行 onboarding? (y/n): " run_onboard
    
    if [ "$run_onboard" = "y" ]; then
        info "启动 onboarding..."
        openclaw onboard --install-daemon
    else
        info "你可以稍后运行：openclaw onboard"
    fi
}

# 显示完成信息
show_completion() {
    echo ""
    echo "========================================"
    success "🎉 OpenClaw 安装完成！"
    echo "========================================"
    echo ""
    echo "常用命令:"
    echo "  openclaw --version    # 查看版本"
    echo "  openclaw doctor       # 检查配置"
    echo "  openclaw status       # 查看状态"
    echo "  openclaw dashboard    # 打开 Web UI"
    echo "  openclaw onboard      # 运行配置向导"
    echo ""
    if [ -d /etc/systemd/system ]; then
        echo "系统服务:"
        echo "  sudo systemctl start openclaw    # 启动服务"
        echo "  sudo systemctl stop openclaw     # 停止服务"
        echo "  sudo systemctl status openclaw   # 查看状态"
        echo ""
    fi
    echo "配置目录：$HOME/.openclaw"
    echo "日志目录：$HOME/.openclaw/logs"
    echo ""
    echo "访问地址：http://localhost:18789"
    echo "文档：https://github.com/openclaw/openclaw"
    echo "========================================"
}

# 主函数
main() {
    echo "========================================"
    echo "  OpenClaw Linux 一键安装脚本"
    echo "========================================"
    echo ""
    
    check_root
    detect_distro
    check_package_manager
    install_dependencies
    install_git
    install_node
    install_openclaw
    create_config
    configure_firewall
    
    # 仅非 root 用户创建 systemd 服务
    if [ "$EUID" -ne 0 ]; then
        create_systemd_service
    fi
    
    run_onboarding
    show_completion
}

# 运行主函数
main "$@"
