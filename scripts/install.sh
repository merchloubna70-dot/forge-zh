#!/usr/bin/env bash
# install.sh — Forge-zh 安装脚本
# 无需 sudo，全部用户空间操作
# 支持 Apple Silicon Mac（/opt/homebrew）和 Intel Mac（/usr/local）
# 用法：在挂载的 DMG 内双击，或终端运行 bash install.sh

set -euo pipefail

# ── 脚本目录（兼容 bash + 从任意位置调用）─────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 版本号从 VERSION 文件读取（单一真实源）────────────────
FORGE_VERSION="$(cat "$SCRIPT_DIR/../VERSION" 2>/dev/null || echo '1.0.1')"

# ── 彩色输出 ──────────────────────────────────────────────
log_info()  { printf "\033[34m[Forge-zh]\033[0m %s\n" "$1"; }
log_ok()    { printf "\033[32m[✓]\033[0m %s\n" "$1"; }
log_warn()  { printf "\033[33m[!]\033[0m %s\n" "$1"; }
log_error() { printf "\033[31m[✗]\033[0m %s\n" "$1" >&2; }

printf "\n"
printf "╔════════════════════════════════════════╗\n"
printf "║   Forge-zh v%s 安装程序           ║\n" "$FORGE_VERSION"
printf "║   中文开发者 AI 终端工作站              ║\n"
printf "╚════════════════════════════════════════╝\n\n"

# ── [0] 前置检测 ──────────────────────────────────────────
log_info "检查运行环境..."

if [[ "$(uname)" != "Darwin" ]]; then
    log_error "仅支持 macOS（当前：$(uname)）"; exit 1
fi

OS_VER=$(sw_vers -productVersion | cut -d. -f1)
if (( OS_VER < 12 )); then
    log_error "需要 macOS 12 Monterey 或更高版本（当前：$(sw_vers -productVersion)）"; exit 1
fi
log_ok "macOS $(sw_vers -productVersion)"

# 检测 Homebrew（兼容 Apple Silicon 和 Intel）
BREW=""
if [[ -x /opt/homebrew/bin/brew ]]; then
    BREW="/opt/homebrew/bin/brew"
elif [[ -x /usr/local/bin/brew ]]; then
    BREW="/usr/local/bin/brew"
fi

if [[ -n "$BREW" ]]; then
    log_ok "Homebrew 已安装（$BREW）"
else
    log_warn "未检测到 Homebrew，跳过 tmux 自动安装"
fi

# 检测 tmux（兼容 Apple Silicon / Intel / 系统 PATH）
TMUX_BIN=""
for candidate in \
    /opt/homebrew/opt/tmux/bin/tmux \
    /usr/local/opt/tmux/bin/tmux \
    /opt/homebrew/bin/tmux \
    /usr/local/bin/tmux; do
    if [[ -x "$candidate" ]]; then
        TMUX_BIN="$candidate"; break
    fi
done
if [[ -z "$TMUX_BIN" ]] && command -v tmux &>/dev/null; then
    TMUX_BIN="$(command -v tmux)"
fi

if [[ -n "$TMUX_BIN" ]]; then
    log_ok "tmux $("$TMUX_BIN" -V | cut -d' ' -f2) 已安装"
elif [[ -n "$BREW" ]]; then
    log_info "正在安装 tmux..."
    "$BREW" install tmux
    TMUX_BIN="$(command -v tmux)"
    log_ok "tmux 安装完成"
else
    log_error "未找到 tmux。请先安装 Homebrew（https://brew.sh）后重试"
    exit 1
fi

TMUX_BIN_RESOLVED="$TMUX_BIN"

# 检测 Node.js / npm（支持 nvm、fnm、系统安装）
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
HAS_NPM=false

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh" 2>/dev/null || true
fi

if command -v npm &>/dev/null; then
    HAS_NPM=true
    log_ok "npm $(npm --version) 已安装"
else
    log_warn "未找到 npm，AI CLI（claude/codex/gemini）安装将跳过"
    log_warn "安装后请手动运行：npm install -g @anthropic-ai/claude-code @openai/codex @google/gemini-cli"
fi

# ── [1] 安装 Ghostty 简体中文版 ───────────────────────────
log_info "安装 Ghostty 简体中文版..."

