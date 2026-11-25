NoTICE / 许可摘要
=================

本仓库（补丁、构建脚本、`dist/` 下的二进制）是 Wine 的衍生作品，按 Wine 的许可发布：
**GNU Lesser General Public License v2.1 or later（LGPL-2.1-or-later）**。

- 完整许可文本：本仓库根目录的 [`LICENSE`](LICENSE)（LGPL-2.1 标准文本，502 行）
  或 <https://www.gnu.org/licenses/old-licenses/lgpl-2.1.txt>
- SPDX-License-Identifier: `LGPL-2.1-or-later`
- 本项目不是 Wine、Proton 或 dwproton 的官方发行版，也未获其背书。

## 对应的源码（LGPL 第 6 条）

`dist/win32u.so` 与 `dist/winex11.so` 是对 dwproton 11.0-17（Wine 11.0）源码打上本仓库
`patches/`（以及可选的 `optional/`）后编译的产物。对应源码 = **dwproton 11.0-17 附带的
Wine 源码树 + 本仓库的补丁**，用 `scripts/build.sh` 可重建出与 `dist/` 逐字节一致的二进制
（`sha256` 见 `dist/SHA256SUMS`）。基础提交号记录在 `README.md` 的「构建」一节。

## 商标 / 游戏相关内容

- 《蓝色星原：旅谣》/ Azur Promilia 及其素材、SDK 的版权归其权利人所有；本仓库只讨论
  Wine 的窗口管理行为，与游戏厂商无任何关联，也不代表其立场。
- 本仓库**不包含**游戏本体、游戏资源、账号数据、日志或截图，也没有修改游戏文件的补丁。
