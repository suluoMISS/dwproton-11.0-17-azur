#!/usr/bin/env bash
# 校验补丁是否在装好的 unix 驱动里
# 用法: scripts/verify.sh <tool-dir>
set -euo pipefail
TOOL=${1:?用法: verify.sh <tool-dir>}
D="$TOOL/files/lib/wine/x86_64-unix"
fail=0

for f in win32u.so winex11.so; do
    [ -f "$D/$f" ] || { echo "缺少 $D/$f" >&2; fail=1; continue; }
    printf '%-12s %10s  %s\n' "$f" "$(stat -c %s "$D/$f")" "$(sha256sum "$D/$f" | cut -d' ' -f1)"
done

grep -aq "keeping app owned panel" "$D/winex11.so" 2>/dev/null \
    && echo "OK  winex11.so 含 0002 (app owned panel 不进入 managed)" \
    || { echo "FAIL winex11.so 不含 0002" >&2; fail=1; }

grep -aq "Converting SetParent" "$D/win32u.so" 2>/dev/null \
    && echo "OK  win32u.so 含 0001 (SetParent -> owner)" \
    || { echo "FAIL win32u.so 不含 0001" >&2; fail=1; }

if grep -aq "azur_poll_input_channel" "$D/win32u.so" 2>/dev/null; then
    echo "注意 win32u.so 含可选的 0003 调试输入通道 (仅 AZUR_INPUT_CHANNEL=1 时生效)"
fi

[ "$fail" -eq 0 ] && echo "校验通过" || { echo "校验失败" >&2; exit 1; }
