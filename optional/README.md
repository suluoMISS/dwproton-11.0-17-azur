# 可选补丁 0003：调试用输入通道（默认不启用）

作用：在 `NtUserPeekMessage` 里每 16 次调用轮询一次 `/tmp/azur_input.txt`，按行执行

```
move X Y       # NtUserSetCursorPos
click X Y      # SetCursorPos + NtUserSendInput(鼠标左键按下/抬起)
text STRING    # 逐字节 KEYEVENTF_UNICODE 键盘输入
```

然后删除该文件。**只有环境变量 `AZUR_INPUT_CHANNEL=1` 时才生效**。

为什么需要它：某些 Wayland 合成器（例如会缩放/平铺窗口的合成器）下，X11 层的
`XTestFakeButtonEvent` / `XSendEvent` 到不了 Wine 窗口（显示的几何 ≠ X 几何），
做无人值守自动化测试时需要一条不依赖合成器的注入通道。走 Wine 自己的输入队列
（`NtUserSendInput`）就绕开了这个问题。

安全提示：启用后本机任何能写 `/tmp/azur_input.txt` 的进程都可以向游戏注入输入。
**不要在正常游玩/发布版本里打这个补丁**；`dist/` 里的二进制包含了它，仅为方便
复现自动化测试流程。
