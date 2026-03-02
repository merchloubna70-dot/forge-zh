#!/usr/bin/env bash
# uninstall.sh — Forge-zh 卸载脚本

printf "╔════════════════════════════════════════╗\n"
printf "║   Forge-zh 卸载程序                    ║\n"
printf "╚════════════════════════════════════════╝\n\n"

log_ok()   { printf "\033[32m[✓]\033[0m %s\n" "$1"; }
log_info() { printf "\033[34m[Forge-zh]\033[0m %s\n" "$1"; }

log_info "正在卸载 Forge-zh...\n"

# 停止 tmux session（如果在运行）
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

if [[ -n "$TMUX_BIN" ]] && "$TMUX_BIN" has-session -t forge-zh 2>/dev/null; then
    "$TMUX_BIN" kill-session -t forge-zh 2>/dev/null || true
    log_ok "tmux session forge-zh 已终止"
fi

# 删除启动脚本和工具
rm -f  "$HOME/.local/bin/forge-zh-launch"   && log_ok "forge-zh-launch 已删除"
rm -f  "$HOME/.local/bin/forge-zh-diagnose" && log_ok "forge-zh-diagnose 已删除"
rm -f  "$HOME/.local/bin/forge-zh-uninstall" 2>/dev/null || true

# 删除桌面图标
if [[ -d "$HOME/Desktop/Forge-zh.app" ]]; then
    rm -rf "$HOME/Desktop/Forge-zh.app"
    log_ok "桌面 Forge-zh.app 已删除"
fi

# 询问是否删除 Ghostty.app
printf "\n是否同时删除 /Applications/Ghostty.app？[y/N] "
read -r ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
    rm -rf /Applications/Ghostty.app
    log_ok "Ghostty.app 已删除"
fi

# 清理 tmux.conf 中 Forge-zh 追加的内容
if [[ -f "$HOME/.tmux.conf" ]] && grep -q "Forge-zh" "$HOME/.tmux.conf" 2>/dev/null; then
    # 备份再清理
    cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.before-uninstall"
    grep -v "Forge-zh" "$HOME/.tmux.conf.before-uninstall" > "$HOME/.tmux.conf" 2>/dev/null || true
    log_ok "~/.tmux.conf 中 Forge-zh 相关行已清理（备份：~/.tmux.conf.before-uninstall）"
fi

printf "\n"
printf "╔════════════════════════════════════════╗\n"
printf "║   ✓ Forge-zh 已成功卸载               ║\n"
printf "╚════════════════════════════════════════╝\n\n"
