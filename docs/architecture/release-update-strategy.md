# Release And Update Strategy

日期：2026-07-06

## 结论

P4 不直接引入 Sparkle。当前优先完成本地签名、`zip` artifact、checksum、release metadata、changelog 和人工安装流程。当前脚本可生成 ad-hoc 或配置身份签名的本地测试包，但不能把它表述为已公证的正式发行物。等 release cadence、下载托管、签名证书和回滚流程稳定后，再单独做 Sparkle P5/P4.5 计划。

## 方案比较

### Sparkle 自动更新

优点：

- 用户体验更接近正式 macOS 应用。
- 可展示版本说明、下载更新并替换应用。
- 支持签名更新 feed 和更完整的更新安全模型。

成本和前置条件：

- 需要稳定签名身份和可验证的 release artifact。
- 需要维护 appcast feed、ed25519 key、下载托管和版本检查 UI。
- 需要额外依赖、许可证审查和回滚策略。
- 需要在真实机器上验证 Gatekeeper、TCC、登录项和更新替换后的权限行为。

### 轻量本地更新

流程：

- 使用 `Scripts/package_release_app.sh` 生成 `dist/zongMacTools-<version>-<build>/`。
- 校验 `SHA256SUMS.txt` 和 `release-metadata.txt`。
- 手动把 `zongMacTools.app` 替换到 `/Applications` 或个人固定安装目录。
- 首次安装或签名身份变化后，按 README 重新确认系统辅助功能和屏幕录制权限。
- 即使设置 `NOTARYTOOL_PROFILE`，现有脚本也只提交并等待公证结果，不装订票据或重新生成 ZIP/checksum；该分支不能替代正式发布验证。

优点：

- 不新增运行时依赖。
- 适合当前自用和少量本地 release。
- 所有产物都在 ignored 的 `dist/` 下，不污染 git 工作区。

限制：

- 没有自动更新提醒。
- 用户需要手动替换 app。
- 稳定签名可以减少 TCC 摩擦，但不能保证所有 macOS 版本都不需要重新授权。

## 后续触发条件

满足以下条件后再评估 Sparkle：

- Developer ID signing 和 notarization 流程稳定。
- release artifact 有固定托管位置。
- changelog、checksum、回滚和故障恢复流程稳定。
- P4 人工验收中安装、TCC、登录项和诊断导出路径完成记录。
