# Finder 新建文件人工验收清单

本清单对应 `.scratch/finder-new-file/issues/12-package-and-accept-configurable-finder-new-file.md`。自动测试和 bundle 校验不能替代真实 Finder、沙盒和 WPS/Office 验收；每次 ad-hoc 替换应用后，应在本文件副本中重新记录结果。

## 固定环境

- 应用副本：`/Applications/zongMacTools.app`（保持唯一稳定副本）
- macOS 版本：
- CPU 架构：
- WPS/Office 名称及完整版本/build：
- 构建产物 SHA-256：
- 验收日期：
- 验收人：
- 扩展启用状态（系统设置 -> 隐私与安全性 -> 扩展 -> Finder）：
- 配置文件路径（预期）：`~/Library/Application Support/com.zong.zongMacTools/FinderNewFile/catalog.json`
- 模板目录路径（预期）：`~/Library/Application Support/com.zong.zongMacTools/FinderNewFile/Templates/`

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

## 可配置目录和模板生命周期

以下操作应在 `/Applications/zongMacTools.app` 的同一稳定副本中完成。每次修改后关闭并重新打开 Finder 背景菜单，确认无需重启主 App 或扩展即可读取最新配置。

| 操作 | 预期结果 | 结果/备注 |
| --- | --- | --- |
| 设置页取消勾选一个内置格式 | 该格式从二级菜单消失，其余启用格式顺序不变 | |
| 设置页双击内置名称并保存 | 菜单使用新名称，后缀仍锁定为原始后缀 | |
| 拖拽内置条目排序 | 下一次打开菜单按新顺序显示，重开设置页顺序保持 | |
| 批量导入多个有后缀普通文件 | 每个文件生成独立条目和副本，重复导入不覆盖旧副本 | |
| 导入无后缀、目录或读取失败项目 | 成功项目保留，失败项目只汇总提示一次并列出原因 | |
| 编辑自定义名称和后缀 | 新名称/后缀用于后续创建，非法值不写入；图标随后缀更新 | |
| 删除自定义条目并确认 | 条目消失且 `Templates/` 中对应副本被删除 | |
| 删除自定义条目后取消确认 | 条目和模板副本均保留 | |
| 恢复默认并确认 | 六种内置格式恢复原始名称、顺序、全选；自定义条目及副本全部删除 | |
| 恢复默认后取消确认 | 配置和模板副本均不改变 | |
| 全部条目取消勾选 | 第一层“新建文件”父入口隐藏 | |
| 重新启用任一条目 | 下一次打开背景菜单立即恢复父入口和该条目 | |

配置/模板跨进程检查：在设置页完成一次导入或改名后退出主 App，确认上述 `catalog.json` 和模板副本仍存在，Finder 扩展仍能创建对应文件；不得把这些路径或文件复制进 `.app/Contents`。删除或恢复默认后再次检查副本已清理。

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

自定义模板至少覆盖 TXT、Markdown 和一种 Office 文件；确认创建结果使用显示名称作为词干、使用当前后缀，并且字节内容与导入副本完全一致。显示名称重复时仍按稳定 ID 创建各自模板，不依赖标题反查。

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
- Dock Window Quick Look 设置导航、诊断导出、窗口预览 smoke test：
- 结论：`pass` / `fail` / `blocked`（逐项说明）

## Ticket 12 自动验证记录（2026-08-30）

- 环境：macOS 26.6.2（25G83），`arm64`；WPS/Office 和真实 Finder 操作未在本次自动化会话中执行。
- 构建：`swift test`（325 项，0 failures）；`swift build`（pass）。
- 打包：`Scripts/build_probe_app.sh`（pass）；`Scripts/verify_app_bundle.sh build/zongMacTools.app`（pass）；主 App 与嵌套 Finder Sync 扩展均为 ad-hoc `arm64` 签名，扩展签名先于主 App，资源 ZIP/XML、entitlement 和 CDHash 校验通过。
- 发布归档：`Scripts/package_release_app.sh`（pass）；解压后的 `.app` 再次通过 `Scripts/verify_app_bundle.sh`；ZIP SHA-256：`0b787badcc8850a7df6c1afeffa70dfe159f6cd3f80ebb092e785650b18e51e2`。
- 配置/模板目录：自动测试验证路径位于用户 `Application Support/com.zong.zongMacTools/FinderNewFile`，模板目录独立且运行时文件不嵌入 bundle；扩展 entitlement 保留 home-relative read-write `/`。
- Dock Window Quick Look：现有 XCTest 全量通过；未执行真实 Dock 悬停、屏幕录制权限和窗口操作人工 smoke test。

## 当前环境无法完成的人工项目

以下项目必须由用户在有图形界面、已启用 Finder Sync 扩展且安装 WPS/Office 的 macOS 会话中完成，不能用 XCTest、临时目录或 bundle 校验替代：

- `/Applications` 稳定副本中的设置页勾选、双击改名、拖拽排序、批量导入、删除确认和恢复默认确认。
- Finder 普通目录与桌面空白处的菜单范围（含文件、文件夹、多选、侧边栏、工具栏、最近使用/搜索等虚拟位置）。
- 退出主 App 后由 Finder 扩展读取最后配置并创建内置/自定义文件；配置损坏、模板缺失、权限拒绝和目录不可写时的真实一次性错误提示与临时文件清理。
- DOCX/XLSX/PPTX 及自定义 Office 模板在本机 WPS/Office 中无修复提示，完成最小编辑、保存、关闭和重开。
- Dock Window Quick Look 的真实 Dock 悬停、窗口预览/操作、设置导航和诊断导出 smoke test。
