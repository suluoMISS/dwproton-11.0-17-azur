# 《蓝色星原：旅谣》临时兼容修复版 —— dwproton / Wine 补丁集

## ⚠️ 仅用于临时运行：官方 dwproton 修复后请移步官方版本

这是 **《蓝色星原：旅谣》（Azur Promilia）** 在 Linux（dwproton / Wine + Proton 兼容层）
上运行时使用的**临时过渡补丁**，只修改 **Wine**（基于 dwproton 11.0-17 / Wine 11.0），
不修改游戏本体任何文件。

- 适用游戏：《蓝色星原：旅谣》/ Azur Promilia（Windows 客户端，启动器 + 游戏同目录结构）
- 适用环境：dwproton 11.0-17（Wine 11.0）的 Proton 兼容工具
- 性质：**临时兼容补丁，仅用于个人在本机临时运行该游戏**
- 何时停用：一旦 **dwproton 官方版本**（或 Wine 上游）合入了等价的窗口管理修复，
  或游戏自身不再触发这两个问题，**请立刻改回官方 dwproton、不要再使用本补丁版本**。
  本补丁版本不是官方发行版，不提供任何官方支持，也不为该游戏提供游戏本体/资源/破解。
- 本仓库不包含：游戏本体、游戏资源、账号数据、启动器或游戏文件修改、注入游戏的 DLL。

上游背景：dwproton/Proton 尚未合并这类 `SetParent` 分层窗口问题（Windows 下正常，
Wine 下会出现弹窗黑屏 / 弹窗被压回初始尺寸），所以先做临时补丁等上游修复。

## 两个问题

### 1. `SetParent` 到 Unity 窗口后，ARGB 弹窗黑屏 / 不显示

游戏 SDK 的窗口是「`WS_POPUP` + `WS_EX_LAYERED|WS_EX_TOOLWINDOW` + `UpdateLayeredWindow`」
的 Qt 弹出窗口，创建后调用：

```c
SetParent( (HWND)winId(), unity_hwnd );   // 把这个 ARGB 窗口挂到 Unity 主窗口下
```

（以下分析针对《蓝色星原：旅谣》SDK 的 `mj_base::MjBaseWnd` 窗口。）

在 Wine 里，`X11DRV_SetParent` 会把「桌面顶层窗口变成子窗口」这条路径走成
`destroy_whole_window()` —— 32 位 ARGB 的 X window 被销毁重建，于是
`UpdateLayeredWindow` 失败（BadDrawable / BadWindow），弹窗内容永远是黑的/看不见。

**补丁 0001**（`patches/0001-win32u-owner-conversion-for-setparent.patch`，仅 `dlls/win32u`）：
在 `NtUserSetParent` 里识别这种窗口（桌面顶层 + `WS_EX_LAYERED|WS_EX_TOOLWINDOW` + 目标是
`UnityWndClass`），把「设置父窗口」转换为「设置 owner（`set_window_owner`）」，并返回桌面窗口，
即不触发子窗口路径，ARGB X window 得以保留；同时在 `set_window_long(GWLP_HWNDPARENT, 0)`
时保留已有 owner（Qt 5 在 `show()` 前会把 parent 清 0，否则 `WM_TRANSIENT_FOR` 丢失）。

### 2. 全屏 SDK 面板被压回 641x480，内容被裁切

问题 1 修好后，弹窗能画出来了，但会被合成器（WM）按「创建时的几何 + 尺寸提示」重新配置：

```
创建: (960,560) 640x480  →  MoveWindow(0,0,2560,1600)  →  WM 应用 min=max=641,480 提示
     → Wine 采纳 WM 的配置 → 面板变回 641x480，而 Qt 内部仍按 1160 宽排版 ⇒ 右侧被裁切
```

根因：这类面板在 `X11DRV_WindowPosChanged` 的「全屏 transition」被判定为 managed
（`is_window_managed()` 对 `WS_POPUP` + fullscreen 返回 TRUE），一旦 managed，
WM 就按创建几何/`WM_NORMAL_HINTS` 摆它，Wine 再通过 `window_update_client_config()`
把 WM 的几何采纳回 Win32 窗口。

