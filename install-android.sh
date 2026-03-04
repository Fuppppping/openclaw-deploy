#!/data/data/com.termux/files/usr/bin/bash
# OpenClaw 一键部署脚本 - Android (Termux) 版本
# 支持：Android 10+ with Termux
# 用法：curl -fsSL https://example.com/install-android.sh | bash

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

# 检查 Termux 环境
check_termux() {
    if [ ! -d "/data/data/com.termux" ]; then
        error "此脚本仅支持 Android Termux 环境"
    fi
    
    if [ ! -command -v pkg &> /dev/null ] && [ ! -command -v apt &> /dev/null ]; then
        error "未检测到 Termux 包管理器"
    fi
    
    info "检测到 Termux 环境"
}

# 检查 Android 版本
check_android_version() {
    # 尝试获取 Android 版本
    if command -v getprop &> /dev/null; then
        local android_version=$(getprop ro.build.version.release)
        local sdk_version=$(getprop ro.build.version.sdk)
        
        if [ "$sdk_version" -lt 29 ]; then
            warn "Android 版本较旧 ($android_version)，可能遇到兼容性问题"
        else
            info "Android $android_version (SDK $sdk_version)"
        fi
    fi
}

# 更新包列表
update_packages() {
    info "更新包列表..."
    
    # Termux 使用 pkg 或 apt
    if command -v pkg &> /dev/null; then
        pkg update -y
    else
        apt update -y
    fi
    
    success "包列表更新完成"
}

# 安装系统依赖
install_dependencies() {
    info "安装系统依赖..."
    
    local packages="python nodejs git curl wget clang cmake libcryptopenssl libjpeg-turbo libwebp libxml2 libxslt"
    
    if command -v pkg &> /dev/null; then
        pkg install -y $packages
    else
        apt install -y $packages
    fi
    
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
        warn "Node.js 版本过低 ($current_version)"
    fi
    
    info "正在安装 Node.js..."
    
    # Termux 默认可能不是最新 Node.js，尝试使用 nvm
    if command -v pkg &> /dev/null; then
        pkg install -y nodejs
    fi
    
    # 检查版本
    local installed_version=$(node -v | cut -d. -f1 | tr -d 'v')
    
    if [ "$installed_version" -lt "$required_version" ]; then
        info "使用 nvm 安装 Node.js $required_version..."
        
        # 安装 nvm
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        
        # 加载 nvm
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        
        # 安装 Node.js 22
        nvm install 22
        nvm use 22
        nvm alias default 22
        
        # 添加到启动脚本
        if ! grep -q "NVM_DIR" ~/.bashrc 2>/dev/null; then
            cat >> ~/.bashrc << 'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
        fi
        
        success "Node.js $(node -v) 通过 nvm 安装完成"
    else
        success "Node.js $installed_version 安装完成"
    fi
}

# 安装 Git
install_git() {
    if command -v git &> /dev/null; then
        success "Git 已安装"
        return
    fi
    
    info "正在安装 Git..."
    
    if command -v pkg &> /dev/null; then
        pkg install -y git
    else
        apt install -y git
    fi
    
    success "Git 安装完成"
}

# 配置 npm 全局目录
setup_npm_global() {
    info "配置 npm 全局目录..."
    
    # 设置全局安装目录到用户目录
    npm config set prefix "$HOME/.npm-global"
    
    # 添加到 PATH
    if ! grep -q "npm-global" ~/.bashrc 2>/dev/null; then
        echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/.npm-global/bin:$PATH"
    fi
    
    success "npm 全局目录配置完成"
}

# 安装 OpenClaw
install_openclaw() {
    info "正在安装 OpenClaw..."
    
    # 设置环境变量
    export npm_config_build_from_source=true
    
    # 安装
    npm install -g openclaw@latest
    
    # 验证
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
      "maxConcurrent": 1
    },
    "list": [
      { "id": "main", "default": true }
    ]
  },
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789
  },
  "meta": {
    "lastTouchedVersion": "2026.3.4"
  }
}
EOF
    
    success "配置文件创建完成"
}

