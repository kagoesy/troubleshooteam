#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Troubleshoot Team — 卸载脚本
# 移除 symlink 和安装的文件，保留用户修改过的配置
# ============================================================

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
echo "║   Troubleshoot Team — Uninstaller        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# --- 移除 Agent symlinks ---
echo "🗑  移除 Agent 定义..."

AGENTS=(
    "issue-analyst"
    "investigation-planner"
    "kusto-author"
    "kusto-executor"
    "devops-searcher"
    "doc-searcher"
)

for agent in "${AGENTS[@]}"; do
    dst="$CLAUDE_DIR/agents/${agent}.md"
    if [ -L "$dst" ]; then
        rm "$dst"
        info "已移除: agents/${agent}.md"
        # 恢复备份（如果有）
        if [ -f "${dst}.bak" ]; then
            mv "${dst}.bak" "$dst"
            warn "已恢复备份: agents/${agent}.md"
        fi
    elif [ -f "$dst" ]; then
        warn "跳过（非 symlink，可能是用户文件）: agents/${agent}.md"
    fi
done

# --- 移除 Command symlinks ---
echo ""
echo "🗑  移除 /investigate 命令..."

COMMANDS=("investigate")

for cmd in "${COMMANDS[@]}"; do
    dst="$CLAUDE_DIR/commands/${cmd}.md"
    if [ -L "$dst" ]; then
        rm "$dst"
        info "已移除: commands/${cmd}.md"
        if [ -f "${dst}.bak" ]; then
            mv "${dst}.bak" "$dst"
            warn "已恢复备份: commands/${cmd}.md"
        fi
    elif [ -f "$dst" ]; then
        warn "跳过（非 symlink）: commands/${cmd}.md"
    fi
done

# --- 处理配置目录 ---
echo ""
echo "🗑  移除安装目录..."

TROUBLESHOOT_DIR="$CLAUDE_DIR/troubleshooteam"

if [ -d "$TROUBLESHOOT_DIR" ]; then
    # 检查用户是否修改过配置
    MODIFIED=false
    for cfg in "$TROUBLESHOOT_DIR/config/"*.json; do
        if [ -f "$cfg" ]; then
            if grep -q "YOUR_" "$cfg" 2>/dev/null; then
                : # 还是模板，未修改
            else
                MODIFIED=true
                break
            fi
        fi
    done

    if [ "$MODIFIED" = true ]; then
        echo ""
        warn "检测到你修改过配置文件。"
        read -p "是否保留配置目录 $TROUBLESHOOT_DIR? [Y/n] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            rm -rf "$TROUBLESHOOT_DIR"
            info "已删除: $TROUBLESHOOT_DIR"
        else
            # 只删除非配置文件
            rm -f "$TROUBLESHOOT_DIR/.install-source"
            rm -rf "$TROUBLESHOOT_DIR/templates"
            info "已保留配置目录，仅清理模板和元数据"
        fi
    else
        rm -rf "$TROUBLESHOOT_DIR"
        info "已删除: $TROUBLESHOOT_DIR"
    fi
fi

# --- 完成 ---
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   ✅ 卸载完成！                          ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Agent 定义和 /investigate 命令已移除。"
echo "你可以安全地删除本 repo 目录。"
