#!/usr/bin/env zsh
# build-dmg.sh — Forge-zh DMG 打包脚本
# 使用系统自带 hdiutil，无需 sudo，无需 create-dmg

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
VERSION=$(cat "$SCRIPT_DIR/VERSION")
DMG_NAME="Forge-zh-${VERSION}.dmg"
STAGING="$SCRIPT_DIR/build/dmg-staging"
TEMP_DMG="$SCRIPT_DIR/build/temp-rw.dmg"
OUTPUT="$SCRIPT_DIR/build/$DMG_NAME"

# Ghostty 构建产物路径（优先 zig-out，回退到 macos/build）
GHOSTTY_REPO="$HOME/Projects/ghostty"
GHOSTTY_SRC=""
if [[ -d "$GHOSTTY_REPO/zig-out/Ghostty.app" ]]; then
    GHOSTTY_SRC="$GHOSTTY_REPO/zig-out/Ghostty.app"
elif [[ -d "$GHOSTTY_REPO/macos/build/ReleaseLocal/Ghostty.app" ]]; then
    GHOSTTY_SRC="$GHOSTTY_REPO/macos/build/ReleaseLocal/Ghostty.app"
else
    print "错误：找不到 Ghostty.app 构建产物。请先运行：" >&2
    print "  cd ~/Projects/ghostty && /opt/homebrew/bin/zig build -Doptimize=ReleaseFast" >&2
    exit 1
fi

print "使用 Ghostty: $GHOSTTY_SRC"
print "输出 DMG: $OUTPUT"
print ""

# ── [1] 组装暂存目录 ──────────────────────────────────────
print "[1/4] 组装 DMG 内容..."

rm -rf "$STAGING"
mkdir -p "$STAGING/scripts"

# 汉化版 Ghostty
/bin/cp -R "$GHOSTTY_SRC" "$STAGING/Ghostty.app"
print "  ✓ Ghostty.app（$(/usr/bin/du -sh "$STAGING/Ghostty.app" | cut -f1)）"

# 桌面启动器 App
/bin/cp -R "$SCRIPT_DIR/Forge-zh-launcher/Forge-zh.app" "$STAGING/Forge-zh.app"
/bin/chmod +x "$STAGING/Forge-zh.app/Contents/MacOS/Forge-zh"
print "  ✓ Forge-zh.app（桌面启动器）"

# 安装脚本（放在 DMG 根目录，用户直接运行）
/bin/cp "$SCRIPT_DIR/scripts/install.sh" "$STAGING/install.sh"
/bin/chmod +x "$STAGING/install.sh"
print "  ✓ install.sh"

# 配置文件
/bin/cp "$SCRIPT_DIR/scripts/forge-zh-launch.sh" "$STAGING/scripts/"
/bin/cp "$SCRIPT_DIR/scripts/tmux.conf"           "$STAGING/scripts/"
/bin/cp "$SCRIPT_DIR/scripts/tmux-forge-append.conf" "$STAGING/scripts/"
print "  ✓ scripts/（tmux.conf、forge-zh-launch.sh）"

# README
/bin/cp "$SCRIPT_DIR/README.md" "$STAGING/README.md"
print "  ✓ README.md"

# Applications 快捷方式（经典拖拽安装样式）
/bin/ln -s /Applications "$STAGING/Applications"
print "  ✓ Applications → /Applications 快捷方式"

# 图标（如有）
if [[ -f "$SCRIPT_DIR/assets/Forge-zh.icns" ]]; then
    mkdir -p "$STAGING/.assets"
    /bin/cp "$SCRIPT_DIR/assets/Forge-zh.icns" "$STAGING/.assets/"
fi

# ── [2] 计算 DMG 大小 ─────────────────────────────────────
print ""
print "[2/4] 计算 DMG 大小..."

STAGING_SIZE_KB=$(/usr/bin/du -sk "$STAGING" | cut -f1)
# 留 40% 余量 + 固定 100MB（供 Finder 元数据）
DMG_SIZE_MB=$(( (STAGING_SIZE_KB / 1024) * 14 / 10 + 100 ))
print "  暂存目录：$(( STAGING_SIZE_KB / 1024 ))MB → DMG 分配：${DMG_SIZE_MB}MB"

# ── [3] 创建可读写临时 DMG ────────────────────────────────
print ""
print "[3/4] 创建 DMG..."

rm -f "$TEMP_DMG" "$OUTPUT"

/usr/bin/hdiutil create \
    -srcfolder "$STAGING" \
    -volname "Forge-zh ${VERSION}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,b=16" \
    -format UDRW \
    -size "${DMG_SIZE_MB}m" \
    "$TEMP_DMG"

# ── Finder 窗口布局（美化，挂载后设置）────────────────────
MOUNT_DIR=$(/usr/bin/hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" \
    | /usr/bin/grep "/Volumes/" | /usr/bin/tail -1 \
    | /usr/bin/sed 's/.*\(\/Volumes\/.*\)/\1/')

print "  挂载到：$MOUNT_DIR"

# 等待 Finder 识别
sleep 2

/usr/bin/osascript <<APPLESCRIPT
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

/usr/bin/hdiutil detach "$MOUNT_DIR" -quiet

# ── [4] 压缩为只读 DMG ────────────────────────────────────
print ""
print "[4/4] 压缩 DMG..."

/usr/bin/hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$OUTPUT"

rm -f "$TEMP_DMG"

DMG_SIZE=$(/usr/bin/du -sh "$OUTPUT" | cut -f1)
print ""
print "╔════════════════════════════════════════╗"
print "║   DMG 打包完成！                       ║"
print "╠════════════════════════════════════════╣"
print "║  文件：build/$DMG_NAME"
print "║  大小：$DMG_SIZE"
print "╚════════════════════════════════════════╝"
