#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Troubleshoot Team — 安装脚本
# 将 agents 和 commands symlink 到 ~/.claude/
# 配置和模板复制到 ~/.claude/troubleshooteam/
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Troubleshoot Team — Installer          ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# --- 检查源文件是否存在 ---
if [ ! -d "$SCRIPT_DIR/.claude/agents" ]; then
    error "找不到 .claude/agents 目录，请确认在项目根目录运行"
    exit 1
fi

# --- 创建目标目录 ---
mkdir -p "$CLAUDE_DIR/agents"
mkdir -p "$CLAUDE_DIR/commands"
mkdir -p "$CLAUDE_DIR/troubleshooteam/config"
mkdir -p "$CLAUDE_DIR/troubleshooteam/templates"

# --- 安装 Agent 定义（symlink） ---
echo ""
echo "📦 安装 Agent 定义..."

AGENTS=(
    "issue-analyst"
    "investigation-planner"
    "kusto-author"
    "kusto-executor"
    "devops-searcher"
    "doc-searcher"
)

for agent in "${AGENTS[@]}"; do
    src="$SCRIPT_DIR/.claude/agents/${agent}.md"
    dst="$CLAUDE_DIR/agents/${agent}.md"

    if [ -L "$dst" ]; then
        # 已有 symlink，先删除
        rm "$dst"
        warn "已覆盖: agents/${agent}.md"
    elif [ -f "$dst" ]; then
        # 已有普通文件，备份
        mv "$dst" "${dst}.bak"
        warn "已备份原有文件: agents/${agent}.md → ${agent}.md.bak"
    fi

    ln -s "$src" "$dst"
    info "agents/${agent}.md → $(realpath --relative-to="$CLAUDE_DIR" "$src" 2>/dev/null || echo "$src")"
done

# --- 安装 /investigate 命令（symlink） ---
echo ""
echo "📦 安装 /investigate 命令..."

COMMANDS=("investigate")

for cmd in "${COMMANDS[@]}"; do
    src="$SCRIPT_DIR/.claude/commands/${cmd}.md"
    dst="$CLAUDE_DIR/commands/${cmd}.md"

    if [ -L "$dst" ]; then
        rm "$dst"
        warn "已覆盖: commands/${cmd}.md"
    elif [ -f "$dst" ]; then
        mv "$dst" "${dst}.bak"
        warn "已备份原有文件: commands/${cmd}.md → ${cmd}.md.bak"
    fi

    ln -s "$src" "$dst"
    info "commands/${cmd}.md → $(realpath --relative-to="$CLAUDE_DIR" "$src" 2>/dev/null || echo "$src")"
done

# --- 复制配置文件（不覆盖已有配置） ---
echo ""
echo "📦 安装配置文件..."

CONFIG_FILES=(
    "adx-clusters.json"
    "devops-projects.json"
    "agent-tools.json"
)

for cfg in "${CONFIG_FILES[@]}"; do
    src="$SCRIPT_DIR/config/${cfg}"
    dst="$CLAUDE_DIR/troubleshooteam/config/${cfg}"

    if [ -f "$dst" ]; then
        warn "配置已存在，跳过（不覆盖）: config/${cfg}"
    else
        cp "$src" "$dst"
        info "config/${cfg}"
    fi
done

# --- 复制模板文件 ---
echo ""
echo "📦 安装报告模板..."

src="$SCRIPT_DIR/templates/report-template.md"
dst="$CLAUDE_DIR/troubleshooteam/templates/report-template.md"

if [ -L "$dst" ]; then
    rm "$dst"
fi
ln -s "$src" "$dst"
info "templates/report-template.md"

# --- 记录安装来源（方便卸载） ---
echo "$SCRIPT_DIR" > "$CLAUDE_DIR/troubleshooteam/.install-source"
info "已记录安装来源"

# --- 完成 ---
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   ✅ 安装完成！                          ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "已安装到: $CLAUDE_DIR/"
echo ""
echo "📌 下一步："
echo "   1. 编辑配置文件（如果是首次安装）："
echo "      $CLAUDE_DIR/troubleshooteam/config/adx-clusters.json"
echo "      $CLAUDE_DIR/troubleshooteam/config/devops-projects.json"
echo ""
echo "   2. 确保 Azure CLI 已登录："
echo "      az login"
echo ""
echo "   3. 在任意目录启动 Claude Code，使用："
echo "      /investigate 工单#12345: 问题描述..."
echo ""
echo "⚠️  请勿删除此 repo 目录（symlink 指向这里）："
echo "   $SCRIPT_DIR"
echo ""
echo "📦 更新: cd $SCRIPT_DIR && git pull"
echo "🗑  卸载: bash $SCRIPT_DIR/uninstall.sh"
