# ============================================================
# Troubleshoot Team — 卸载脚本 (Windows PowerShell)
# 移除 symlink/复制的文件，保留用户修改过的配置
# ============================================================

$ErrorActionPreference = "Stop"

$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$TroubleshootDir = Join-Path $ClaudeDir "troubleshooteam"

function Write-Info  { param($msg) Write-Host "[✓] $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err   { param($msg) Write-Host "[✗] $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "╔══════════════════════════════════════════╗"
Write-Host "║   Troubleshoot Team — Uninstaller        ║"
Write-Host "╚══════════════════════════════════════════╝"
Write-Host ""

# --- 移除 Agent 文件 ---
Write-Host "🗑  移除 Agent 定义..."

$Agents = @(
    "issue-analyst",
    "investigation-planner",
    "kusto-author",
    "kusto-executor",
    "devops-searcher",
    "doc-searcher"
)

foreach ($agent in $Agents) {
    $dst = Join-Path $ClaudeDir "agents\${agent}.md"

    if (Test-Path $dst) {
        $item = Get-Item $dst -Force
        $isSymlink = $item.Attributes -band [IO.FileAttributes]::ReparsePoint

        if ($isSymlink) {
            Remove-Item $dst -Force
            Write-Info "已移除 symlink: agents\${agent}.md"
        } else {
            # 检查是否是我们安装的（通过内容匹配）
            $content = Get-Content $dst -Raw -ErrorAction SilentlyContinue
            if ($content -match "排查团队|investigation team|troubleshoot") {
                Remove-Item $dst -Force
                Write-Info "已移除: agents\${agent}.md"
            } else {
                Write-Warn "跳过（非本项目文件）: agents\${agent}.md"
            }
        }

        # 恢复备份
        $bak = "${dst}.bak"
        if (Test-Path $bak) {
            Rename-Item $bak $dst -Force
            Write-Warn "已恢复备份: agents\${agent}.md"
        }
    }
}

# --- 移除 Command 文件 ---
Write-Host ""
Write-Host "🗑  移除 /investigate 命令..."

$dst = Join-Path $ClaudeDir "commands\investigate.md"
if (Test-Path $dst) {
    $item = Get-Item $dst -Force
    Remove-Item $dst -Force
    Write-Info "已移除: commands\investigate.md"

    $bak = "${dst}.bak"
    if (Test-Path $bak) {
        Rename-Item $bak $dst -Force
        Write-Warn "已恢复备份: commands\investigate.md"
    }
}

# --- 处理配置目录 ---
Write-Host ""
Write-Host "🗑  移除安装目录..."

if (Test-Path $TroubleshootDir) {
    # 检查用户是否修改过配置
    $Modified = $false
    $configDir = Join-Path $TroubleshootDir "config"
    if (Test-Path $configDir) {
        Get-ChildItem -Path $configDir -Filter "*.json" | ForEach-Object {
            $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -and $content -notmatch "YOUR_") {
                $Modified = $true
            }
        }
    }

    if ($Modified) {
        Write-Host ""
        Write-Warn "检测到你修改过配置文件。"
        $reply = Read-Host "是否保留配置目录 $TroubleshootDir？[Y/n]"
        if ($reply -match "^[Nn]") {
            Remove-Item $TroubleshootDir -Recurse -Force
            Write-Info "已删除: $TroubleshootDir"
        } else {
            # 只清理非配置文件
            Remove-Item (Join-Path $TroubleshootDir ".install-info.json") -Force -ErrorAction SilentlyContinue
            $templatesDir = Join-Path $TroubleshootDir "templates"
            if (Test-Path $templatesDir) { Remove-Item $templatesDir -Recurse -Force }
            Write-Info "已保留配置目录，仅清理模板和元数据"
        }
    } else {
        Remove-Item $TroubleshootDir -Recurse -Force
        Write-Info "已删除: $TroubleshootDir"
    }
}

# --- 完成 ---
Write-Host ""
Write-Host "╔══════════════════════════════════════════╗"
Write-Host "║   ✅ 卸载完成！                          ║"
Write-Host "╚══════════════════════════════════════════╝"
Write-Host ""
Write-Host "Agent 定义和 /investigate 命令已移除。"
Write-Host "你可以安全地删除本 repo 目录。"