GHOSTTY_SRC="$SCRIPT_DIR/Ghostty.app"
GHOSTTY_DST="/Applications/Ghostty.app"

if [[ ! -d "$GHOSTTY_SRC" ]]; then
    log_error "找不到 Ghostty.app（预期：$GHOSTTY_SRC）"
    log_error "请确保从 DMG 根目录运行 install.sh"
    exit 1
fi

if [[ -d "$GHOSTTY_DST" ]]; then
    BACKUP="${GHOSTTY_DST}.bak"
    log_warn "已存在 Ghostty.app，备份为 Ghostty.app.bak"
    rm -rf "$BACKUP"
    mv "$GHOSTTY_DST" "$BACKUP"
fi

cp -R "$GHOSTTY_SRC" "$GHOSTTY_DST"
xattr -dr com.apple.quarantine "$GHOSTTY_DST" 2>/dev/null || \
    log_warn "检疫属性清除失败（首次启动可能需在「安全性」手动允许）"

# 完整性验证
if [[ ! -x "$GHOSTTY_DST/Contents/MacOS/ghostty" ]]; then
    log_error "Ghostty 安装不完整，请重新下载 DMG 后重试"
    exit 1
fi
log_ok "Ghostty 简体中文版已安装到 /Applications/Ghostty.app"

# ── [2] 安装 tmux 配置 ────────────────────────────────────
log_info "配置 tmux..."

TMUX_CONF_SRC="$SCRIPT_DIR/scripts/tmux.conf"
TMUX_CONF_APPEND="$SCRIPT_DIR/scripts/tmux-forge-append.conf"
TMUX_CONF_DST="$HOME/.tmux.conf"

if [[ -f "$TMUX_CONF_DST" ]]; then
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
        log_ok "$cmd 已安装，跳过"; return
    fi
    log_info "安装 $pkg..."
    if npm install -g "$pkg" 2>/dev/null; then
        log_ok "$cmd 安装完成"
    else
        log_warn "$cmd 安装失败（可稍后运行：npm install -g $pkg）"
    fi
}

if [[ "$HAS_NPM" == "true" ]]; then
    log_info "检查 AI CLI 工具..."
    install_npm_pkg "@anthropic-ai/claude-code" "claude"
    install_npm_pkg "@openai/codex"             "codex"
    install_npm_pkg "@google/gemini-cli"        "gemini"
fi

# ── [4] 安装启动脚本（注入正确的 tmux 路径）──────────────
log_info "安装启动脚本..."

mkdir -p "$HOME/.local/bin" || { log_error "无法创建 ~/.local/bin"; exit 1; }

LAUNCH_DST="$HOME/.local/bin/forge-zh-launch"
sed "s|TMUX_BIN_PLACEHOLDER|${TMUX_BIN_RESOLVED}|g" \
    "$SCRIPT_DIR/scripts/forge-zh-launch.sh" > "$LAUNCH_DST"
chmod +x "$LAUNCH_DST"
log_ok "启动脚本已安装到 ~/.local/bin/forge-zh-launch"

# 安装诊断工具
if [[ -f "$SCRIPT_DIR/scripts/forge-zh-diagnose.sh" ]]; then
    cp "$SCRIPT_DIR/scripts/forge-zh-diagnose.sh" "$HOME/.local/bin/forge-zh-diagnose"
    chmod +x "$HOME/.local/bin/forge-zh-diagnose"
    log_ok "诊断工具已安装到 ~/.local/bin/forge-zh-diagnose"
fi

# 安装卸载脚本
if [[ -f "$SCRIPT_DIR/scripts/uninstall.sh" ]]; then
    cp "$SCRIPT_DIR/scripts/uninstall.sh" "$HOME/.local/bin/forge-zh-uninstall"
    chmod +x "$HOME/.local/bin/forge-zh-uninstall"
    log_ok "卸载脚本已安装到 ~/.local/bin/forge-zh-uninstall"
fi

# 安装统一复制工具（OSC 52 远端剪贴板同步 + pbcopy 兜底）
if [[ -f "$SCRIPT_DIR/scripts/forge-zh-yank.sh" ]]; then
    cp "$SCRIPT_DIR/scripts/forge-zh-yank.sh" "$HOME/.local/bin/forge-zh-yank"
    chmod +x "$HOME/.local/bin/forge-zh-yank"
    log_ok "复制工具已安装到 ~/.local/bin/forge-zh-yank"
