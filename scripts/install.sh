#!/usr/bin/env zsh
# install.sh — Forge-zh 安装脚本
# 无需 sudo，全部用户空间操作
# 用法：在挂载的 DMG 内双击，或终端运行 zsh install.sh

set -euo pipefail

FORGE_VERSION="1.0.0"
SCRIPT_DIR="${0:A:h}"
BREW="/opt/homebrew/bin/brew"
NVM_DIR="$HOME/.nvm"

# ── 彩色输出 ──────────────────────────────────────────────
log_info()  { print -P "%F{blue}[Forge-zh]%f $1"; }
log_ok()    { print -P "%F{green}[✓]%f $1"; }
log_warn()  { print -P "%F{yellow}[!]%f $1"; }
log_error() { print -P "%F{red}[✗]%f $1" >&2; }

print ""
print "╔════════════════════════════════════════╗"
print "║   Forge-zh v${FORGE_VERSION} 安装程序           ║"
print "║   中文开发者 AI 终端工作站              ║"
print "╚════════════════════════════════════════╝"
print ""

# ── [0] 前置检测 ──────────────────────────────────────────
log_info "检查运行环境..."

if [[ "$(uname)" != "Darwin" ]]; then
    log_error "仅支持 macOS（当前系统：$(uname)）"; exit 1
fi

# macOS 版本检测（要求 12+）
OS_VER=$(sw_vers -productVersion | cut -d. -f1)
if (( OS_VER < 12 )); then
    log_error "需要 macOS 12 Monterey 或更高版本（当前：$(sw_vers -productVersion)）"; exit 1
fi
log_ok "macOS $(sw_vers -productVersion)"

# Homebrew
HAS_BREW=false
if [[ -x "$BREW" ]]; then
    HAS_BREW=true
    log_ok "Homebrew 已安装"
else
    log_warn "未检测到 Homebrew（/opt/homebrew/bin/brew），跳过 tmux 自动安装"
fi

# tmux 检测与安装
if command -v tmux &>/dev/null; then
    log_ok "tmux $(tmux -V | cut -d' ' -f2) 已安装"
elif [[ "$HAS_BREW" == "true" ]]; then
    log_info "正在安装 tmux..."
    "$BREW" install tmux
    log_ok "tmux 安装完成"
else
    log_error "未找到 tmux，请先安装：/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\" 后重试"
    exit 1
fi

# nvm / Node.js
HAS_NVM=false
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
    HAS_NVM=true
    log_ok "nvm 已安装（Node.js $(node --version 2>/dev/null || echo '未知')）"
else
    log_warn "未找到 nvm，AI CLI 安装将跳过（请手动安装 Node.js 后运行：npm install -g @anthropic-ai/claude-code @openai/codex @google/gemini-cli）"
fi

# ── [1] 安装 Ghostty 简体中文版 ───────────────────────────
log_info "安装 Ghostty 简体中文版..."

GHOSTTY_SRC="$SCRIPT_DIR/Ghostty.app"
GHOSTTY_DST="/Applications/Ghostty.app"

if [[ ! -d "$GHOSTTY_SRC" ]]; then
    log_error "找不到 Ghostty.app（预期路径：$GHOSTTY_SRC）"; exit 1
fi

if [[ -d "$GHOSTTY_DST" ]]; then
    BACKUP="${GHOSTTY_DST}.bak"
    log_warn "已存在 Ghostty.app，备份为 Ghostty.app.bak"
    rm -rf "$BACKUP"
    mv "$GHOSTTY_DST" "$BACKUP"
fi

cp -R "$GHOSTTY_SRC" "$GHOSTTY_DST"
log_ok "Ghostty 简体中文版已安装到 /Applications/Ghostty.app"

# ── [2] 安装 tmux 配置 ────────────────────────────────────
log_info "配置 tmux..."

