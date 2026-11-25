#!/usr/bin/env bash
# 从 wine 源码构建补丁版 win32u.so / winex11.so
# 用法: scripts/build.sh <wine-src> <build-dir> <out-dir>
set -euo pipefail

SRC=${1:?用法: build.sh <wine-src> <build-dir> <out-dir>}
BUILD=${2:?用法: build.sh <wine-src> <build-dir> <out-dir>}
OUT=${3:?用法: build.sh <wine-src> <build-dir> <out-dir>}
HERE=$(cd "$(dirname "$0")/.." && pwd)

[ -f "$SRC/dlls/win32u/message.c" ] || { echo "不是 wine 源码树: $SRC" >&2; exit 1; }
mkdir -p "$BUILD" "$OUT"

apply_patch() {
    local p=$1
    if git -C "$SRC" apply --check "$p" >/dev/null 2>&1; then
        git -C "$SRC" apply "$p"; echo "已应用 $(basename "$p")"
    elif git -C "$SRC" apply --check --reverse "$p" >/dev/null 2>&1; then
        echo "已是补丁状态, 跳过 $(basename "$p")"
    else
        echo "补丁无法应用(冲突?): $p" >&2; exit 1
    fi
}

apply_patch "$HERE/patches/0001-win32u-owner-conversion-for-setparent.patch"
apply_patch "$HERE/patches/0002-winex11.drv-keep-app-panels-unmanaged.patch"

if [ ! -f "$BUILD/Makefile" ]; then
    echo "配置 $BUILD ..."
    ( cd "$BUILD" && "$SRC/configure" \
        --enable-win64 --without-mingw --disable-tests \
        --with-x --without-wayland --without-alsa --without-pulse --without-gstreamer \
        --without-ffmpeg --without-cups --without-dbus --without-gnutls --without-krb5 \
        --without-netapi --without-pcap --without-pcsclite --without-sane --without-sdl \
        --without-udev --without-unwind --without-usb --without-v4l2 --without-oss \
        --without-capi --without-gphoto --without-opencl )
fi

echo "编译 ..."
make -C "$BUILD/dlls/win32u" -j"$(nproc)" all
make -C "$BUILD/dlls/winex11.drv" -j"$(nproc)" all

cp -a "$BUILD/dlls/win32u/win32u.so" "$OUT/win32u.so"
cp -a "$BUILD/dlls/winex11.drv/winex11.so" "$OUT/winex11.so"
strip --strip-debug "$OUT/win32u.so" "$OUT/winex11.so" 2>/dev/null || true
( cd "$OUT" && sha256sum win32u.so winex11.so )
echo "完成: $OUT"
