#!/bin/bash
# OpenClaw 一键部署脚本 - macOS 版本
# 支持：macOS 12+ (Intel/Apple Silicon)
# 用法：curl -fsSL https://example.com/install-macos.sh | bash

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 检查是否以 root 运行
check_root() {
    if [ "$EUID" -eq 0 ]; then
        warn "不建议以 root 身份运行，将以普通用户安装"
    fi
}

# 检测 macOS 版本
check_macos_version() {
    if [[ "$(uname)" != "Darwin" ]]; then
        error "此脚本仅支持 macOS 系统"
    fi
    
    local macos_version=$(sw_vers -productVersion)
    local major_version=$(echo $macos_version | cut -d. -f1)
    
    if [ "$major_version" -lt 12 ]; then
        error "需要 macOS 12 或更高版本 (当前：$macos_version)"
    fi
    
    info "检测到 macOS $macos_version"
}

# 检测芯片架构
check_architecture() {
    local arch=$(uname -m)
    if [ "$arch" = "arm64" ]; then
        info "检测到 Apple Silicon (M1/M2/M3)"
        ARCH="arm64"
    elif [ "$arch" = "x86_64" ]; then
        info "检测到 Intel Mac"
        ARCH="x86_64"
    else
        error "不支持的架构：$arch"
    fi
}

# 检查并安装 Homebrew
install_homebrew() {
    if command -v brew &> /dev/null; then
        success "Homebrew 已安装"
        return
    fi
    
    info "正在安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # 添加到 PATH
    if [ "$ARCH" = "arm64" ]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    success "Homebrew 安装完成"
}

# 检查并安装 Node.js
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
    brew install node@$required_version
    brew link --force node@$required_version
    
    # 验证安装
    local installed_version=$(node -v | cut -d. -f1 | tr -d 'v')
    success "Node.js $installed_version 安装完成"
}

# 检查并安装 Git
install_git() {
    if command -v git &> /dev/null; then
        success "Git 已安装"
        return
    fi
    
    info "正在安装 Git..."
    xcode-select --install 2>/dev/null || brew install git
    success "Git 安装完成"
}

# 安装 OpenClaw
install_openclaw() {
    info "正在安装 OpenClaw..."
    
    # 使用 npm 全局安装
    npm install -g openclaw@latest
    
    # 验证安装
    if command -v openclaw &> /dev/null; then
        local version=$(openclaw --version)
        success "OpenClaw $version 安装完成"
    else
        error "OpenClaw 安装失败"
    fi
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
    
    success "配置文件创建完成：$config_dir/openclaw.json"
}

# 设置 API Keys
setup_api_keys() {
    info "配置 API Keys..."
    
    local config_file="$HOME/.openclaw/openclaw.json"
    
    echo ""
    echo "请设置你的 API Keys (可选，稍后也可在 UI 中配置):"
    read -p "Anthropic API Key (回车跳过): " anthropic_key
    read -p "OpenAI API Key (回车跳过): " openai_key
    
    if [ -n "$anthropic_key" ] || [ -n "$openai_key" ]; then
        # 添加到环境变量
        local env_file="$HOME/.openclaw/.env"
        
        echo "# OpenClaw API Keys" > "$env_file"
        [ -n "$anthropic_key" ] && echo "ANTHROPIC_API_KEY=$anthropic_key" >> "$env_file"
        [ -n "$openai_key" ] && echo "OPENAI_API_KEY=$openai_key" >> "$env_file"
        
        # 添加到 shell 配置
        if grep -q "openclaw/.env" ~/.zprofile 2>/dev/null; then
            info "环境变量已配置"
        else
            echo '' >> ~/.zprofile
            echo '# OpenClaw' >> ~/.zprofile
            echo 'if [ -f "$HOME/.openclaw/.env" ]; then' >> ~/.zprofile
            echo '  set -a' >> ~/.zprofile
            echo '  source "$HOME/.openclaw/.env"' >> ~/.zprofile
            echo '  set +a' >> ~/.zprofile
            echo 'fi' >> ~/.zprofile
        fi
        
        success "API Keys 配置完成"
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
    echo "配置目录：$HOME/.openclaw"
    echo "日志目录：$HOME/.openclaw/logs"
    echo ""
    echo "文档：https://github.com/openclaw/openclaw"
    echo "========================================"
}

# 主函数
main() {
    echo "========================================"
    echo "  OpenClaw macOS 一键安装脚本"
    echo "========================================"
    echo ""
    
    check_root
    check_macos_version
    check_architecture
    install_homebrew
    install_git
    install_node
    install_openclaw
    create_config
    setup_api_keys
    run_onboarding
    show_completion
}

# 运行主函数
main "$@"