TMUX_CONF_SRC="$SCRIPT_DIR/scripts/tmux.conf"
TMUX_CONF_APPEND="$SCRIPT_DIR/scripts/tmux-forge-append.conf"
TMUX_CONF_DST="$HOME/.tmux.conf"

if [[ -f "$TMUX_CONF_DST" ]]; then
    # 已有配置：追加 Forge-zh 快捷键片段
    if grep -q "Forge-zh" "$TMUX_CONF_DST" 2>/dev/null; then
        log_ok "tmux 已含 Forge-zh 配置，跳过"
    else
        BACKUP_TMUX="$HOME/.tmux.conf.bak.$(date +%Y%m%d_%H%M%S)"
        log_warn "已存在 ~/.tmux.conf，备份到 $BACKUP_TMUX"
        cp "$TMUX_CONF_DST" "$BACKUP_TMUX"
        cat "$TMUX_CONF_APPEND" >> "$TMUX_CONF_DST"
        log_ok "已追加 Forge-zh 快捷键到现有 tmux 配置"
    fi
else
    cp "$TMUX_CONF_SRC" "$TMUX_CONF_DST"
    log_ok "tmux 配置已安装到 ~/.tmux.conf"
fi

# ── [3] 安装三大 AI CLI ───────────────────────────────────
install_npm_pkg() {
    local pkg="$1" cmd="$2"
    if command -v "$cmd" &>/dev/null; then
        log_ok "$cmd 已安装，跳过"
    else
        log_info "安装 $pkg..."
        npm install -g "$pkg"
        log_ok "$cmd 安装完成"
    fi
}

if [[ "$HAS_NVM" == "true" ]]; then
    log_info "检查 AI CLI 工具..."
    install_npm_pkg "@anthropic-ai/claude-code" "claude"
    install_npm_pkg "@openai/codex"             "codex"
    install_npm_pkg "@google/gemini-cli"        "gemini"
fi

# ── [4] 安装启动脚本 ──────────────────────────────────────
log_info "安装启动脚本..."

mkdir -p "$HOME/.local/bin"
cp "$SCRIPT_DIR/scripts/forge-zh-launch.sh" "$HOME/.local/bin/forge-zh-launch"
chmod +x "$HOME/.local/bin/forge-zh-launch"
log_ok "启动脚本已安装到 ~/.local/bin/forge-zh-launch"

# 确保 ~/.local/bin 在 PATH 中（写入 ~/.zshrc 若未包含）
if ! grep -q '\.local/bin' "$HOME/.zshrc" 2>/dev/null; then
    echo '\n# Forge-zh\nexport PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    log_ok "已将 ~/.local/bin 追加到 ~/.zshrc PATH"
fi

# ── [5] 创建桌面图标 ──────────────────────────────────────
log_info "创建桌面图标..."

LAUNCHER_SRC="$SCRIPT_DIR/Forge-zh.app"
LAUNCHER_DESKTOP="$HOME/Desktop/Forge-zh.app"

if [[ -d "$LAUNCHER_DESKTOP" ]]; then
    rm -rf "$LAUNCHER_DESKTOP"
fi
cp -R "$LAUNCHER_SRC" "$LAUNCHER_DESKTOP"
chmod +x "$LAUNCHER_DESKTOP/Contents/MacOS/Forge-zh"
log_ok "桌面图标已创建：~/Desktop/Forge-zh.app"

# ── [6] 完成 ─────────────────────────────────────────────
print ""
print "╔════════════════════════════════════════╗"
print "║   Forge-zh v${FORGE_VERSION} 安装完成！         ║"
print "╠════════════════════════════════════════╣"
print "║  1. 双击桌面 Forge-zh 图标启动工作台  ║"
print "║  2. 首次启动请在「安全性」中允许运行  ║"
print "║  3. 配置 API Keys：                   ║"
print "║     claude: claude /login             ║"
print "║     codex:  export OPENAI_API_KEY=... ║"
print "║     gemini: gemini auth login         ║"
print "╚════════════════════════════════════════╝"
print ""
