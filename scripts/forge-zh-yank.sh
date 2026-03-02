#!/usr/bin/env bash
# forge-zh-yank — 统一复制通道
# 同时写入：tmux buffer + OSC 52（ToDesk 远端剪贴板同步）+ pbcopy（本地兜底）
#
# tmux.conf 中通过 copy-pipe-and-cancel 调用本脚本：
#   bind -T copy-mode-vi y send -X copy-pipe-and-cancel "~/.local/bin/forge-zh-yank"

buf=$(cat)
[[ -z "$buf" ]] && exit 0

# ── 1. 写入 tmux buffer（跨 pane 粘贴，Ctrl+b v）───────────
printf '%s' "$buf" | tmux load-buffer - 2>/dev/null || true

# ── 2. OSC 52（终端 escape 序列，ToDesk / 远程桌面剪贴板同步）──
# 格式：ESC ] 52 ; c ; <base64> BEL
# Ghostty 和 iTerm2 均支持转发此序列给远端
encoded=$(printf '%s' "$buf" | base64 | tr -d '\n')
# 向 Ghostty 所在的 TTY 发送（通过 tmux passthrough）
printf "\033Ptmux;\033\033]52;c;%s\a\033\\" "$encoded" 2>/dev/null || true

# ── 3. pbcopy（本地 Mac 剪贴板兜底）────────────────────────
printf '%s' "$buf" | pbcopy 2>/dev/null || true

# ── 4. 视觉反馈（tmux 状态栏短暂提示）──────────────────────
char_count=${#buf}
tmux display-message "已复制 ${char_count} 个字符" 2>/dev/null || true
