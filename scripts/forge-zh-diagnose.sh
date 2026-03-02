#!/usr/bin/env bash
# forge-zh-diagnose.sh — Forge-zh 环境诊断工具

printf "=== Forge-zh 环境诊断 ===\n\n"

check() {
    local label="$1"
    if eval "$2" &>/dev/null 2>&1; then
        printf "  ✓ %s\n" "$label"
    else
        printf "  ✗ %s\n" "$label"
    fi
}

printf "[系统]\n"
printf "  macOS %s\n\n" "$(sw_vers -productVersion)"

printf "[核心组件]\n"
check "Ghostty.app"  "[[ -d /Applications/Ghostty.app ]]"
check "tmux"         "command -v tmux"
check "启动脚本"      "[[ -x $HOME/.local/bin/forge-zh-launch ]]"

printf "\n[AI CLI]\n"
check "claude" "command -v claude"
check "codex"  "command -v codex"
check "gemini" "command -v gemini"

printf "\n[nvm / Node]\n"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
check "nvm" "[[ -s $NVM_DIR/nvm.sh ]]"
if [[ -d "$NVM_DIR/versions/node" ]]; then
    latest_node=$(ls "$NVM_DIR/versions/node/" 2>/dev/null | sort -V | tail -1)
    if [[ -n "$latest_node" ]]; then
        printf "  Node 版本（最新）：%s\n" "$latest_node"
    fi
fi

printf "\n[tmux session]\n"
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
    if "$TMUX_BIN" has-session -t forge-zh 2>/dev/null; then
        PANE_COUNT=$("$TMUX_BIN" list-panes -t forge-zh 2>/dev/null | wc -l | tr -d ' ')
        printf "  ✓ forge-zh session 存在（%s 个面板）\n" "$PANE_COUNT"
    else
        printf "  - forge-zh session 未运行\n"
    fi
fi

printf "\n=== 诊断完成 ===\n"
