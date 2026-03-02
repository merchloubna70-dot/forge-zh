#!/usr/bin/env bash
# forge-zh-launch.sh — Forge-zh 工作台启动器
# 注意：install.sh 会将 TMUX_BIN_PLACEHOLDER 替换为本机实际 tmux 路径
# 1. 后台建 tmux 三栏 session（幂等：已存在则直接 attach）
# 2. 打开 Ghostty 并 attach

# tmux 路径（由 install.sh 在安装时注入，亦支持 PATH 查找）
TMUX_BIN="TMUX_BIN_PLACEHOLDER"
# 若占位符未被替换（直接运行原始脚本），自动查找
if [[ "$TMUX_BIN" == "TMUX_BIN_PLACEHOLDER" ]] || [[ ! -x "$TMUX_BIN" ]]; then
    if command -v tmux &>/dev/null; then
        TMUX_BIN="$(command -v tmux)"
    else
        for candidate in \
            /opt/homebrew/opt/tmux/bin/tmux \
            /usr/local/opt/tmux/bin/tmux \
            /opt/homebrew/bin/tmux \
            /usr/local/bin/tmux; do
            if [[ -x "$candidate" ]]; then
                TMUX_BIN="$candidate"; break
            fi
        done
    fi
fi

if [[ ! -x "$TMUX_BIN" ]]; then
    osascript -e 'display alert "找不到 tmux" message "请先安装 tmux：\nbrew install tmux"'
    exit 1
fi

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
SESSION="forge-zh"
WORKDIR="$HOME"

# 激活 nvm（让本脚本进程能找到 claude/codex/gemini）
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh" 2>/dev/null || true
fi

# 每个面板的初始化命令：激活 nvm + 加载 shell rc
INIT='
NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then source "$NVM_DIR/nvm.sh" 2>/dev/null; fi
if [[ -s "$HOME/.zshrc" ]]; then source "$HOME/.zshrc" 2>/dev/null; fi
clear
'

if ! "$TMUX_BIN" has-session -t "$SESSION" 2>/dev/null; then
    "$TMUX_BIN" new-session -d -s "$SESSION" -n "工作台" -c "$WORKDIR"

    "$TMUX_BIN" select-pane -t "$SESSION:工作台.0" -T "Claude Code"
    "$TMUX_BIN" send-keys -t "$SESSION:工作台.0" \
        "$INIT; echo '── Claude Code CLI ──'; echo; claude" Enter

    "$TMUX_BIN" split-window -h -t "$SESSION:工作台" -c "$WORKDIR"
    "$TMUX_BIN" select-pane -t "$SESSION:工作台.1" -T "Codex"
    "$TMUX_BIN" send-keys -t "$SESSION:工作台.1" \
        "$INIT; echo '── OpenAI Codex CLI ──'; echo; codex" Enter

    "$TMUX_BIN" split-window -h -t "$SESSION:工作台" -c "$WORKDIR"
    "$TMUX_BIN" select-pane -t "$SESSION:工作台.2" -T "Gemini"
    "$TMUX_BIN" send-keys -t "$SESSION:工作台.2" \
        "$INIT; echo '── Google Gemini CLI ──'; echo; gemini" Enter

    "$TMUX_BIN" select-layout -t "$SESSION:工作台" even-horizontal
    "$TMUX_BIN" select-pane -t "$SESSION:工作台.0"
fi

open -na Ghostty.app --args \
    --title="Forge-zh 工作台" \
    -e "$TMUX_BIN" \
    attach-session -t "$SESSION"
