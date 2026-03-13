# ============================================================
# Troubleshoot Team — 安装脚本 (Windows PowerShell)
# 将 agents 和 commands symlink 到 ~/.claude/
# 配置和模板复制到 ~/.claude/troubleshooteam/
# ============================================================

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"

function Write-Info  { param($msg) Write-Host "[✓] $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err   { param($msg) Write-Host "[✗] $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "╔══════════════════════════════════════════╗"
Write-Host "║   Troubleshoot Team — Installer          ║"
Write-Host "╚══════════════════════════════════════════╝"
Write-Host ""

# --- 检查管理员权限（创建 symlink 需要） ---
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# 检查是否启用了开发者模式（Windows 10 1703+ 不需要管理员就能创建 symlink）
$DevMode = $false
try {
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    if (Test-Path $regPath) {
        $val = Get-ItemProperty -Path $regPath -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
        if ($val.AllowDevelopmentWithoutDevLicense -eq 1) { $DevMode = $true }
    }
} catch {}

$CanSymlink = $IsAdmin -or $DevMode

if (-not $CanSymlink) {
    Write-Warn "未检测到管理员权限或开发者模式。"
    Write-Warn "Symlink 需要以下任一条件："
    Write-Warn "  1. 以管理员身份运行 PowerShell"
    Write-Warn "  2. 启用 Windows 开发者模式（设置 → 开发者选项）"
    Write-Host ""
    $fallback = Read-Host "是否改用复制模式安装（不使用 symlink）？[Y/n]"
    if ($fallback -match "^[Nn]") {
        Write-Err "安装已取消。请以管理员身份重新运行，或启用开发者模式。"
        exit 1
    }
    $UseSymlink = $false
    Write-Warn "将使用复制模式安装（更新时需重新运行 install.ps1）"
} else {
    $UseSymlink = $true
}

# --- 检查源文件 ---
$AgentsDir = Join-Path $ScriptDir ".claude\agents"
if (-not (Test-Path $AgentsDir)) {
    Write-Err "找不到 .claude\agents 目录，请确认在项目根目录运行"
    exit 1
}

# --- 创建目标目录 ---
$dirs = @(
    (Join-Path $ClaudeDir "agents"),
    (Join-Path $ClaudeDir "commands"),
    (Join-Path $ClaudeDir "troubleshooteam\config"),
    (Join-Path $ClaudeDir "troubleshooteam\templates")
)
foreach ($d in $dirs) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
}

# --- 辅助函数：创建链接或复制 ---
function Install-Link {
    param($Source, $Destination, $Label)

    # 如果目标已存在
    if (Test-Path $Destination) {
        $item = Get-Item $Destination -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            # 已有 symlink，删除
            Remove-Item $Destination -Force
            Write-Warn "已覆盖: $Label"
        } else {
            # 普通文件，备份
            Rename-Item $Destination "${Destination}.bak" -Force
            Write-Warn "已备份原有文件: $Label → ${Label}.bak"
        }
    }

    if ($UseSymlink) {
        New-Item -ItemType SymbolicLink -Path $Destination -Target $Source -Force | Out-Null
        Write-Info "$Label → symlink"
    } else {
        Copy-Item $Source $Destination -Force
        Write-Info "$Label → copied"
    }
}

# --- 安装 Agent 定义 ---
Write-Host ""
Write-Host "📦 安装 Agent 定义..."

$Agents = @(
    "issue-analyst",
    "investigation-planner",
    "kusto-author",
    "kusto-executor",
    "devops-searcher",
    "doc-searcher"
)

foreach ($agent in $Agents) {
    $src = Join-Path $ScriptDir ".claude\agents\${agent}.md"
    $dst = Join-Path $ClaudeDir "agents\${agent}.md"
    Install-Link -Source $src -Destination $dst -Label "agents\${agent}.md"
}

# --- 安装 /investigate 命令 ---
Write-Host ""
Write-Host "📦 安装 /investigate 命令..."

$src = Join-Path $ScriptDir ".claude\commands\investigate.md"
$dst = Join-Path $ClaudeDir "commands\investigate.md"
Install-Link -Source $src -Destination $dst -Label "commands\investigate.md"

# --- 复制配置文件（不覆盖） ---
Write-Host ""
Write-Host "📦 安装配置文件..."

$ConfigFiles = @(
    "adx-clusters.json",
    "devops-projects.json",
    "agent-tools.json"
)

foreach ($cfg in $ConfigFiles) {
    $src = Join-Path $ScriptDir "config\$cfg"
    $dst = Join-Path $ClaudeDir "troubleshooteam\config\$cfg"

    if (Test-Path $dst) {
        Write-Warn "配置已存在，跳过（不覆盖）: config\$cfg"
    } else {
        Copy-Item $src $dst -Force
        Write-Info "config\$cfg"
    }
}

# --- 安装报告模板 ---
Write-Host ""
Write-Host "📦 安装报告模板..."

$src = Join-Path $ScriptDir "templates\report-template.md"
$dst = Join-Path $ClaudeDir "troubleshooteam\templates\report-template.md"
Install-Link -Source $src -Destination $dst -Label "templates\report-template.md"

# --- 记录安装信息 ---
$installInfo = @{
    source   = $ScriptDir
    mode     = if ($UseSymlink) { "symlink" } else { "copy" }
    date     = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
} | ConvertTo-Json

$installInfo | Out-File -FilePath (Join-Path $ClaudeDir "troubleshooteam\.install-info.json") -Encoding utf8
Write-Info "已记录安装信息"

# --- 完成 ---
Write-Host ""
Write-Host "╔══════════════════════════════════════════╗"
Write-Host "║   ✅ 安装完成！                          ║"
Write-Host "╚══════════════════════════════════════════╝"
Write-Host ""
Write-Host "已安装到: $ClaudeDir\"
if ($UseSymlink) {
    Write-Host "安装模式: symlink（git pull 自动生效）"
} else {
    Write-Host "安装模式: copy（更新需重新运行 install.ps1）"
}
Write-Host ""
Write-Host "📌 下一步："
Write-Host "   1. 编辑配置文件（如果是首次安装）："
Write-Host "      $ClaudeDir\troubleshooteam\config\adx-clusters.json"
Write-Host "      $ClaudeDir\troubleshooteam\config\devops-projects.json"
Write-Host ""
Write-Host "   2. 确保 Azure CLI 已登录："
Write-Host "      az login"
Write-Host ""
Write-Host "   3. 在任意目录启动 Claude Code，使用："
Write-Host "      /investigate 工单#12345: 问题描述..."
Write-Host ""
if ($UseSymlink) {
    Write-Host "⚠️  请勿删除此 repo 目录（symlink 指向这里）："
    Write-Host "   $ScriptDir"
    Write-Host ""
    Write-Host "📦 更新: cd $ScriptDir; git pull"
}
Write-Host "🗑  卸载: .\uninstall.ps1"