**补丁 0002**（`patches/0002-winex11.drv-keep-app-panels-unmanaged.patch`，仅 `dlls/winex11.drv`）：
新增 `is_app_owned_panel()`（`WS_POPUP` + `WS_EX_LAYERED|WS_EX_TOOLWINDOW` + owner 是
`UnityWndClass`），在 `X11DRV_WindowPosChanged()` 里让这类窗口**永远不进入 managed**
（保持 override-redirect，创建时的 unmanaged 状态），WM 不再干预几何，面板以
2560x1600 ARGB 全屏显示且内容完整。

### 可选：自动化输入通道（**仅调试用**）

`optional/0003-win32u-azur-input-channel.patch`：在 `NtUserPeekMessage` 里轮询
`/tmp/azur_input.txt`，用 `NtUserSendInput` 注入鼠标/键盘事件（`AZUR_INPUT_CHANNEL=1` 时才启用）。
用于在合成器会缩放窗口的桌面上做无人值守测试（X11 的 XTest/XSendEvent 到不了 Wine 窗口）。
**普通游玩不需要它，默认不启用，也不会被启用。**

## 构建

依赖：`gcc`、`make`、`pkg-config`、X11 开发库（x11、xext、xrender、xfixes、xcursor、xi、
xrandr、xinerama、xcomposite、x11-xcb、xkbcommon）、`libxml-2.0`、`freetype2`、`fontconfig`。

```sh
# 1) 取 Wine 源码：dwproton 11.0-17 发布包里自带的 wine 源码目录
#    （基础提交 a45ed99；上游 Wine 见 https://gitlab.winehq.org/wine/wine）
# 2) 打补丁
cd wine-src
git apply /path/to/patches/0001-win32u-owner-conversion-for-setparent.patch
git apply /path/to/patches/0002-winex11.drv-keep-app-panels-unmanaged.patch
#    可选：git apply /path/to/optional/0003-win32u-azur-input-channel.patch
# 3) 构建（out-of-tree 也可以）
mkdir build && cd build
../configure --enable-win64 --without-mingw --disable-tests \
    --with-x --without-wayland --without-alsa --without-pulse --without-gstreamer \
    --without-ffmpeg --without-cups --without-dbus --without-gnutls --without-krb5 \
    --without-netapi --without-pcap --without-pcsclite --without-sane --without-sdl \
    --without-udev --without-unwind --without-usb --without-v4l2 --without-oss \
    --without-capi --without-gphoto --without-opencl
make -C dlls/win32u -j"$(nproc)"
make -C dlls/winex11.drv -j"$(nproc)"
```

或者直接用 `scripts/build.sh`：

```sh
scripts/build.sh /path/to/wine-src /path/to/build-dir /path/to/out
```

`out/` 里会得到 `win32u.so` 和 `winex11.so`（已 `strip --strip-debug`，本仓库 `dist/` 里的
就是这对文件，`SHA256SUMS` 可用于校验）。

## 安装（Proton / dwproton 兼容工具）

