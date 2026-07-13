# GitHub Draft Release Automation Design

日期：2026-07-13

## Goal

在推送正式版本标签后，GitHub Actions 自动在 macOS runner 上测试、打包当前 ad-hoc public beta，并创建包含下载文件的 GitHub Draft Release。维护者检查 Draft 的资产和安装行为后，才在 GitHub UI 中发布。

## Scope

- 标签格式为 `v<version>`，例如 `v0.1.0`。
- 标签版本必须与 `Sources/DockHoverPreviewProbe/Info.plist` 的 `CFBundleShortVersionString` 完全一致。
- 工作流在固定的 `macos-14` runner 上运行 `swift test`、`Scripts/package_release_app.sh` 和产物检查。
- Draft Release 仅上传 ZIP、SHA-256、release metadata、安装说明和 changelog；不上传 `.app` 目录或整个 `dist/`。
- 使用内置 `GITHUB_TOKEN` 与最小 `contents: write` 权限创建 Draft Release。

## Out Of Scope

- Developer ID 签名、Apple 公证、票据装订和凭据管理。
- 自动发布正式 Release、自动更新、网站上传或 GitHub Pages。
- 多架构 universal app 打包。首版产物的架构由固定 runner 决定，发布前由维护者在 Draft 验收中确认目标设备兼容性。
- 自动执行需要 GUI、TCC 或多显示器硬件的人工验收。

## Workflow

```text
push v0.1.0
  -> validate tag matches Info.plist version
  -> swift test
  -> package_release_app.sh (ad-hoc, no notarization profile)
  -> verify required artifacts and checksum
  -> gh release create --draft
  -> maintainer reviews assets and publishes manually
```

### Trigger And Concurrency

工作流只监听 `v*` 标签 push，并以标签名作为 concurrency group。相同标签不允许并发发布，重复运行不会覆盖已存在的 Draft；创建 Release 已存在时应失败并要求维护者明确处理。

### Build And Validation

工作流 checkout 标签指向的 commit，读取 `CFBundleShortVersionString` 和 `CFBundleVersion`，并拒绝版本不匹配的标签。测试成功后调用既有 packaging 脚本，显式保持 `NOTARYTOOL_PROFILE` 为空，避免无意走公证路径。

打包后必须检查以下文件存在且 SHA-256 校验行引用实际 ZIP：

- `zongMacTools-<version>-<build>.zip`
- `SHA256SUMS.txt`
- `release-metadata.txt`
- `README-install.txt`
- `CHANGELOG.md`

### Release Creation

工作流通过 `gh release create <tag> --draft --generate-notes` 创建 Draft，并上传上述五个文件。release title 使用 `zongMacTools <tag>`。Draft 不是面向公众的发布物；维护者需下载资产、检查 checksum、在干净用户环境安装与验证后，才手动发布或标记为 prerelease。

## Security And Failure Handling

- 不使用 Personal Access Token、Apple ID、签名身份或 notary credentials。
- `permissions` 只授予 `contents: write`，用于创建 Release 和上传资产。
- 任一步失败即停止，Release 创建放在所有验证之后，因此测试、打包或资产检查失败时不会创建 Draft。
- 当前产物是 ad-hoc 签名且未公证；Draft/发布说明继续标注为 public beta，不宣称通过 Gatekeeper 验证。

## Verification

- 对 workflow YAML 增加静态测试，断言 tag trigger、`macos-14`、`contents: write`、测试、packaging、tag/version guard、Draft flag 和资产名单存在。
- 本地运行 `swift test` 与 `git diff --check`。
- 首次推送测试标签后，在 GitHub Actions 页面确认 Draft 创建，再手动检查 Release 资产和安装流程。
