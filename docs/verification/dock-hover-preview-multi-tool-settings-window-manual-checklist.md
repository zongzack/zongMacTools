# 多工具设置窗口人工验证清单

日期：2026-07-06

状态：not run

## 自动验证

2026-07-07 已完成：

- [x] `swift test`：192 XCTest，0 failures。
- [x] `swift build`：通过。
- [x] `Scripts/build_probe_app.sh`：通过，输出 `build/zongMacTools.app`。
- [x] `git diff --check`：通过。

## 菜单栏

| 项目 | 预期 | 状态 | 备注 |
| --- | --- | --- | --- |
| [ ] 极简菜单 | 菜单只显示 zongMacTools、Dock 窗口速览状态、打开设置、启停、关于与状态、导出诊断和退出。 | not run |  |
| [ ] 打开设置 | 从菜单打开设置窗口，默认进入 Dock 窗口速览页。 | not run |  |
| [ ] 启停 | 菜单启停只改变设置，预览 cancel / hide 由设置 observer 统一处理。 | not run |  |
| [ ] 关于与状态 | 菜单入口打开设置窗口并选中关于与状态页。 | not run |  |
| [ ] 导出诊断 | 菜单入口仍能打开保存面板并导出诊断。 | not run |  |

## 设置窗口

| 项目 | 预期 | 状态 | 备注 |
| --- | --- | --- | --- |
| [ ] 窗口复用 | 重复点击打开设置不会创建多个设置窗口，关闭后可再次打开。 | not run |  |
| [ ] Sidebar 分组 | 左侧显示应用、工具、支持；右键扩展为禁用占位，不可选中。 | not run |  |
| [ ] 通用页 | 显示语言和开机启动入口可用。 | not run |  |
| [ ] Dock 窗口速览页 | 总开关、悬停延迟、面板保留手感、最大卡片数、排除当前可排除 App、排除列表移除和清空入口齐全。 | not run |  |
| [ ] 离散滑杆 | 三个滑杆只能停在并写入合法预设值。 | not run |  |
| [ ] 排除目标 | “排除当前可排除 App”沿用当前 preview、最近 Dock hover、最近非本 app 前台应用的目标优先级。 | not run |  |
| [ ] 权限与状态页 | 辅助功能、屏幕录制状态、系统设置入口、刷新、导出诊断可用。 | not run |  |
| [ ] 关于与状态页 | 版本、build、bundle id、权限、登录项、签名和设置摘要可见，Copy Status 可用。 | not run |  |

## 主流程回归

| 项目 | 预期 | 状态 | 备注 |
| --- | --- | --- | --- |
| [ ] Dock hover preview | 打开设置窗口前后，Dock hover preview 仍可正常触发、展示、点击激活和隐藏。 | not run |  |
| [ ] 设置副作用 | 停用、修改延迟、排除当前 preview app 时副作用与旧菜单一致，且不重复 cancel / hide。 | not run |  |
| [ ] 权限缺失 | 屏幕录制缺失时仍静默抑制 preview UI。 | not run |  |
| [ ] 浅色/深色外观 | 设置窗口浅色和深色外观可读，无明显文字截断。 | not run |  |
