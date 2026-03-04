# OpenClaw 一键部署脚本

> 🚀 快速部署 OpenClaw 到 macOS、Linux、Windows 和 Android 平台

## 📦 快速开始

选择你的操作系统，复制对应命令，在终端中运行即可。

### 🍎 macOS

```bash
curl -fsSL https://raw.githubusercontent.com/Fuppppping/openclaw-deploy/main/install-macos.sh | bash
```

### 🐧 Linux

```bash
curl -fsSL https://raw.githubusercontent.com/Fuppppping/openclaw-deploy/main/install-linux.sh | bash
```

### 🪟 Windows

以**管理员身份**打开 PowerShell，运行：

```powershell
iwr -useb https://raw.githubusercontent.com/Fuppppping/openclaw-deploy/main/install-windows.ps1 | iex
```

### 🤖 Android (Termux)

在 Termux 中运行：

```bash
curl -fsSL https://raw.githubusercontent.com/Fuppppping/openclaw-deploy/main/install-android.sh | bash
```

---

## 📋 详细说明

### 部署前准备

| 平台 | 要求 |
|------|------|
| macOS | macOS 10.15+，需要 Xcode Command Line Tools |
| Linux | Ubuntu 18.04+ / Debian 10+ / CentOS 7+，需要 sudo 权限 |
| Windows | Windows 10+，需要管理员权限，PowerShell 5.1+ |
| Android | Termux App，需要存储权限 |

### 部署后

脚本运行完成后：

1. **验证安装**：在终端运行 `openclaw --version`
2. **启动服务**：运行 `openclaw start`
3. **访问界面**：打开浏览器访问 `http://localhost:8080`

---

## 🔧 高级选项

### 自定义安装路径

```bash
# macOS/Linux
export OPENCLAW_INSTALL_DIR=/opt/openclaw
curl -fsSL https://raw.githubusercontent.com/Fuppppping/openclaw-deploy/main/install-macos.sh | bash

# Windows
$env:OPENCLAW_INSTALL_DIR="C:\openclaw"
iwr -useb https://raw.githubusercontent.com/Fuppppping/openclaw-deploy/main/install-windows.ps1 | iex
```

### 静默安装（无交互）

```bash
# macOS/Linux
curl -fsSL https://raw.githubusercontent.com/Fuppppping/openclaw-deploy/main/install-macos.sh | bash -s -- --silent

# Windows
iwr -useb https://raw.githubusercontent.com/Fuppppping/openclaw-deploy/main/install-windows.ps1 | iex -ArgumentList "-silent"
```

### 指定版本安装

```bash
# 安装特定版本
curl -fsSL https://raw.githubusercontent.com/Fuppppping/openclaw-deploy/main/install-macos.sh | bash -s -- --version 2.1.0
```

---

## 🛠️ 手动安装

如果自动脚本无法运行，可以手动下载：

### 1. 下载脚本

```bash
# macOS
curl -O https://raw.githubusercontent.com/Fuppppping/openclaw-deploy/main/install-macos.sh
chmod +x install-macos.sh
./install-macos.sh

# Linux
curl -O https://raw.githubusercontent.com/Fuppppping/openclaw-deploy/main/install-linux.sh
chmod +x install-linux.sh
./install-linux.sh

# Windows
# 右键保存：https://raw.githubusercontent.com/Fuppppping/openclaw-deploy/main/install-windows.ps1
# 然后以管理员身份运行 PowerShell
.\install-windows.ps1

# Android
curl -O https://raw.githubusercontent.com/Fuppppping/openclaw-deploy/main/install-android.sh
chmod +x install-android.sh
./install-android.sh
```

---

## ❓ 常见问题

### 1. 脚本运行失败怎么办？

**检查网络连接**：
```bash
# 测试是否能访问 GitHub
curl -I https://raw.githubusercontent.com
```

**检查权限**：
- macOS/Linux: 确保有 sudo 权限
- Windows: 以管理员身份运行 PowerShell

### 2. 如何卸载？

```bash
# macOS/Linux
openclaw uninstall

# Windows
& "C:\Program Files\OpenClaw\uninstall.exe"

# Android (Termux)
rm -rf $PREFIX/openclaw
```

### 3. 安装位置在哪里？

| 平台 | 默认路径 |
|------|----------|
| macOS | `/Applications/OpenClaw` |
| Linux | `/opt/openclaw` |
| Windows | `C:\Program Files\OpenClaw` |
| Android | `$PREFIX/openclaw` |

### 4. 如何更新？

```bash
# 重新运行安装脚本即可
curl -fsSL https://raw.githubusercontent.com/Fuppppping/openclaw-deploy/main/install-macos.sh | bash
```

---

## 📞 获取帮助

- 📖 **官方文档**: https://github.com/openclaw/openclaw
- 🐛 **问题反馈**: https://github.com/openclaw/openclaw/issues
- 💬 **社区讨论**: https://github.com/openclaw/openclaw/discussions

---

## 📄 许可证

本部署脚本采用 MIT 许可证。

OpenClaw 主程序请查看其官方仓库的许可证。

---

## 🙏 致谢

感谢 [OpenClaw](https://github.com/openclaw/openclaw) 团队提供的优秀工具！

此部署脚本由社区维护，旨在简化 OpenClaw 的安装流程。
