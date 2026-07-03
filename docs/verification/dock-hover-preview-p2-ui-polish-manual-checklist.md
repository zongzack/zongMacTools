# Dock Hover Preview P2 UI Polish Manual Checklist

日期：2026-07-02

最近更新：2026-07-02

## 状态

P2 UI polish 自动验证已完成；人工视觉验证尚未运行。本文只记录真实执行结果，未执行项保持 `not run`，不声明 manual UI pass。

## 自动验证记录

| 验证项 | 时间 | 结果 | 证据 |
| --- | --- | --- | --- |
| `swift test` | 2026-07-03 13:31:05 Asia/Shanghai | pass, exit 0 | 130 XCTest，0 failures。 |
| `swift build` | 2026-07-03 | pass, exit 0 | 构建通过。 |
| `Scripts/build_probe_app.sh` | 2026-07-03 | pass, exit 0 | 输出 `/Users/zong/Desktop/Project/zongMacTools/build/zongMacTools.app`，Info.plist OK，替换 existing signature。 |
| `git diff --check` | 2026-07-03 | pass, exit 0 | 文档更新后运行，无 whitespace error。 |

## 自动验证覆盖

- fit/fill render plan：`.fill` 与 `.fit` 进入不同渲染分支。
- 窄窗口策略：默认 fill 下，窄窗口使用 fit，宽窗口保持 fill。
- loading/unavailable placeholder：thumbnail nil 更新后停止 loading，并进入 unavailable 分支。
- 本地化 unavailable 文案：English 使用 `No thumbnail`，简体中文使用 `无缩略图`。
- show/hide animation：show 与 hide 走 animation path；update 不重复触发 show animation。
- Reduce Motion：打开时 show/hide 走降级路径。
- Light / Dark visual token：panel border、shadow、placeholder surface、hover state 有基础约束。
- Screen Recording denied 自动路径：保持不 show panel。

## Manual-Only Checklist

| 项目 | 检查内容 | 结果 | 记录 |
| --- | --- | --- | --- |
| [ ] Bottom Dock | 普通底部 Dock 下 hover 多个 app，观察 panel 位置、fit/fill、loading/unavailable、show/hide animation 和 quick stale cancellation。 | not run |  |
| [ ] Left / Right Dock | 左侧和右侧 Dock 下 hover 多窗口 app，观察 side Dock 纵向卡片、panel 不越界、Dock-to-panel 保留和离开隐藏。 | not run |  |
| [ ] Dock Auto-Hide | 开启 Dock auto-hide 后 hover、离开、再次 hover，观察 reveal edge 与 stale cancellation。 | not run |  |
| [ ] Stage Manager | 开启 Stage Manager 后 hover 有窗口 app，观察 AX fallback placeholder、panel 位置、点击激活和离开隐藏。 | not run |  |
| [ ] Light / Dark | 分别切换 Light 和 Dark，观察 panel material、border、shadow、title、hover state、loading 和 unavailable placeholder。 | not run |  |
| [ ] Reduce Motion | 分别开启和关闭 Reduce Motion，观察 show/hide 动画降级、隐藏时命中区域和 stale hide。 | not run |  |
| [ ] Typora Narrow Window | 使用 Typora 或同类窄窗口，观察 thumbnail 使用 fit、容器尺寸稳定、标题不遮挡缩略图。 | not run |  |
| [ ] Multi-Window App | 使用 VS Code / WPS 等多窗口 app，观察多卡片列表、横向/纵向滚动、标题截断和点击激活。 | not run |  |
| [ ] Screen Recording Denied | 撤销 Screen Recording 后 hover Dock app，观察 preview UI 静默抑制，不显示 loading、placeholder 或弹窗。 | not run |  |
| [ ] Quick Stale | 快速 hover 后离开、横移到相邻未启动 Dock app、hide 动画未完成时重新 hover，观察旧 panel 不残留。 | not run |  |

## 受限项

- Multiple displays：当前硬件环境不可用，验证状态沿用 `blocked / not available`。

## 记录边界

- 本清单不复制、翻译或机械改写外部项目源码、文件结构、helper、注释或私有 API wrapper。
- 未人工执行的项目保持 `not run`。
