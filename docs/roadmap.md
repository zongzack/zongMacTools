# Dock 悬停窗口预览后续路线清单

日期：2026-07-01

## 当前原则

- 先稳定，再扩功能。
- 不使用私有 API，除非后续单独评估并明确接受风险。
- 不复制 DockDoor GPLv3 源码，只参考交互和 API 策略。
- Screen Recording 缺失时继续静默抑制 preview UI。
- stale hover cancellation 始终是一等状态。
- 每个新功能都要有自动测试或明确的人工验证记录。

## P0：环境变体验证和稳定性修复

目标：把 MVP 从“普通环境可用”推进到“常见 macOS 环境可稳定自用”。

- [x] Other normal Space。
- [x] Full-screen Space。
- [x] Dock auto-hide。
- [x] Dock on left。
- [x] Dock on right。
- [ ] Stage Manager。
- [ ] Multiple displays。
- [ ] 将每个环境变体的结果写入 `docs/verification/dock-hover-preview-mvp-ui-manual-checklist.md`。
- [ ] 对验证中发现的 bug 单独补测试并修复。

验收标准：

- 可执行环境都有 pass / pass with note / fail / blocked 结论。
- 不出现 stuck panel。
- 不出现过期 hover 弹出。
- 不出现权限缺失时的打扰弹窗。

## P1：基础设置能力

目标：让工具变成长期自用时可调、可控、不打扰。

- [ ] 菜单栏增加 Enable / Disable Dock hover preview。
- [ ] 支持 hover delay 设置：例如 150 ms、250 ms、400 ms。
- [ ] 支持 panel hide / retention 手感设置。
- [ ] 支持最大卡片数设置，默认 8。
- [ ] 支持 excluded apps，不对指定 app 显示 preview。
- [ ] 支持 Launch at Login。
- [ ] 设置持久化到 `UserDefaults`。

验收标准：

- 设置变更即时生效或明确要求重启。
- 默认值保持当前 MVP 行为。
- 设置错误不会导致 hover preview 崩溃或卡住。

## P2：UI polish

目标：让预览面板更像成熟 macOS 小工具。

- [ ] 缩略图显示模式：保持比例 / 裁切填满。
- [ ] 改善窄窗口缩略图展示。
- [ ] 增加轻量 show / hide 动画，并尊重 Reduce Motion。
- [ ] 优化 loading 和 placeholder 状态。
- [ ] 优化多窗口标题截断和卡片宽度。
- [ ] 复查 Light / Dark 下的材质、边框和阴影。

验收标准：

- UI 不遮挡文字或缩略图。
- 卡片尺寸稳定，缩略图加载不造成布局跳动。
- Light / Dark 外观都可读。

## P3：窗口操作增强

目标：在 preview 基础上增加少量高价值窗口操作。

- [ ] 卡片右键菜单：Activate。
- [ ] 卡片右键菜单：Hide App。
- [ ] 评估并实现 Close Window。
- [ ] 评估并实现 Minimize Window。
- [ ] 显示窗口所在屏幕或当前可交互环境提示。

验收标准：

- 所有窗口操作都必须使用公开 API。
- 操作失败时安静降级并记录日志。
- 不影响基础 hover preview 的稳定性。

## P4：正式应用化

目标：减少本地运行摩擦，形成可长期维护的 release 流程。

- [ ] 使用更稳定的签名方式，减少每次构建后 TCC 重新授权。
- [ ] 维护版本号和 release notes。
- [ ] 增加诊断日志导出。
- [ ] 增加 app 内 About / 状态信息。
- [ ] 评估 Sparkle 自动更新或轻量本地更新流程。
- [ ] 整理 release build 脚本。

验收标准：

- 普通本地安装流程清晰。
- 诊断信息足够定位权限、Dock 订阅、窗口查询、缩略图和激活问题。
- release 构建不会污染 git 工作区。

## 暂不计划

- 实时视频缩略图。
- Cmd+Tab 替代。
- 搜索窗口。
- 跨 Space 主动拉起窗口。
- 私有 API 的窗口管理能力。
- App Store 分发。
