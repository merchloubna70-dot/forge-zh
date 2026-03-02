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

# ── 计算 nvm node bin 路径（运行时解析）─────────────────
# 不 source ~/.zshrc（避免 starship/fzf/zoxide 全部重跑造成闪烁）
# 只拼接 PATH，让各面板的 login shell 能直接找到 claude/codex/gemini
NVM_NODE_BIN=""
if [[ -d "$NVM_DIR/versions/node" ]]; then
    latest_node=$(ls "$NVM_DIR/versions/node/" 2>/dev/null | sort -V | tail -1)
    if [[ -n "$latest_node" ]]; then
        NVM_NODE_BIN="$NVM_DIR/versions/node/$latest_node/bin"
    fi
fi

# 每个 pane 用登录 shell（自动加载用户 rc），只在前面追加必要 PATH
# 登录 shell（bash -l / zsh -l）会加载 rc，但 tmux server 启动后
# default-command 继承的环境已含 PATH，send-keys 仅补充 nvm bin 目录
PATCH_PATH=""
if [[ -n "$NVM_NODE_BIN" ]]; then
    PATCH_PATH="export PATH=\"$NVM_NODE_BIN:\$HOME/.local/bin:\$PATH\"; "
fi

if ! "$TMUX_BIN" has-session -t "$SESSION" 2>/dev/null; then
    # new-session 时覆盖 default-command，使用不带 -l 的 bash
    # 避免三个 pane 同时走完整登录 shell 初始化造成 CPU 竞争闪烁
    "$TMUX_BIN" new-session -d -s "$SESSION" -n "工作台" -c "$WORKDIR" \
        -e "FORGE_ZH=1"

    "$TMUX_BIN" select-pane -t "$SESSION:工作台.0" -T "Claude Code"
    "$TMUX_BIN" send-keys -t "$SESSION:工作台.0" \
        "${PATCH_PATH}claude" Enter

    "$TMUX_BIN" split-window -h -t "$SESSION:工作台" -c "$WORKDIR"
    "$TMUX_BIN" select-pane -t "$SESSION:工作台.1" -T "Codex"
    "$TMUX_BIN" send-keys -t "$SESSION:工作台.1" \
        "${PATCH_PATH}codex" Enter

    "$TMUX_BIN" split-window -h -t "$SESSION:工作台" -c "$WORKDIR"
    "$TMUX_BIN" select-pane -t "$SESSION:工作台.2" -T "Gemini"
    "$TMUX_BIN" send-keys -t "$SESSION:工作台.2" \
        "${PATCH_PATH}gemini" Enter

    "$TMUX_BIN" select-layout -t "$SESSION:工作台" even-horizontal
    "$TMUX_BIN" select-pane -t "$SESSION:工作台.0"
fi

# ── 打开 Ghostty 并 attach ───────────────────────────────
# open -na：-n 强制新实例，-a 按名查找已安装的 app
open -na Ghostty.app --args \
    --title="Forge-zh 工作台" \
    -e "$TMUX_BIN" \
    attach-session -t "$SESSION"
