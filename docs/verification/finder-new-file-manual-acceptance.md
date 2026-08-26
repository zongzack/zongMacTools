# Finder 新建文件人工验收清单

本清单对应 `.scratch/finder-new-file/issues/04-build-signing-and-acceptance.md`。自动测试和 bundle 校验不能替代真实 Finder、沙盒和 WPS/Office 验收；每次 ad-hoc 替换应用后，应在本文件副本中重新记录结果。

## 固定环境

- 应用副本：`/Applications/zongMacTools.app`（保持唯一稳定副本）
- macOS 版本：
- CPU 架构：
- WPS/Office 名称及完整版本/build：
- 构建产物 SHA-256：
- 验收日期：
- 验收人：

## 安装和启用

1. 使用 `Scripts/package_release_app.sh` 生成的同一 `zongMacTools.app`，将它安装到 `/Applications`；不要并行保留第二个同名副本。
2. 在“系统设置 -> 隐私与安全性 -> 扩展 -> Finder”中手动启用 `zongMacTools` Finder Sync 扩展。只使用主程序设置页的“管理 Finder 扩展”入口进入系统界面；不运行 `pluginkit`，不自动重启 Finder，也不关闭系统安全功能。
3. 在主程序设置页重新打开页面，确认状态显示“已启用”；停用后重新激活窗口，确认刷新为“未启用”，再恢复启用并确认回到“已启用”。
4. 记录系统报告中的扩展标识、扩展点和沙盒 entitlement；ad-hoc 替换应用后若系统要求重新启用，记录为预期平台行为。

## Finder 生命周期和菜单范围

| 场景 | 预期结果 | 结果/备注 |
| --- | --- | --- |
| Finder 普通项目目录空白处 | 显示“新建文件”，含六种格式 | |
| 桌面空白处 | 显示“新建文件”，含六种格式 | |
| 选中文件 | 不显示产品菜单 | |
| 选中文件夹 | 不显示产品菜单 | |
| 多选项目 | 不显示产品菜单 | |
| 侧边栏项目 | 不显示产品菜单 | |
| Finder 工具栏菜单 | 不显示产品菜单 | |
| 最近使用/搜索等虚拟位置 | 不显示产品菜单 | |
| 退出 zongMacTools 主程序后 | Finder 菜单仍可用 | |

## 六种文件创建和打开

在桌面和一个普通项目目录各执行一次；每个文件都确认创建后 Finder 选中新文件且没有额外窗口，成功时没有通知。

| 菜单项 | 文件扩展名 | 预期内容/结构 | Finder 选中 | WPS/Office 打开、编辑、保存、关闭、重开 |
| --- | --- | --- | --- | --- |
| TXT | `.txt` | 零字节 | | |
| Markdown | `.md` | 零字节 | | |
| JSON | `.json` | UTF-8 `{}\n`，标准 JSON 可解析 | | |
| Word | `.docx` | 合法空白 OOXML 文档 | | |
| Excel | `.xlsx` | 空白 `Sheet1` 工作表 | | |
| PowerPoint | `.pptx` | 一张空白幻灯片 | | |

分别在简体中文和非简体中文环境（或切换系统语言后重新登录）确认默认名称为 `新建文稿.ext` / `New Document.ext`。连续创建同一格式，确认使用 ` 2`、` 3` 等后缀且不覆盖已有文件；如需验证上限，使用自动化测试覆盖第 10,000 个候选，不在真实主目录批量制造文件。

## 失败和边界

对符号链接目录、垃圾篓、云盘/文件提供程序目录、只读目录、其他挂载卷和虚拟位置分别尝试显式动作：菜单应隐藏或动作失败并只显示一次说明原因的错误；不得留下最终半成品或扩展临时文件，也不得修改已有文件。记录错误文本和相关系统日志。

## 交付记录

- `swift test`：
- `swift build`：
- `Scripts/build_probe_app.sh`：
- `Scripts/verify_app_bundle.sh build/zongMacTools.app`：
- `Scripts/package_release_app.sh` 及解压归档复验：
- `git diff --check`：
- 结论：`pass` / `fail` / `blocked`（逐项说明）
