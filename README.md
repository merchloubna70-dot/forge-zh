# Forge-zh — 中文开发者 AI 终端工作站

开箱即用，三大 AI 编程助手并排，简体中文界面。

## 包含组件

| 组件 | 说明 |
|------|------|
| Ghostty（简体中文版） | 高性能终端，菜单全面汉化 |
| tmux | 三栏均分面板管理 |
| Claude Code CLI | Anthropic AI 编程助手 |
| OpenAI Codex CLI | OpenAI AI 编程助手 |
| Google Gemini CLI | Google AI 编程助手 |

## 布局

```
┌─────────────────┬─────────────────┬─────────────────┐
│  Claude Code    │   Codex CLI     │   Gemini CLI    │
│                 │                 │                 │
│  claude>        │  codex>         │  gemini>        │
└─────────────────┴─────────────────┴─────────────────┘
```

## 安装

1. 打开 DMG
2. 双击 `install.sh`（或终端运行 `zsh install.sh`）
3. 双击桌面 **Forge-zh** 图标启动

> 首次启动需在「系统设置 → 隐私与安全性」中点击「仍要打开」

## 配置 API Keys

```bash
# Claude Code
claude /login

# OpenAI Codex
export OPENAI_API_KEY="sk-..."    # 写入 ~/.zshrc

# Google Gemini
gemini auth login
```

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+b 1/2/3` | 切换三栏面板 |
| `Ctrl+b F` | 快速打开 Forge-zh session |
| `Ctrl+b [` | 进入滚动/复制模式 |
| `q` | 退出复制模式 |

## 版本

v1.0.0 — Ghostty 简体中文优化版（含菜单汉化 v1.0.0~v1.0.7 全量修复）
