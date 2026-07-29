# Dock 悬停窗口预览后续路线清单

日期：2026-07-01

## 当前原则

- 先稳定，再扩功能。
- 不使用私有 API。
- 不复制 DockDoor GPLv3 源码，只参考交互和 API 策略。
- 屏幕录制权限缺失时继续静默抑制预览 UI。
- stale hover cancellation 始终是一等状态。
- 每个新功能都要有自动测试或明确的人工验证记录。

## P0：环境变体验证和稳定性修复

目标：把 MVP 从“普通环境可用”推进到“常见 macOS 环境可稳定自用”。

- [x] Other normal Space。
- [x] Full-screen Space。
- [x] Dock auto-hide。
- [x] Dock on left。
- [x] Dock on right。
- [x] Stage Manager。
- [ ] Multiple displays。当前环境仅 1 个显示器，结果记录为 blocked / not available，接入多显示器硬件后复验。
- [x] 将每个环境变体的结果写入验证总结和环境变体验证记录。
- [x] 对验证中发现的 bug 单独补测试并修复。

验收标准：

- 可执行环境都有 pass / pass with note / fail / blocked 结论。
- 不出现 stuck panel。
- 不出现过期 hover 弹出。
- 不出现权限缺失时的打扰弹窗。

## P1：基础设置能力

目标：让工具变成长期自用时可调、可控、不打扰。

- [x] 菜单栏增加 Enable / Disable Dock hover preview。
- [x] 支持 hover delay 设置：例如 150 ms、250 ms、400 ms。
- [x] 支持 panel hide / retention 手感设置。
- [x] 支持最大卡片数设置，默认 8。
- [x] 支持 excluded apps，不对指定 app 显示 preview。
- [x] 支持 Launch at Login。
- [x] 支持应用自身显示语言切换：English / 简体中文。只切换本工具静态 UI 文案，不翻译 app 名称、窗口标题、bundle id、系统权限名称或系统设置页面名称。
- [x] 设置持久化到 `UserDefaults`。

状态：2026-07-02 已完成实现、自动验证和人工验证。

验收标准：

- 设置变更即时生效或明确要求重启。
- 默认值保持当前 MVP 行为。
- 设置错误不会导致 hover preview 崩溃或卡住。

## P2：UI polish

目标：让预览面板更像成熟 macOS 小工具。

- [x] 缩略图显示模式：保持比例 / 裁切填满。
- [x] 改善窄窗口缩略图展示。
- [x] 增加轻量显示/隐藏动画，并尊重减少动态效果设置。
- [x] 优化 loading 和 placeholder 状态。
- [x] 优化多窗口标题截断和卡片宽度。
- [x] 复查浅色/深色外观下的材质、边框和阴影。

状态：2026-07-03 已完成实现、自动验证和人工视觉验证；人工验证由用户反馈正常。

验收标准：

- UI 不遮挡文字或缩略图。
- 卡片尺寸稳定，缩略图加载不造成布局跳动。
- 浅色/深色外观都可读。

## P3：窗口操作增强

目标：在 preview 基础上增加少量高价值窗口操作。

历史实施计划：`docs/archive/plans/dock-hover-preview-p3-window-actions-development-plan.md`。

- [x] 卡片右键菜单：Activate。
- [x] 卡片右键菜单：Hide App。
- [x] 评估并实现 Close Window。
- [x] 评估并实现 Minimize Window。
- [x] 显示窗口所在屏幕或当前可交互环境提示。

状态：2026-07-06 已完成实现和自动验证；人工验收待执行，清单见 `docs/verification/dock-hover-preview-p3-window-actions-manual-checklist.md`。

验收标准：

- 所有窗口操作都必须使用公开 API。
- 操作失败时安静降级并记录日志。
- 不影响基础 hover preview 的稳定性。

## P4：正式应用化

目标：减少本地运行摩擦，形成可长期维护的 release 流程。

历史实施计划：`docs/archive/plans/dock-hover-preview-p4-formal-app-development-plan.md`

- [x] 使用可配置稳定签名身份，保留 ad-hoc fallback，并提示 TCC caveat。
- [x] 维护版本号规则和 release notes。
- [x] 增加诊断日志导出。
- [x] 增加 app 内 About / 状态信息。
- [x] 评估 Sparkle 自动更新或轻量本地更新流程；P4 默认采用轻量本地更新。
- [x] 整理 release build 脚本。

状态：2026-07-06 已完成实现和自动验证；最终自动验证和人工验收记录见 `docs/verification/dock-hover-preview-p4-formal-app-manual-checklist.md`。人工验收尚未执行，不写成通过。

验收标准：

- 普通本地安装流程清晰。
- 诊断信息足够定位权限、Dock 订阅、窗口查询、缩略图和激活问题。
- release 构建不会污染 git 工作区。

## 当前待验收

- Desktop Window Peek implementation and automated verification are complete. Single-display manual validation is currently blocked because the local Mac session was locked during the validation attempt; see `docs/verification/dock-window-desktop-peek-manual-checklist.md`. Multiple-display validation remains `blocked / not available` until compatible hardware is connected.
- P3 窗口操作真实 app 人工验收。
- P4 正式应用化人工验收，包括 release artifact、TCC、关于与状态和诊断导出。
- 多工具设置窗口人工 smoke test。
- 接入可用硬件后的 Multiple displays 验证。

## 暂不计划

- 实时视频缩略图。
- Cmd+Tab 替代。
- 搜索窗口。
- 跨 Space 主动拉起窗口。
- 私有 API 的窗口管理能力。
- App Store 分发。
