# OpenClaw Windows 一键安装脚本
# 支持：Windows 10/11 (PowerShell 5.1+)
# 用法：iwr -useb https://example.com/install-windows.ps1 | iex

param(
    [switch]$NoOnboard,
    [switch]$Verbose,
    [string]$InstallPath = "$env:USERPROFILE\openclaw"
)

# 颜色定义
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Blue }
function Write-Success { Write-Host "[SUCCESS] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Error-Custom { Write-Host "[ERROR] $args" -ForegroundColor Red; exit 1 }

# 检查 PowerShell 版本
function Check-PowerShell-Version {
    Write-Info "检查 PowerShell 版本..."
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Error-Custom "需要 PowerShell 5.1 或更高版本"
    }
    Write-Success "PowerShell $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) 版本符合要求"
}

# 检查管理员权限
function Check-Admin-Rights {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Warn "未以管理员身份运行，某些功能可能受限"
        Write-Info "建议：右键 PowerShell -> 以管理员身份运行"
    } else {
        Write-Success "以管理员权限运行"
    }
}

# 检测系统架构
function Check-Architecture {
    $arch = (Get-CimInstance Win32_Processor).AddressWidth
    if ($arch -eq 64) {
        Write-Info "检测到 64 位系统"
        $script:ARCH = "x64"
    } else {
        Write-Error-Custom "仅支持 64 位 Windows 系统"
    }
}

# 检查并安装 Git
function Install-Git {
    Write-Info "检查 Git..."
    
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitVersion = git --version
        Write-Success "Git 已安装：$gitVersion"
        return
    }
    
    Write-Info "正在安装 Git..."
    
    # 尝试使用 winget
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Git.Git -e --source winget
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Git 通过 winget 安装完成"
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            return
        }
    }
    
    # 尝试使用 Chocolatey
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install git -y
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Git 通过 Chocolatey 安装完成"
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            return
        }
    }
    
    # 尝试使用 Scoop
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install git
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Git 通过 Scoop 安装完成"
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            return
        }
    }
    
    # 手动下载安装
    Write-Info "请手动安装 Git: https://git-scm.com/download/win"
    Write-Warn "安装 Git 后重新运行此脚本"
    pause
    exit
}

# 检查并安装 Node.js 22
function Install-NodeJS {
    Write-Info "检查 Node.js..."
    
    $requiredVersion = 22
    
    if (Get-Command node -ErrorAction SilentlyContinue) {
        $nodeVersion = node --version
        $majorVersion = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
        
        if ($majorVersion -ge $requiredVersion) {
            Write-Success "Node.js $nodeVersion 已安装"
            return
        }
        
        Write-Warn "Node.js 版本过低 ($nodeVersion)，需要 22+"
    }
    
    Write-Info "正在安装 Node.js 22..."
    
    # 使用 winget (推荐)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info "使用 winget 安装 Node.js..."
        winget install --id OpenJS.NodeJS.LTS -e --source winget
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Node.js 安装完成"
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            return
        }
    }
    
    # 使用 Chocolatey
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Info "使用 Chocolatey 安装 Node.js..."
        choco install nodejs-lts -y
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Node.js 安装完成"
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            return
        }
    }
    
    # 手动下载 MSI 安装
    Write-Info "请手动安装 Node.js 22: https://nodejs.org/"
    Write-Warn "安装后重新运行此脚本"
    pause
    exit
}

# 安装 OpenClaw
function Install-OpenClaw {
    Write-Info "正在安装 OpenClaw..."
    
    # 设置 npm 全局安装目录到用户目录
    $npmGlobalPath = "$env:USERPROFILE\AppData\Roaming\npm"
    npm config set prefix $npmGlobalPath
    
    # 添加到 PATH
    if ($env:Path -notlike "*$npmGlobalPath*") {
        [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$npmGlobalPath", "User")
        $env:Path = $env:Path + ";$npmGlobalPath"
    }
    
    # 安装
    npm install -g openclaw@latest --force
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "OpenClaw 安装失败"
    }
    
    # 验证
    if (Get-Command openclaw -ErrorAction SilentlyContinue) {
        $version = openclaw --version
        Write-Success "OpenClaw $version 安装完成"
    } else {
        Write-Error-Custom "OpenClaw 命令未找到，请检查 PATH"
    }
}

# 创建配置文件
function Create-Config {
    $configDir = "$env:USERPROFILE\.openclaw"
    
    if (Test-Path "$configDir\openclaw.json") {
        Write-Warn "配置文件已存在，跳过创建"
        return
    }
    
    Write-Info "创建配置文件..."
    
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    
    $config = @{
        agents = @{
            defaults = @{
                model = @{
                    primary = "anthropic/claude-opus-4-6"
                    fallbacks = @("anthropic/claude-sonnet-4-5")
                }
                maxConcurrent = 2
            }
            list = @(
                @{ id = "main"; default = $true }
            )
        }
        gateway = @{
            mode = "local"
            bind = "loopback"
        }
        meta = @{
            lastTouchedVersion = "2026.3.4"
        }
    }
    
    $config | ConvertTo-Json -Depth 10 | Out-File -FilePath "$configDir\openclaw.json" -Encoding utf8
    
    Write-Success "配置文件创建完成：$configDir\openclaw.json"
}

