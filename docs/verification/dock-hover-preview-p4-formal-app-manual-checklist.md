# Dock 悬停窗口预览 P4 正式应用化人工验收清单

日期：2026-07-06

## 状态

P4 正式应用化已进入实现和自动验证阶段；人工验收尚未执行。本文只记录真实执行结果，未执行项保持 `not run`。没有稳定签名证书、公证凭据或多显示器硬件时，相关项标记为 `blocked / not available`，不提前写成通过。

## 自动验证覆盖

- app bundle 身份、版本字段、`build/zongMacTools.app` 路径和 executable 名称。
- ad-hoc fallback、可配置稳定签名身份和 bundle 验证脚本。
- release artifact 输出到 ignored 的 `dist/`。
- AppMetadata、AppStatusSnapshot、About / Status、Copy Status、Export Diagnostics。
- 诊断导出只在用户主动触发后生成本地文件，不自动上传。
- Screen Recording 权限缺失时仍静默抑制预览 UI。

## 最终自动验证记录

- `swift test`：2026-07-06 Asia/Shanghai，180 XCTest，0 failures，exit 0。
- `swift build`：2026-07-06，exit 0。
- `Scripts/build_probe_app.sh`：2026-07-06，exit 0，输出 `/Users/zong/Desktop/Project/zongMacTools/build/zongMacTools.app`，ad-hoc fallback 签名并提示 TCC caveat。
- `Scripts/verify_app_bundle.sh build/zongMacTools.app`：2026-07-06，exit 0，Info.plist、executable、icon、bundle id 和签名摘要通过。
- `Scripts/package_release_app.sh`：2026-07-06，exit 0，输出 `dist/zongMacTools-0.1.0-1/`；`NOTARYTOOL_PROFILE` 未配置，公证跳过。
- `git diff --check`：2026-07-06，exit 0。
- `rg -n "\b(CGS|SLS|AXUIElementSetMessagingTimeout|_AX)\b" Sources Tests`：2026-07-06，无匹配。

## 人工验收清单

| 项目 | 检查内容 | 结果 | 记录 |
| --- | --- | --- | --- |
| [ ] Finder 名称和图标 | 新构建 app 在 Finder 显示 `zongMacTools` 名称和图标。 | not run |  |
| [ ] 系统辅助功能列表 | 系统辅助功能权限列表显示 `zongMacTools` 名称和图标。 | not run |  |
| [ ] Screen Recording 列表 | 屏幕录制权限列表显示 `zongMacTools` 名称和图标。 | not run |  |
| [ ] ad-hoc TCC caveat | ad-hoc 重新构建后的重新授权风险在 README 和脚本输出中清楚。 | not run |  |
| [ ] 稳定签名重复构建 | 使用稳定签名身份重复构建后，权限稳定性较 ad-hoc 改善。 | blocked / not available | 需要 Developer ID 或本机稳定证书。 |
| [ ] Launch at Login | 菜单状态与系统 Login Items 真实状态一致。 | not run |  |
| [ ] About / Status | 窗口显示版本、build、bundle id、bundle path、权限、登录项、签名和设置摘要。 | not run |  |
| [ ] Copy Status | 剪贴板内容可用于排障，且不包含第三方窗口标题或第三方 app 名。 | not run |  |
| [ ] Export Diagnostics | 用户主动保存本地诊断文件；内容包含权限、Dock 订阅、窗口查询、缩略图、激活、签名和 bundle 验证摘要。 | not run |  |
| [ ] 诊断隐私 | 诊断文件不包含截图、缩略图图像、屏幕录制内容或用户文件内容。 | not run |  |
| [ ] Screen Recording 缺失 | 屏幕录制权限缺失时 hover preview UI 仍静默抑制。 | not run |  |
| [ ] release artifact | release zip 可从干净位置安装并启动。 | not run |  |
| [ ] release 工作区清洁 | release 构建后 `git status --short` 不出现 `build/`、`dist/`、dmg、zip 或 notary log。 | not run |  |
| [ ] 多显示器 | 多显示器下 About/诊断和基础预览路径无异常。 | blocked / not available | 当前硬件环境不足。 |

## 记录边界

- 本清单不复制、翻译或机械改写外部项目源码、文件结构、helper、注释或私有接口封装。
- 未人工执行的项目保持 `not run`。
- 证书、Apple ID、team id、notary password 和 keychain profile 不写入仓库或验收记录。