预编译二进制见 [Releases](https://github.com/suluoMISS/dwproton-11.0-17-azur/releases/latest)
（`win32u.so` + `winex11.so` + `SHA256SUMS`，附补丁与脚本的 tar.gz）。

```sh
scripts/install.sh /path/to/compatibilitytools.d/dwproton-11.0-17
```

脚本会把两个 `.so` 复制到 `<tool>/files/lib/wine/x86_64-unix/`，原文件备份到
`<tool>/backup-unix-<时间戳>/`，复制后 `chmod 555`（Proton 的库文件是只读的）。
也可以手动：

```sh
D=<tool>/files/lib/wine/x86_64-unix
chmod u+w "$D/win32u.so" "$D/winex11.so"
cp dist/win32u.so dist/winex11.so "$D"/
chmod 555 "$D/win32u.so" "$D/winex11.so"
```

注意：只需要替换 `x86_64-unix/` 下的这两个 `ELF .so`；`x86_64-windows/` 下的 PE 驱动不用动
（这套补丁全部在 Unix 侧）。

## 验证

```sh
scripts/verify.sh /path/to/compatibilitytools.d/dwproton-11.0-17
```

另外可以启动游戏后看窗口：修复生效时，SDK 面板窗口应为
`abs=(0,0) size=2560x1600 depth=32 override_redirect=1`（2560x1600 的屏幕），
而不是 `(960,560) 641x480`。没有 `xwininfo` 的环境可以用 `tools/xinfo.py`（）或
`xprop` 检查。

## 这个补丁只解决《蓝色星原：旅谣》的问题吗

补丁的判定条件很窄：只有「桌面顶层 + `WS_POPUP` + `WS_EX_LAYERED|WS_EX_TOOLWINDOW`
+ owner 是 `UnityWndClass`」这种窗口才会被特殊对待，因此对其它游戏一般无影响。
但**它仍然是临时方案**：正确的做法是等 dwproton/Wine 上游修复后，回到官方版本。

## 分辨率无关

补丁本身没有任何分辨率假设，面板尺寸完全跟随游戏（Unity）窗口：

```
Unity 窗口任意尺寸 (W x H)
  → SDK 调用 MoveWindow/UpdateLayeredWindow 把面板设成 W x H
  → 本补丁保证该面板不被 WM 改回创建时的 640x480
```

也就是说 2560x1600、1920x1080、1280x720、乃至窗口化运行都走同一套逻辑；
补丁里没有任何写死的宽度/高度（只判断窗口样式、扩展样式和 owner 窗口类名）。
窗口化的游戏窗口不会被强行拉伸。

配套脚本（watchdog、点击定位）同样不写死分辨率：

- 屏幕尺寸从 root 窗口读取，点击坐标按 `窗口实际位置 + 窗口宽高 × 比例` 计算；
- 游戏窗口识别用「名字含 `AzurPromilia` 的 mapped 窗口里面积最大的一个」，不要求接近全屏；
- 启动器窗口识别用「顶层、depth 32、无窗口名的 mapped 窗口」，按屏幕比例过滤；
- 只有窗口自身尺寸比例（启动器按钮 80.3%/89.1%、更新对话框"确定" 66.0%/60.7%）是常量，
  这几个比例与分辨率无关。

> 验证记录：2560x1600 全屏下协议面板 = `(0,0) 2560x1600 depth 32` 且完整可点；
> 1280x720 窗口化下游戏窗口 = `1280x720`（面板机制同上，尺寸=窗口尺寸）。

## 已验证环境

- Wine 11.0（dwproton 11.0-17 的 wine 源码，基础提交 `a45ed99`，补丁 0001 等价于 `549f652`）
- 构建：GCC 14，x86_64，`--enable-win64 --without-mingw`
- 运行：Proton 兼容工具（dwproton 11.0-17）+ DXVK 3.1.1-198 + Wayland 合成器（Smithay XWM）
- 面板：`WS_POPUP` 640x480 → `MoveWindow(0,0,2560,1600)` → 不再被 WM 压回

## 说明与边界

- 补丁只改 Wine 的窗口管理逻辑，**不改游戏文件**，也不注入游戏进程。
- 0001 的判定条件依赖窗口类名 `UnityWndClass`（Unity 播放器的窗口类）；同理这套补丁对
  「Qt 分层工具弹窗 + Unity 宿主」的其它游戏也适用。
- `optional/0003` 是调试工具：启用后本机任意进程都可以通过 `/tmp/azur_input.txt` 向游戏
  注入输入，**生产环境不要打这个补丁**。
- 本仓库不含任何游戏资源、账号数据、日志或截图；构建产物只包含 Wine 的机器码。
- **《蓝色星原：旅谣》/ Azur Promilia 的名称与相关素材版权归其权利人所有**；本仓库
  仅讨论 Wine 的窗口管理行为，与游戏厂商无关联，也不代表任何官方立场。

## 许可

补丁与构建产物都是 Wine 的衍生作品，按 Wine 的许可发布：**LGPL-2.1-or-later**。

- 许可摘要与免责声明：`NOTICE.md`
- **完整许可文本：`LICENSE`**（LGPL-2.1 标准文本，与 Wine 源码树中的 `COPYING.LIB` 一致）
- 对应源码：dwproton 11.0-17 的 Wine 源码 + 本仓库 `patches/`，用 `scripts/build.sh`
  可重建出与 `dist/` 完全相同的二进制（`sha256` 见 `dist/SHA256SUMS`）。
