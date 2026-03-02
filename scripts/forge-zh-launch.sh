#!/usr/bin/env bash
# forge-zh-launch.sh — Forge-zh 工作台启动器
# 1. 后台建 tmux 三栏 session（幂等：已存在则直接 attach）
# 2. 打开 Ghostty 并 attach

TMUX=/opt/homebrew/opt/tmux/bin/tmux
NVM_DIR="$HOME/.nvm"
SESSION="forge-zh"
WORKDIR="$HOME"

export NVM_DIR
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

INIT="export NVM_DIR=\"$HOME/.nvm\"; source \"\$NVM_DIR/nvm.sh\""

if ! $TMUX has-session -t "$SESSION" 2>/dev/null; then
    $TMUX new-session -d -s "$SESSION" -n "工作台" -c "$WORKDIR"

    $TMUX select-pane -t "$SESSION:工作台.0" -T "Claude Code"
    $TMUX send-keys -t "$SESSION:工作台.0" \
        "$INIT; clear; echo '== Claude Code CLI =='; echo; claude" Enter

    $TMUX split-window -h -t "$SESSION:工作台" -c "$WORKDIR"
    $TMUX select-pane -t "$SESSION:工作台.1" -T "Codex"
    $TMUX send-keys -t "$SESSION:工作台.1" \
        "$INIT; clear; echo '== OpenAI Codex CLI =='; echo; codex" Enter

    $TMUX split-window -h -t "$SESSION:工作台" -c "$WORKDIR"
    $TMUX select-pane -t "$SESSION:工作台.2" -T "Gemini"
    $TMUX send-keys -t "$SESSION:工作台.2" \
        "$INIT; clear; echo '== Google Gemini CLI =='; echo; gemini" Enter

    $TMUX select-layout -t "$SESSION:工作台" even-horizontal
    $TMUX select-pane -t "$SESSION:工作台.0"
fi

open -na Ghostty.app --args \
    --title="Forge-zh 工作台" \
    -e /opt/homebrew/opt/tmux/bin/tmux \
    attach-session -t "$SESSION"