# 配置环境变量
function Setup-Environment {
    Write-Info "配置环境变量..."
    
    $envFile = "$env:USERPROFILE\.openclaw\.env"
    
    Write-Host "`n请设置 API Keys (可选，稍后也可在 UI 中配置):"
    $anthropicKey = Read-Host "Anthropic API Key (回车跳过)"
    $openaiKey = Read-Host "OpenAI API Key (回车跳过)"
    
    $envContent = "# OpenClaw API Keys`n"
    
    if ($anthropicKey) {
        [Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", $anthropicKey, "User")
        $envContent += "ANTHROPIC_API_KEY=$anthropicKey`n"
    }
    
    if ($openaiKey) {
        [Environment]::SetEnvironmentVariable("OPENAI_API_KEY", $openaiKey, "User")
        $envContent += "OPENAI_API_KEY=$openaiKey`n"
    }
    
    if ($anthropicKey -or $openaiKey) {
        $envContent | Out-File -FilePath $envFile -Encoding utf8
        Write-Success "API Keys 配置完成"
    }
}

# 创建 Windows 服务 (使用 NSSM 或任务计划)
function Create-Windows-Service {
    Write-Info "创建 Windows 服务..."
    
    # 检查 NSSM
    $nssmPath = "C:\Program Files\nssm\nssm.exe"
    
    if (-not (Test-Path $nssmPath)) {
        Write-Warn "NSSM 未安装，跳过服务创建"
        Write-Info "可使用任务计划程序或手动运行 openclaw gateway"
        return
    }
    
    & $nssmPath install OpenClawGateway "C:\Program Files\nodejs\node.exe" "C:\Program Files\nodejs\node_modules\openclaw\dist\index.js" "gateway" "--port" "18789"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Windows 服务创建完成"
        Write-Info "服务名称：OpenClawGateway"
        Write-Info "启动服务：Start-Service OpenClawGateway"
        Write-Info "停止服务：Stop-Service OpenClawGateway"
    }
}

# 创建启动脚本
function Create-Startup-Script {
    $startupDir = "$env:USERPROFILE\.openclaw"
    $scriptPath = "$startupDir\start-openclaw.ps1"
    
    $scriptContent = @"
# OpenClaw 启动脚本
Start-Process node -ArgumentList "C:\Program Files\nodejs\node_modules\openclaw\dist\index.js", "gateway", "--port", "18789"
"@
    
    $scriptContent | Out-File -FilePath $scriptPath -Encoding utf8
    Write-Success "启动脚本创建完成：$scriptPath"
}

# 运行 Onboarding
function Run-Onboarding {
    if ($NoOnboard) {
        Write-Info "跳过 onboarding (使用 -NoOnboard 参数)"
        return
    }
    
    Write-Host "`n是否现在运行 onboarding 向导？"
    $response = Read-Host "运行 onboarding? (y/n)"
    
    if ($response -eq 'y') {
        Write-Info "启动 onboarding..."
        openclaw onboard --install-daemon
    } else {
        Write-Info "你可以稍后运行：openclaw onboard"
    }
}

# 显示完成信息
function Show-Completion {
    Write-Host "`n========================================"
    Write-Success "🎉 OpenClaw 安装完成！"
    Write-Host "========================================"
    Write-Host "`n常用命令:"
    Write-Host "  openclaw --version    # 查看版本"
    Write-Host "  openclaw doctor       # 检查配置"
    Write-Host "  openclaw status       # 查看状态"
    Write-Host "  openclaw dashboard    # 打开 Web UI"
    Write-Host "  openclaw onboard      # 运行配置向导"
    Write-Host "`n配置目录：$env:USERPROFILE\.openclaw"
    Write-Host "日志目录：$env:USERPROFILE\.openclaw\logs"
    Write-Host "`n访问地址：http://localhost:18789"
    Write-Host "文档：https://github.com/openclaw/openclaw"
    Write-Host "========================================"
}

# 主函数
function Main {
    Write-Host "========================================"
    Write-Host "  OpenClaw Windows 一键安装脚本"
    Write-Host "========================================"
    Write-Host ""
    
    Check-PowerShell-Version
    Check-Admin-Rights
    Check-Architecture
    Install-Git
    Install-NodeJS
    Install-OpenClaw
    Create-Config
    Setup-Environment
    Create-Windows-Service
    Create-Startup-Script
    Run-Onboarding
    Show-Completion
    
    Write-Host "`n按任意键退出..."
    pause
}

# 运行主函数
Main