fi

# ── [5] 确保 ~/.local/bin 在 PATH ─────────────────────────
LOCAL_BIN_LINE='export PATH="$HOME/.local/bin:$PATH"'
SHELL_NAME="$(basename "$SHELL")"

add_to_path() {
    local rc_file="$1"
    if [[ -f "$rc_file" ]] && grep -q '\.local/bin' "$rc_file" 2>/dev/null; then
        log_ok "~/.local/bin 已在 $rc_file 的 PATH 中"; return
    fi
    printf '\n# Forge-zh\n%s\n' "$LOCAL_BIN_LINE" >> "$rc_file"
    log_ok "已将 ~/.local/bin 追加到 $rc_file"
}

case "$SHELL_NAME" in
    zsh)  add_to_path "$HOME/.zshrc" ;;
    bash)
        if [[ -f "$HOME/.bash_profile" ]]; then
            add_to_path "$HOME/.bash_profile"
        else
            add_to_path "$HOME/.bashrc"
        fi ;;
    fish)
        FISH_CONFIG="$HOME/.config/fish/config.fish"
        mkdir -p "$(dirname "$FISH_CONFIG")"
        if ! grep -q '\.local/bin' "$FISH_CONFIG" 2>/dev/null; then
            printf '\n# Forge-zh\nfish_add_path "$HOME/.local/bin"\n' >> "$FISH_CONFIG"
            log_ok "已将 ~/.local/bin 追加到 fish config"
        else
            log_ok "~/.local/bin 已在 fish config 的 PATH 中"
        fi ;;
    *) log_warn "Shell $SHELL_NAME：请手动添加 export PATH=\"\$HOME/.local/bin:\$PATH\" 到启动文件" ;;
esac

# ── [6] 创建桌面图标 ──────────────────────────────────────
log_info "创建桌面图标..."

LAUNCHER_SRC="$SCRIPT_DIR/Forge-zh.app"
LAUNCHER_DESKTOP="$HOME/Desktop/Forge-zh.app"

if [[ -d "$LAUNCHER_DESKTOP" ]]; then
    rm -rf "$LAUNCHER_DESKTOP"
fi
cp -R "$LAUNCHER_SRC" "$LAUNCHER_DESKTOP"
chmod +x "$LAUNCHER_DESKTOP/Contents/MacOS/Forge-zh"
xattr -dr com.apple.quarantine "$LAUNCHER_DESKTOP" 2>/dev/null || true
log_ok "桌面图标已创建：~/Desktop/Forge-zh.app"

# ── [7] 安装验证 ──────────────────────────────────────────
printf "\n[安装验证]\n"
[[ -d "/Applications/Ghostty.app" ]]            && log_ok "Ghostty.app"  || log_warn "Ghostty.app 未找到"
[[ -x "$HOME/.local/bin/forge-zh-launch" ]]     && log_ok "启动脚本"     || log_warn "启动脚本未找到"
command -v claude &>/dev/null                    && log_ok "claude CLI"   || log_warn "claude 未安装（需配置 API Key）"
command -v codex  &>/dev/null                    && log_ok "codex CLI"    || log_warn "codex 未安装"
command -v gemini &>/dev/null                    && log_ok "gemini CLI"   || log_warn "gemini 未安装"

# ── [8] 完成提示 ──────────────────────────────────────────
printf "\n"
printf "╔════════════════════════════════════════╗\n"
printf "║   Forge-zh v%s 安装完成！         ║\n" "$FORGE_VERSION"
printf "╠════════════════════════════════════════╣\n"
printf "║  1. 双击桌面 Forge-zh 图标启动工作台  ║\n"
printf "║  2. 首次启动请在「安全性」中允许运行  ║\n"
printf "║  3. 配置 API Keys：                   ║\n"
printf "║     claude：claude /login             ║\n"
printf "║     codex： export OPENAI_API_KEY=... ║\n"
printf "║     gemini：gemini auth login         ║\n"
printf "║  4. 问题诊断：forge-zh-diagnose       ║\n"
printf "║  5. 卸载：    forge-zh-uninstall      ║\n"
printf "╚════════════════════════════════════════╝\n\n"
