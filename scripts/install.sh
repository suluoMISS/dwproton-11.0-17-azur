#!/usr/bin/env bash
# 安装到 Proton / dwproton 兼容工具
# 用法: scripts/install.sh <tool-dir>   例如 .../compatibilitytools.d/dwproton-11.0-17
set -euo pipefail
TOOL=${1:?用法: install.sh <tool-dir>}
HERE=$(cd "$(dirname "$0")/.." && pwd)
DEST="$TOOL/files/lib/wine/x86_64-unix"

[ -d "$DEST" ] || { echo "目录不存在: $DEST" >&2; exit 1; }
[ -f "$HERE/dist/win32u.so" ] && [ -f "$HERE/dist/winex11.so" ] || { echo "dist/ 里没有 win32u.so / winex11.so, 先跑 build.sh" >&2; exit 1; }

STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$TOOL/backup-unix-$STAMP"
mkdir -p "$BACKUP"
for f in win32u.so winex11.so; do
    cp -a "$DEST/$f" "$BACKUP/$f"
    chmod u+w "$DEST/$f"
    cp -a "$HERE/dist/$f" "$DEST/$f"
    chmod 555 "$DEST/$f"
    echo "已安装 $f (原文件备份到 $BACKUP/)"
done
"$HERE/scripts/verify.sh" "$TOOL"
echo
echo "提示: 这是《蓝色星原：旅谣》的临时兼容补丁版, 仅用于临时运行;"
echo "      官方 dwproton 修复后请改回官方版本 (备份在 $BACKUP/)。"
