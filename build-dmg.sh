#!/usr/bin/env bash
# build-dmg.sh — Forge-zh DMG 打包脚本
# 使用系统自带 hdiutil，无需 sudo，无需 create-dmg
# 用法：bash build-dmg.sh [/path/to/ghostty-repo]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(cat "$SCRIPT_DIR/VERSION")"
DMG_NAME="Forge-zh-${VERSION}.dmg"
STAGING="$SCRIPT_DIR/build/dmg-staging"
TEMP_DMG="$SCRIPT_DIR/build/temp-rw.dmg"
OUTPUT="$SCRIPT_DIR/build/$DMG_NAME"

mkdir -p "$SCRIPT_DIR/build"

# Ghostty 仓库路径（支持命令行参数覆盖）
GHOSTTY_REPO="${1:-${GHOSTTY_REPO_PATH:-$HOME/Projects/ghostty}}"

# ── 查找 Ghostty 构建产物 ─────────────────────────────────
GHOSTTY_SRC=""
for candidate in \
    "$GHOSTTY_REPO/zig-out/Ghostty.app" \
    "$GHOSTTY_REPO/macos/build/ReleaseLocal/Ghostty.app"; do
    if [[ -d "$candidate" ]]; then
        GHOSTTY_SRC="$candidate"
        break
    fi
done

if [[ -z "$GHOSTTY_SRC" ]]; then
    printf "错误：找不到 Ghostty.app 构建产物\n" >&2
    printf "请先构建：\n" >&2
    printf "  cd %s\n" "$GHOSTTY_REPO" >&2
    printf "  /opt/homebrew/bin/zig build -Doptimize=ReleaseFast\n" >&2
    printf "或指定仓库路径：\n" >&2
    printf "  bash build-dmg.sh /path/to/ghostty\n" >&2
    exit 1
fi

printf "使用 Ghostty: %s\n" "$GHOSTTY_SRC"
printf "输出 DMG: %s\n\n" "$OUTPUT"

# ── [1] 组装暂存目录 ──────────────────────────────────────
printf "[1/5] 组装 DMG 内容...\n"

rm -rf "$STAGING"
mkdir -p "$STAGING/scripts"

cp -R "$GHOSTTY_SRC" "$STAGING/Ghostty.app"
printf "  ✓ Ghostty.app（%s）\n" "$(du -sh "$STAGING/Ghostty.app" | cut -f1)"

cp -R "$SCRIPT_DIR/Forge-zh-launcher/Forge-zh.app" "$STAGING/Forge-zh.app"
chmod +x "$STAGING/Forge-zh.app/Contents/MacOS/Forge-zh"
printf "  ✓ Forge-zh.app（桌面启动器）\n"

cp "$SCRIPT_DIR/scripts/install.sh" "$STAGING/install.sh"
chmod +x "$STAGING/install.sh"
printf "  ✓ install.sh\n"

cp "$SCRIPT_DIR/scripts/forge-zh-launch.sh"      "$STAGING/scripts/"
cp "$SCRIPT_DIR/scripts/forge-zh-yank.sh"        "$STAGING/scripts/"
cp "$SCRIPT_DIR/scripts/forge-zh-diagnose.sh"    "$STAGING/scripts/"
cp "$SCRIPT_DIR/scripts/uninstall.sh"            "$STAGING/scripts/"
cp "$SCRIPT_DIR/scripts/tmux.conf"               "$STAGING/scripts/"
cp "$SCRIPT_DIR/scripts/tmux-forge-append.conf"  "$STAGING/scripts/"
chmod +x "$STAGING/scripts/"forge-zh-*.sh "$STAGING/scripts/uninstall.sh"
printf "  ✓ scripts/\n"

cp "$SCRIPT_DIR/README.md" "$STAGING/README.md"
printf "  ✓ README.md\n"

ln -sf /Applications "$STAGING/Applications"
printf "  ✓ Applications 快捷方式\n"

# ── [2] Ad-hoc 代码签名（避免其他 Mac 上 Gatekeeper 阻止）
printf "\n[2/5] 代码签名（ad-hoc）...\n"

sign_app() {
    local app="$1"
    if codesign --sign - --force --deep --preserve-metadata=entitlements "$app" 2>/dev/null; then
        printf "  ✓ 已签名: %s\n" "$(basename "$app")"
    else
        printf "  ! 签名跳过（不影响安装）: %s\n" "$(basename "$app")"
    fi
}

sign_app "$STAGING/Ghostty.app"
sign_app "$STAGING/Forge-zh.app"

# ── [3] 计算 DMG 大小 ─────────────────────────────────────
printf "\n[3/5] 计算 DMG 大小...\n"

STAGING_KB=$(du -sk "$STAGING" | cut -f1)
DMG_MB=$(( (STAGING_KB / 1024) * 14 / 10 + 100 ))
printf "  暂存目录：%sMB → DMG 分配：%sMB\n" "$(( STAGING_KB / 1024 ))" "$DMG_MB"

# ── [4] 创建 DMG ──────────────────────────────────────────
printf "\n[4/5] 创建 DMG...\n"

rm -f "$TEMP_DMG" "$OUTPUT"

hdiutil create \
    -srcfolder "$STAGING" \
    -volname "Forge-zh ${VERSION}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,b=16" \
    -format UDRW \
    -size "${DMG_MB}m" \
    "$TEMP_DMG"

# 设置 Finder 窗口布局
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" \
    | grep "/Volumes/" | tail -1 \
    | sed 's/.*\(\/Volumes\/.*\)/\1/')
printf "  挂载到：%s\n" "$MOUNT_DIR"
sleep 2

osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "Forge-zh ${VERSION}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 800, 520}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        set position of item "Ghostty.app"   of container window to {140, 180}
        set position of item "Forge-zh.app"  of container window to {340, 180}
        set position of item "Applications"  of container window to {560, 180}
        set position of item "install.sh"    of container window to {140, 350}
        set position of item "README.md"     of container window to {340, 350}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
APPLESCRIPT

hdiutil detach "$MOUNT_DIR" -quiet

# ── [5] 压缩为只读 DMG ────────────────────────────────────
printf "\n[5/5] 压缩 DMG...\n"

hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$OUTPUT"

rm -f "$TEMP_DMG"

DMG_SIZE=$(du -sh "$OUTPUT" | cut -f1)
printf "\n╔════════════════════════════════════════╗\n"
printf "║   DMG 打包完成！                       ║\n"
printf "╠════════════════════════════════════════╣\n"
printf "║  文件：build/%s\n" "$DMG_NAME"
printf "║  大小：%s\n" "$DMG_SIZE"
printf "╚════════════════════════════════════════╝\n"