# 配置 API Keys
setup_api_keys() {
    info "配置 API Keys..."
    
    local config_file="$HOME/.openclaw/openclaw.json"
    local env_file="$HOME/.openclaw/.env"
    
    echo ""
    echo "请设置你的 API Keys (可选，稍后也可在 UI 中配置):"
    read -p "Anthropic API Key (回车跳过): " anthropic_key
    read -p "OpenAI API Key (回车跳过): " openai_key
    
    if [ -n "$anthropic_key" ] || [ -n "$openai_key" ]; then
        echo "# OpenClaw API Keys" > "$env_file"
        [ -n "$anthropic_key" ] && echo "ANTHROPIC_API_KEY=$anthropic_key" >> "$env_file"
        [ -n "$openai_key" ] && echo "OPENAI_API_KEY=$openai_key" >> "$env_file"
        
        # 添加到 shell 配置
        if ! grep -q "openclaw/.env" ~/.bashrc 2>/dev/null; then
            echo '' >> ~/.bashrc
            echo '# OpenClaw' >> ~/.bashrc
            echo 'if [ -f "$HOME/.openclaw/.env" ]; then' >> ~/.bashrc
            echo '  set -a' >> ~/.bashrc
            echo '  source "$HOME/.openclaw/.env"' >> ~/.bashrc
            echo '  set +a' >> ~/.bashrc
            echo 'fi' >> ~/.bashrc
        fi
        
        success "API Keys 配置完成"
    fi
}

# 创建 Termux 启动脚本
create_startup_script() {
    info "创建启动脚本..."
    
    local startup_script="$HOME/.openclaw/start.sh"
    
    cat > "$startup_script" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# OpenClaw 启动脚本 (Termux)

cd $HOME/.openclaw

# 加载环境变量
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# 启动网关
echo "启动 OpenClaw Gateway..."
openclaw gateway --port 18789
EOF
    
    chmod +x "$startup_script"
    success "启动脚本创建完成：$startup_script"
    
    # 创建 Termux 快捷方式
    local termux_shortcut="$HOME/termux.properties"
    if ! grep -q "shortcut" "$termux_shortcut" 2>/dev/null; then
        cat >> "$termux_shortcut" << EOF

# OpenClaw 快捷方式
shortcut.create-openclaw=am start -n com.termux/.app.RunScript --es script "$startup_script"
EOF
        success "Termux 快捷方式已配置"
    fi
}

# 配置 Termux:Boot (开机自启)
setup_termux_boot() {
    info "配置开机自启 (可选)..."
    
    local boot_dir="$HOME/.termux/boot"
    
    if [ ! -d "$boot_dir" ]; then
        echo ""
        echo "是否配置开机自启？"
        echo "需要先安装 Termux:Boot 应用 (从 F-Droid)"
        read -p "配置开机自启？(y/n): " setup_boot
        
        if [ "$setup_boot" = "y" ]; then
            mkdir -p "$boot_dir"
            
            cat > "$boot_dir/start-openclaw.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
sleep 10  # 等待网络就绪
cd $HOME/.openclaw
openclaw gateway --port 18789 &
EOF
            
            chmod +x "$boot_dir/start-openclaw.sh"
            success "开机自启配置完成"
            info "请安装 Termux:Boot 应用以启用自启"
        fi
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
    echo "启动脚本：$HOME/.openclaw/start.sh"
    echo "配置目录：$HOME/.openclaw"
    echo "日志目录：$HOME/.openclaw/logs"
    echo ""
    echo "访问地址：http://localhost:18789"
    echo ""
    echo "⚠️  Android 注意事项:"
    echo "  - 保持 Termux 后台运行"
    echo "  - 关闭电池优化"
    echo "  - 使用 Termux:Boot 实现开机自启"
    echo ""
    echo "文档：https://github.com/openclaw/openclaw"
    echo "========================================"
}

# 主函数
main() {
    echo "========================================"
    echo "  OpenClaw Android (Termux) 安装脚本"
    echo "========================================"
    echo ""
    
    check_termux
    check_android_version
    update_packages
    install_dependencies
    install_git
    install_node
    setup_npm_global
    install_openclaw
    create_config
    setup_api_keys
    create_startup_script
    setup_termux_boot
    run_onboarding
    show_completion
}

# 运行主函数
main "$@"
