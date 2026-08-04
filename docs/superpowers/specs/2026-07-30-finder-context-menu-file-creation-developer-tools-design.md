# Finder 右键扩展：文件创建与开发工具设计

日期：2026-07-30

修订：2026-08-04

当前审批状态：本规格只批准进入第 15.3 和 16 节明确限定的阶段 0 最小平台探针；其他章节在被阶段 0 引用时只提供对应探针的输入、公开 API 候选和通过标准，不授权实现正式业务能力。阶段 0 的强制项全部通过、验证记录回填并完成一次架构复审后，才允许进入正式业务实现。

## 1. 目标

在现有 `zongMacTools` 中增加一个 Finder Sync 右键扩展，为普通本地目录以及阶段 0/阶段 3 已验证、正常挂载且支持本规格原子发布语义的外置磁盘提供两类操作：

1. 从内置类型或用户导入的模板创建新文件。
2. 使用 Terminal、Visual Studio Code 或用户添加的 `.app` 打开 Finder 当前上下文。

首个可发布版本采用 ad-hoc 签名，定位为可从网站下载的免费技术预览版。它不使用 Developer ID，不进行 Apple 公证，也不宣传为通过 Gatekeeper 验证的正式发行版。设计必须只使用公开 API，并保留以后迁移到 Developer ID 和公证发行的入口。

本规格分为两个审批边界：

1. 当前可以直接进入实现的只有第 15.3 和 16 节限定的阶段 0 最小平台探针；不得因为探针引用后续业务章节而顺带实现该章节的正式功能。
2. Finder Sync 加载、ad-hoc App Group、URL Scheme 冷热启动、Terminal Services、普通本地目录覆盖和启动磁盘原子发布等强制探针全部通过并形成验证记录后，必须重新评审探针结果；评审通过后才能进入正式业务实现。外置卷硬件不可用可以记录为 `blocked / not available`，但在真实外置卷验证完成前不得发布对外置卷的兼容承诺。

后续章节是“探针通过后生效”的业务契约，不代表其中的平台假设已经得到证明。阶段 0 失败时必须执行第 16 节的停止条件，不能一边保留失败结论一边继续实现业务功能。

## 2. 已确认的产品决策

### 2.1 Finder 上下文

- 在 Finder 空白处打开菜单时，当前目录是操作上下文。
- 单选文件夹时，文件创建目标是该文件夹内部。
- 单选文件时，文件创建目标是该文件所在目录。
- 多选时禁用文件创建。
- 普通本地目录属于支持范围；正常挂载的外置磁盘只有在阶段 0/阶段 3 验证覆盖、权限和原子发布后才属于可对外承诺的支持范围。
- iCloud Drive、OneDrive、Dropbox、网络卷、文件提供程序虚拟目录和 Finder 特殊位置不作可靠性承诺。
- 不使用全局鼠标监听，不实现 Finder 之外的第二套自定义右键菜单。
- Finder 上下文在 `menu(for:)` 构造菜单时冻结。每个可点击菜单项持有同一次菜单构造得到的不可变上下文快照；动作回调不得重新读取 Finder 当前选择来替换它。
- Finder package，包括 `.app`，按文件处理；符号链接和 Finder alias 不跟随目标，也按文件处理。卷根按文件夹处理。VS Code 和自定义工具仍收到原始 URL，不收到解析后的替代 URL。
- `FIMenuKind.contextualMenuForContainer` 只使用 `targetedURL()` 作为当前目录；`selectedItemURLs()` 必须为空或被忽略。没有单一、有效的本机 `file:` 目录 URL 时返回单一禁用状态项。
- `FIMenuKind.contextualMenuForItems` 只使用 `selectedItemURLs()` 作为选择数组；`targetedURL()` 不得替代该数组。数组为空、包含非本机 `file:` URL 或原始项目数超过 256 时返回单一禁用状态项。扩展必须记录阶段 0 中 Finder 实际返回的两套 API 组合；未记录的组合按无效上下文处理。

### 2.2 文件创建

- 第一个候选名称是 `未命名.ext`；英文界面使用 `Untitled.ext`。
- 名称冲突后依次尝试 `未命名 2.ext`、`未命名 3.ext`，英文同理。
- 单次创建最多尝试 10,000 个候选名称；全部冲突或目标文件系统不支持本规格要求的不覆盖原子提交时，创建失败并显示明确错误。
- 创建成功后使用公开 API 让 Finder 选中新文件。
- 不使用 Apple Events 或系统辅助功能强制 Finder 进入行内重命名；用户可按 Return 重命名。
- 用户导入的模板复制到应用管理的模板库，之后不依赖原始文件位置。
- 模板设置支持显示名称修改、排序、启用/停用和删除。
- 最终文件只在模板内容完成 `write loop -> 设置属性 -> fsync(fd) -> close 并检查错误` 且 close 成功后才以最终名称出现；空模板创建零字节文件是有效结果，非空模板的最终文件必须逐字节等于模板内容。本规格不承诺断电后的目录持久化顺序。
- 文件名语言取自菜单快照；创建命令冻结该快照的语言，避免主程序冷启动或系统语言变化后改变本次候选名称。

### 2.3 内置文件类型

首版提供以下 14 类内置模板：

| 菜单类型 | 扩展名 | 初始内容要求 |
| --- | --- | --- |
| TXT | `.txt` | 空文本文件 |
| Markdown | `.md` | 空 UTF-8 文本文件 |
| JSON | `.json` | 有效的空 JSON 对象并以换行结尾 |
| XML | `.xml` | UTF-8 XML 声明和一个空根元素 |
| Word | `.docx` | 可被兼容办公软件打开的有效 OOXML 文档 |
| Excel | `.xlsx` | 包含一个空工作表的有效 OOXML 工作簿 |
| PowerPoint | `.pptx` | 包含一张空白幻灯片的有效 OOXML 演示文稿 |
| YAML | `.yaml` | 文档起始标记并以换行结尾 |
| Python | `.py` | 空 UTF-8 文本文件 |
| HTML | `.html` | 最小有效 HTML5 文档骨架 |
| CSS | `.css` | 空 UTF-8 文本文件 |
| JavaScript | `.js` | 空 UTF-8 文本文件 |
| TypeScript | `.ts` | 空 UTF-8 文本文件 |
| RTF | `.rtf` | 最小有效 RTF 文档，不是改扩展名的纯文本文件 |

`.docx`、`.xlsx` 和 `.pptx` 以应用资源中的已验证二进制模板交付，不能通过创建零字节文件后修改扩展名实现。WPS Office 直接使用这三种标准 OOXML 格式；首版不提供 `.wps`、`.et` 或 `.dps` 原生模板。

### 2.4 开发工具

- 内置工具是 Terminal 和 Visual Studio Code。
- 其他工具由用户通过“添加开发工具”选择 `.app`。
- Finder 空白处把当前目录传给工具。
- 单选文件夹把该文件夹传给工具。
- 单选文件时，Visual Studio Code 和自定义工具接收文件；Terminal 接收文件所在目录。
- 多选时，Visual Studio Code 和自定义工具接收全部选中项。
- 多选时，Terminal 只在所有选中项解析到同一个目标目录时可用，否则禁用。
- “打开成功”只表示 macOS 接受了向指定应用交付 URL 的请求；第三方应用是否理解目录、是否处理全部多选项以及如何复用窗口由该应用决定，本工具不作超出公开打开接口的保证。

### 2.5 Terminal 行为

Finder 菜单只显示一个“在 Terminal 中打开”。`zongMacTools` 设置页提供“新窗口”和“新标签页”两个选项，并保存本工具自己的默认值。

执行时使用 Terminal 注册的公开 macOS Services：

- `New Terminal at Folder`
- `New Terminal Tab at Folder`

这两个名称只是阶段 0 的验证候选，不是正式实现可以无条件硬编码的跨版本/跨语言契约；正式映射只在第 2.5、5.5 和 15.3 节的公开发现与实测记录稳定通过后才成立。探针通过后，正式规格必须回填一个版本化的静态 Terminal Service descriptor 表，键为支持的 macOS build 范围和系统语言，值为公开调用 API、精确 Service 名称和 pasteboard 类型；运行时只能选择表中完全匹配的 descriptor，不能枚举或猜测本地化字符串。没有匹配 descriptor 时 Terminal 菜单项保留但禁用，并显示“当前系统上的 Terminal 服务不可用”。

在当前可观察到的 Terminal 版本中，这两个服务分别对应新窗口和新标签页。系统没有供第三方稳定读取的统一“目录应在窗口还是标签页打开”偏好，因此本工具不声称跟随 Terminal 自身设置，也不请求自动化权限。服务不可用或调用失败时显示明确错误，不退回 Apple Events。

Terminal 是首版核心工具，但这两个 Service 的注册名称、pasteboard 输入类型和运行结果仍属于平台假设。阶段 0 必须在受支持的最低 macOS 和当前发布测试版本上记录公开调用 API、pasteboard 类型、系统语言、Service 启用状态、Terminal 冷启动/已运行以及“新标签页但当前无窗口”的真实结果。Service 名称或输入契约无法稳定复现时，本规格不能进入正式业务实现；只有另行移除 Terminal 产品承诺、更新菜单矩阵并重新评审规格后，其他能力才能独立继续。

## 3. 范围外

首版不实现：

- Finder 行内重命名自动触发。
- 文件夹模板或一次创建多个文件的项目模板。
- 自定义命令、Shell 脚本、参数占位符或环境变量编辑器。
- VS Code 的 `code` 命令行安装或管理。
- Terminal 之外的终端模拟器专用适配；其他终端可作为普通自定义 `.app` 添加。
- WPS 私有文件格式。
- Finder 工具栏按钮、侧边栏菜单或状态徽章。
- 云盘和文件提供程序目录的兼容性承诺。
- App Store 分发、Developer ID、公证、自动更新和静默安装。
- 私有 API、全局事件监听、Apple Events 或辅助功能驱动的 Finder 操作。
- 主程序 App Sandbox 化。现有主程序继续作为非沙盒菜单栏应用；只有 Finder Sync 扩展启用 App Sandbox。
- 对命令执行提供 exactly-once 保证。首版采用明确的 at-most-once 语义，进程在副作用边界崩溃时可能把结果标记为未知，但不得自动重放可能已经执行的外部动作。

## 4. 架构选择

### 4.1 采用方案 A：轻量扩展、主程序执行

正式结构由三个边界组成：

```text
Finder
  |
  | 加载菜单、提交用户命令
  v
RightClickFinderExtension.appex
  |
  | App Group 中的菜单快照和命令文件
  v
zongMacTools.app
  |
  | 创建文件、调用 Terminal Service、打开开发工具
  v
文件系统 / NSWorkspace / macOS Services
```

Finder 扩展只负责：

- 读取 Finder 当前上下文。
- 根据主程序发布的只读菜单快照构造 `NSMenu`。
- 把用户动作写成小型、版本化、原子的命令文件。
- 用自定义 URL Scheme 唤醒主程序。

主程序负责：

- 管理设置、内置模板、自定义模板和开发工具。
- 发布扩展可直接读取的菜单快照。
- 把 URL Scheme 当作唤醒提示，在每次启动和每次收到 URL 后串行扫描、领取并验证全部 pending 命令。
- 创建文件、调用 Terminal Service、通过 `NSWorkspace` 打开工具。
- 显示成功后的 Finder 选择和用户可理解的错误。

扩展不得在 Finder 菜单回调中扫描应用、复制模板、创建 Office 文档或等待主程序 IPC。这样可以控制 Finder 进程中的工作量，并避免主程序未运行时卡住 Finder 菜单。

主程序明确保持非沙盒，以兼容现有系统辅助功能、ScreenCaptureKit 和普通网站分发结构。它声明 App Group entitlement，但不得声明 `com.apple.security.app-sandbox`。Finder 扩展声明 App Sandbox 和同一个 App Group。目标文件系统访问由主程序自身完成，受 POSIX 权限、目标卷能力和 macOS 隐私控制约束；命令中的普通 `file:` URL 不被表述为从扩展转移给主程序的沙盒授权。

App Group 在本方案中是主程序与扩展的共享存储和可靠队列位置，不是针对同一登录用户其他进程的认证边界。由于主程序非沙盒，同一用户下的其他非沙盒进程可能直接访问用户可读写的共享容器。命令的 UUID、schema 和工具 ID 校验用于防止误投、损坏和越过产品注册表，不用于抵抗已经取得同一用户文件权限的恶意进程。阶段 0 必须验证实际容器解析与签名稳定性，但不得把“其他同用户非沙盒进程无法读目录”写成通过条件。

### 4.2 方案 B 只作为失败后的重新设计入口

如果 ad-hoc 签名下的 App Group 探针失败，停止本规格中的正式业务实现。后续单独设计由主程序提供生命周期受控、带超时和调用方验证的本机 IPC 服务。

本规格不预先承诺某种本机端口、Unix Socket 或 Mach Service，因为它们各自涉及扩展沙盒、服务注册和认证约束。不得通过硬编码访问 `~/Library/Group Containers`、关闭沙盒或使用私有 API 伪造方案 A 成功。

### 4.3 不采用“全部逻辑放在扩展中”

模板导入、Office 资源、工具发现、错误界面和文件写入都不适合由 Finder 扩展承担。扩展生命周期由系统管理，可能随时终止；把状态和业务逻辑放入扩展会增加 Finder 卡顿、状态丢失和重复执行风险。

## 5. App Group 探针门槛

### 5.1 标识和签名候选

探针沿用当前主程序标识，并为扩展和共享组使用稳定候选值：

| 对象 | 标识 |
| --- | --- |
| 主程序 | `com.zong.zongMacTools` |
| Finder 扩展 | `com.zong.zongMacTools.RightClickFinderExtension` |
| App Group | `group.com.zong.zongMacTools` |
| URL Scheme | `zongmactools` |

主程序和扩展都声明 `com.apple.security.application-groups`。主程序不得声明 `com.apple.security.app-sandbox`；扩展必须声明 App Sandbox。探针使用当前 ad-hoc 身份签名，不需要 Developer ID 或公证，但必须验证这种组合确实能取得同一容器，不能把 entitlement 文件中“写了同一个字符串”视为能力已经成立。

### 5.2 最小往返流程

1. 主程序必须通过 `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` 获取容器，不能自己拼接路径。
2. 主程序原子写入带随机 UUID 的 `probe/request.json`。
3. 用户在真实 Finder 中打开扩展菜单，使系统实际加载扩展。
4. 扩展通过同一个公开 API 获取容器并读取请求。
5. 扩展原子写入 `probe/response.json`，包含请求 UUID 和它解析到的容器路径。
6. 主程序读取响应并核对 UUID、路径和内容。
7. 重启主程序、Finder 和扩展后重复验证。
8. 重新构建、按“扩展先签、主程序最后签”的顺序 ad-hoc 签名后重复验证。

### 5.3 通过标准

- 主程序和扩展得到的容器 URL 都非空。
- 标准化后的两个容器 URL 相同。
- 双向原子读写成功。
- Console 中没有与共享目录有关的 Sandbox、entitlement 或签名拒绝。
- Finder 重启和扩展重载后仍能往返。
- ad-hoc 重建并替换应用后有可复现的成功结果。
- 主程序冷启动、热启动和连续收到多个合法 URL 时都能扫描同一 pending 队列，不依赖每个 URL 回调逐一到达。
- Launch Services 对 `zongmactools` 的解析目标是当前安装在 `/Applications` 的发布候选；存在旧副本或另一个处理同名 scheme 的应用时记录为失败。

### 5.4 失败标准

- 任一进程无法解析 Group Container。
- 两边得到不同容器。
- 扩展因沙盒、entitlement 或签名被拒绝访问。
- 只能在一次偶然安装中成功，重建或重启后不可复现。
- 必须手工访问系统 Group Containers 路径才能成功。
- URL Scheme 解析到旧副本、开发目录副本或其他应用。

任何一条失败都阻止方案 A 的业务开发，并触发方案 B 的独立设计。探针不通过时不能通过忽略错误、关闭扩展沙盒或直接读写其他应用容器继续实现。

### 5.5 探针同时记录但不混淆的能力

App Group 往返是硬门槛。为了避免下一阶段立即遇到另一个平台阻塞，探针构建还要记录：

- Finder 能加载嵌入的 ad-hoc `.appex`。
- 空白处、单选和多选菜单回调能取得预期 URL。
- 扩展可以通过 `zongmactools://command/<UUID>` 唤醒已运行或未运行的主程序。
- URL Scheme 在主程序替换安装、存在旧副本以及重新注册后实际解析到的应用；解析到错误副本或其他应用视为失败，发布测试不得保留多个可注册同一 scheme 的副本。
- `/` 或明确卷根目录的 Finder Sync 注册方式能覆盖普通本地目录。
- 正常挂载的外置磁盘能否显示菜单；没有可用外置盘时记录为 `blocked / not available`，不能写成通过。
- 目标文件系统是否支持第 10.3 节要求的同目录、不覆盖原子发布。至少验证启动磁盘实际文件系统；可用时再验证一块正常外置卷。外置卷未验证时不能承诺其文件创建原子性。
- Terminal 的 `New Terminal at Folder` 和 `New Terminal Tab at Folder` 是否能用公开 Service 调用，并记录实际 API、pasteboard 类型、系统语言、Terminal 未运行/已运行、有窗口/无窗口和 Service 被禁用时的结果。

URL Scheme 唤醒失败也会阻止正式方案 A，因为写入命令但无法可靠通知主程序会形成无反馈的失效路径。

## 6. 构建和 Bundle 结构

### 6.1 保留 SwiftPM 作为主程序与测试入口

现有 SwiftPM executable、源码布局和 `swift test` 流程继续保留。Finder 扩展是独立 `.appex`，不能伪装成主 executable 中的普通类型。

`zongMacTools.xcodeproj` 用于声明原生 Finder Sync Extension target 和生成合法 `.appex`。主程序仍可由 SwiftPM 构建，打包脚本负责组合两个产物。共享的协议模型使用源文件级共享，不引入动态框架，也不让扩展链接整个 Dock 窗口速览实现。

SwiftPM package、主程序 `LSMinimumSystemVersion`、Xcode 主/扩展 target 的 `MACOSX_DEPLOYMENT_TARGET` 全部固定为 `14.0`。主程序与扩展必须为相同 CPU 架构集合；首版不假设 Universal 2，实际架构按第 15.2/15.4 节检查和披露。

### 6.2 最终目录

```text
zongMacTools.app/
  Contents/
    Info.plist
    MacOS/DockHoverPreviewProbe
    Resources/
      BuiltInTemplates/
      en.lproj/InfoPlist.strings
      zh-Hans.lproj/InfoPlist.strings
    PlugIns/
      RightClickFinderExtension.appex/
        Contents/
          Info.plist
          MacOS/RightClickFinderExtension
```

上面的目录是正式发布 Bundle；当前主 executable 固定为 `DockHoverPreviewProbe`，外层 `Info.plist` 的 `CFBundleExecutable` 和 SwiftPM 最终 product name 必须与它完全一致。阶段 0 的最小 probe host 可以复用该主 executable，但只能启用第 15.3 节限定的 probe 行为，不能因名称相同而带入正式业务能力。外层 `Info.plist` 还必须声明一个 `CFBundleURLTypes` 项，包含稳定的 `CFBundleURLName`、`CFBundleTypeRole` 和唯一的 `CFBundleURLSchemes = ["zongmactools"]`；15.2 的自动检查必须验证这些字段与当前 Bundle identifier 一致。

### 6.3 签名顺序

打包脚本必须：

1. 构建主程序和扩展。
2. 组装主程序 Bundle 并嵌入 `.appex`。
3. 使用扩展 entitlements 签名 `.appex`。
4. 使用主程序 entitlements 签名外层 `.app`。
5. 用 `codesign --verify --deep --strict` 验证完整 Bundle。
6. 分别导出并检查主程序和扩展的实际 entitlements。

签名必须从内到外，不依赖 `codesign --deep --force` 自动替内层选择 entitlements。默认身份仍是 `-`；以后配置 Developer ID 时只替换签名与 provisioning 流程，不改变命令协议和业务边界。

### 6.4 主程序隐私用途说明

实际执行目标目录访问和文件创建的是非沙盒主程序，因此外层 `.app/Contents/Info.plist` 必须包含以下四个非空用途说明；不能只把它们写在 Finder Sync 扩展的 plist 中：

- `NSDesktopFolderUsageDescription`
- `NSDocumentsFolderUsageDescription`
- `NSDownloadsFolderUsageDescription`
- `NSRemovableVolumesUsageDescription`

四项文案必须在 `en.lproj/InfoPlist.strings` 和 `zh-Hans.lproj/InfoPlist.strings` 中分别本地化，明确说明本工具只在用户触发 Finder 动作时访问目标位置以创建文件或交付打开请求。用途说明只负责解释系统隐私提示，不等于预先授予访问权；实现必须按用户允许、拒绝和之后撤销访问分别处理失败，不把权限状态写入长期配置或命令协议。Bundle 自动检查必须验证四个 key 在最终外层 plist 中存在、非空且两种本地化均可解析。

本功能不需要系统辅助功能、屏幕录制或 Apple Events 权限，也不应为了 Finder 菜单、Terminal Service 或文件创建新增 `NSAppleEventsUsageDescription`。主程序现有 Dock 窗口速览若另有这些权限需求，必须在下载说明和首次使用流程中与本功能的目标目录隐私提示分开说明。

## 7. Finder 菜单设计

### 7.1 菜单层级

扩展在 Finder 上下文菜单中提供一个稳定的 `zongMacTools` 根项，子菜单为：

```text
zongMacTools
  新建文件 >
    <文本与代码类内置模板，按各自分组内的设置顺序>
    --------
    <Office 与富文本类内置模板，按各自分组内的设置顺序>
    --------
    <用户模板，按设置顺序>
  --------
  在 Terminal 中打开
  使用 Visual Studio Code 打开
  使用开发工具打开 >
    <用户添加的 .app，按设置顺序>
```

内置模板只允许在所属固定分组内排序，不能跨分组移动。TXT、Markdown、JSON、XML、YAML、Python、HTML、CSS、JavaScript 和 TypeScript 属于“文本与代码”；Word、Excel、PowerPoint 和 RTF 属于“Office 与富文本”。某一分组没有启用项目时不显示该分组，也不留下相邻或尾部分隔线。自定义模板只在自定义模板域内排序，始终位于内置模板之后。

Terminal 和 Visual Studio Code 是固定顺序的一级工具项，允许分别启用或停用，但不允许与自定义工具混排。自定义工具只在“使用开发工具打开”子菜单内排序；没有启用的自定义工具时隐藏该子菜单。用户停用的模板或工具不出现在菜单中。用户启用 Terminal 但当前系统没有匹配的 Terminal Service descriptor 时，Terminal 一级项保留为禁用的“当前系统上的 Terminal 服务不可用”，它不计为可点击业务动作；若没有其他可点击动作，根菜单只保留这个单一状态项。多选时“新建文件”保留但禁用；Terminal 目标不唯一时保留但禁用，使菜单结构稳定且状态可理解。

至少有一个模板启用时才显示“新建文件”：单选/空白上下文正常启用，多选时保留但禁用。没有任何模板启用时隐藏整个“新建文件”项，不创建空子菜单。Terminal、VS Code 和自定义工具按各自启用状态过滤；过滤后没有任何可见业务动作时仍保留 `zongMacTools` 根项，根菜单只包含一个禁用的“没有已启用的操作”状态项，唯一例外是第 2.5 节定义的 `terminalDescriptorUnavailable` 状态项。上下文无效、选择超过上限或快照尚未初始化时使用各自的单一禁用状态项，不同时混入可点击业务项。

### 7.2 Finder API 上下文

扩展只响应：

- `FIMenuKind.contextualMenuForContainer`：Finder 空白处。
- `FIMenuKind.contextualMenuForItems`：单选或多选项目。

Finder 工具栏、侧边栏等其他菜单类型返回 `nil`。扩展通过 `FIFinderSyncController` 的 `targetedURL()` 和 `selectedItemURLs()` 获取上下文，不根据鼠标坐标或全局事件猜测目标。

### 7.3 目录注册

探针先验证以 `/` 作为监控根目录时的实际覆盖范围。若普通本地目录可用但外置卷不能继承覆盖，扩展在启动和卷挂载变化后显式维护 `/Volumes` 下的正常卷根目录集合。

目录注册只决定菜单覆盖范围，不在 Finder 回调中递归扫描文件系统。文件提供程序或云盘即使偶尔显示菜单，也仍属于不保证范围。

### 7.4 菜单性能

`menu(for:)` 必须只做：

- 读取 Finder 已提供的少量 URL。
- 去重前先检查 Finder 原始 URL 数组的 256 项上限；不超过上限时，为每个 URL 有界读取分类所需的 `isDirectory`、`isPackage`、`isSymbolicLink`、`isAliasFile` 和 `volumeURL` 等公开 resource values，并用不跟随最终符号链接的 `lstat` 读取 `st_dev`/`st_ino` 作为短生命周期对象 identity；不读取文件内容、不跟随链接或 alias。
- 运行其余纯内存目标解析。
- 使用内存中的最后一份有效菜单快照创建 `NSMenu`。

它不得启动主程序、枚举已安装应用、读取模板内容、访问网络或等待异步结果。扩展发现 `menu-catalog.json` 版本变化时可以重新解码小型文件；解码失败则保留进程内最后一份有效快照。进程内没有有效快照时只显示一个禁用的“请先打开 zongMacTools”状态项。阶段 0 在启动磁盘本地目录分别以 1、64、256 个项目做 20 次冷/热菜单测量，记录中位数和 p95；`menu(for:)` p95 必须不超过 150 ms，否则先降低选择上限或重新设计分类路径，不带着 Finder 卡顿风险进入业务实现。云盘和网络卷不纳入该性能承诺。

## 8. 目标解析规则

目标解析是共享的纯领域逻辑，由自动测试覆盖。URL 使用路径标准化但不得解析符号链接或 Finder alias，然后按标准化 URL 去重，同时保留 Finder API 返回的首次顺序。原始数组已经通过 256 项上限后，去重后的数组不得再超过 256 项。对象 identity 是不跟随最终符号链接的 `lstat` 返回的 `(st_dev, st_ino)`，以无符号十进制字符串编码；扩展在构造菜单时把 `FIMenuKind`、冻结后的 URL 数组、分类结果、对象 identity 和菜单快照语言组成不可变上下文；动作回调只序列化这份上下文。

| Finder 上下文 | 创建文件目标目录 | Terminal 目标 | VS Code / 自定义工具目标 |
| --- | --- | --- | --- |
| 空白处 | 当前目录 | 当前目录 | 当前目录 |
| 单个文件夹 | 文件夹内部 | 该文件夹 | 该文件夹 |
| 单个文件 | 文件所在目录 | 文件所在目录 | 该文件 |
| 多选且目标目录相同 | 禁用 | 唯一目标目录 | 全部选中项 |
| 多选且目标目录不同 | 禁用 | 禁用 | 全部选中项 |

多选 Terminal 的“目标目录”按以下规则计算：文件夹对应自身，文件对应父目录。例如同时选择文件夹 `A` 和 `A/file.txt` 时，两项都解析到 `A`，Terminal 可以启用。

分类使用菜单构造时读取的公开 URL resource values：真实目录且不是 package 的项目按文件夹处理；package、普通文件、符号链接和 Finder alias 按文件处理；文件系统卷根按文件夹处理。扩展不跟随链接或 alias。主程序执行时使用相同规则重新验证冻结 URL 的现存类型；类型已经改变时拒绝动作，不把它重新解释成另一种 Finder 上下文。

以下情况禁用对应动作：

- Finder 没有提供文件 URL。
- 空白处没有有效的目标目录。
- 项目在动作执行前被移走、删除或所属卷被弹出。
- Terminal 多选不能归一到一个目录。
- 原始 Finder URL 数组超过 256 项。此时文件创建本来就因多选禁用，Terminal、VS Code 和自定义工具也禁用，并显示“选择项目过多”的禁用状态，不生成命令文件。

扩展不在菜单构建路径中执行昂贵的可写性检查。主程序在真正执行时重新验证目录存在、是目录并可创建文件；失败时给出错误，不覆盖任何已有项目。

## 9. App Group 数据协议

### 9.1 目录布局

```text
<Group Container>/
  right-click/
    menu-catalog.json
    commands/
      staging/<UUID>.json.tmp
      pending/<UUID>.json
      processing/<UUID>.json
      results/<UUID>.json
      queue.lock
    templates/
      <TemplateID>/content
      .staging/<TemplateID>/content
    state/
      configuration.json
      configuration.previous.json
      initialization.json
      host.lock
      extension-heartbeat.json
    probe/
      request.json
      response.json
```

主程序是 `configuration.json`、菜单快照、模板库和 result 记录的唯一写入者。`configuration.json` 只保存本 Finder 右键功能的状态，不迁移或替换现有 Dock 预览等其他工具的设置存储。它是 schema 版本化、最大 2 MiB、原子替换的主状态，持久化模板事务状态、工具普通书签、Terminal 设置和排序/启停；扩展不得读取它。每个受管理的 JSON 原子发布都必须遵循同一顺序：完整编码到同目录临时文件，执行 `write loop -> 设置权限和必要属性 -> fsync(fd) -> close 并检查错误`，重新打开并做有界完整性校验，最后才 `rename` 到目标名称；rename 前后的崩溃恢复必须保留至少一个可验证副本。对配置更新，新的编码结果在整个 previous 保存过程结束前始终保持为临时文件；先把仍在 current 目标名下的旧有效配置复制到独立 previous 临时文件，按上述写入/校验顺序原子替换 `configuration.previous.json`，只有成功后才把新的临时文件原子 rename 为 `configuration.json`。不能先发布新 current、让 previous 捕获新版本，也不能先删除唯一有效副本。

配置 schema 只向前兼容已明确支持的旧版本。启动发现旧但可迁移的 schema 时，主程序在独立迁移事务中先保留原 current 副本，再生成当前 schema 的完整副本，重新校验模板记录、工具书签和排序域，成功后按 current/previous 原子发布顺序替换；迁移必须幂等，失败时保留旧副本并进入恢复错误。未知未来 schema 不得按默认值覆盖，也不得猜测字段含义。

首次初始化是唯一可创建默认配置的例外。只有 `configuration.json`、`configuration.previous.json` 和 `initialization.json` 都不存在，且除固定空目录和阶段 0 的 `probe/` 记录外没有任何受管持久化内容（`menu-catalog.json` 不存在，`templates/`、`commands/staging`、`commands/pending`、`commands/processing` 和 `commands/results` 均为空）时，主程序才可以开始初始化。它先按上述 JSON 契约发布 `initialization.json`，状态为 `starting` 并包含首份默认配置的 schema 与 SHA-256；再发布首份 `configuration.json`，其中 14 个内置模板全部启用并按第 7.1 节的固定组内默认顺序排列，Terminal 与 VS Code 启用、Terminal 为 `newWindow`，且没有自定义模板或工具；最后把 marker 原子更新为 `complete` 并记录 current 的 SHA-256。首次发布不要求 `configuration.previous.json`。若进程在 marker 为 `starting` 时终止，启动恢复只可在 current/previous 均不存在且仍无其他受管内容时重新发布同一首份默认配置；若 current 已存在且哈希匹配，则只完成 marker。只要任一配置文件、marker、菜单快照、模板目录或命令状态已经存在但无法满足上述预期，均视为已有状态或损坏配置：不发布默认值、不删除数据，进入恢复错误。

启动时先验证 current，失败时只回退到 schema 可读且校验通过的 previous；两个副本都无效时不发布业务菜单，并显示配置恢复错误，不猜测字段。使用 previous 回退或两个副本都无效时，主程序不得根据不完整状态删除任何 staging、模板最终目录或工具记录，只能停用无法证明有效的菜单项并提示恢复。扩展只读取 `menu-catalog.json`，不读取模板正文或其他设置文件。扩展是 pending 命令的写入者，主程序通过原子移动领取命令。result 只保存命令 ID、动作类型、完成时间、`succeeded`、`failed` 或 `unknown` 状态、错误分类和可选的 `feedbackClaimedAt`；`action` 只允许 `createFile`、`openTool` 或 `unknown`，其中 `unknown` 仅用于文件名含规范 UUID 但内容无法解码出动作的协议损坏。result 不保存 URL、模板内容或工具路径，用于阻止重复执行和最多一次地领取错误反馈。

### 9.2 菜单快照

`menu-catalog.json` 至少包含：

```json
{
  "schemaVersion": 1,
  "revision": 12,
  "publishedAt": "2026-07-30T10:00:00Z",
  "language": "zh-Hans",
  "templates": [
    {
      "id": "builtin.json",
      "displayName": "JSON",
      "group": "textAndCode",
      "enabled": true,
      "sortOrder": 30
    }
  ],
  "tools": [
    {
      "id": "builtin.terminal",
      "displayName": "Terminal",
      "kind": "terminal",
      "placement": "builtinPrimary",
      "enabled": true,
      "availability": "available",
      "sortOrder": 10
    }
  ]
}
```

快照只包含构造菜单所需的稳定 ID、显示名称、类型、启用状态、可用性、固定分组和分组内排序，不包含自定义工具书签、应用完整路径或模板正文。`availability` 只允许 `available` 或 `terminalDescriptorUnavailable`；后者只适用于内置 Terminal 且要求扩展渲染为禁用状态。菜单排序先按 `sortOrder` 升序，再按稳定 ID 的字节序升序解决并列；配置中允许并列但不得产生非确定顺序。主程序在启动、相关设置变化和模板导入删除后，按上述 JSON 发布顺序通过同目录临时文件加原子替换发布新 revision；旧 revision 或新 revision 至少有一个始终可验证。

菜单快照有以下硬限制：UTF-8 JSON 最大 512 KiB；`language` 只允许 `zh-Hans` 或 `en`，其他有效系统语言使用 `en`；内置模板固定为 14 个；自定义模板最多 32 个；自定义工具最多 16 个；用户可编辑显示名称去除首尾空白后必须为 1 至 80 个扩展字素，不能包含换行或其他控制字符。超过限制的设置操作在主程序中被拒绝，主程序不得发布超过限制的快照；扩展遇到超限快照时视为损坏并沿用最后有效版本。系统或应用语言变化只影响主程序下一次发布的快照，已经构造的菜单和命令继续使用冻结语言。

### 9.3 命令文件

每次菜单动作写入一个单独文件：

```json
{
  "schemaVersion": 1,
  "id": "2F95B633-2B8A-4F70-B3A7-62F1886D4698",
  "createdAt": "2026-07-30T10:01:00Z",
  "action": "createFile",
  "subjectID": "builtin.json",
  "language": "zh-Hans",
  "context": "singleFile",
  "urls": ["file:///Users/example/Project/README.md"],
  "itemKinds": ["file"],
  "itemIdentities": [
    { "device": "16777232", "inode": "123456789" }
  ],
  "targetDirectoryIdentity": { "device": "16777232", "inode": "123456700" }
}
```

`action` 首版只有 `createFile` 和 `openTool`。`subjectID` 引用主程序管理的模板或工具记录。`context` 只允许 `container`、`singleFolder`、`singleFile` 或 `multipleItems`；`container` 对应 Finder 空白处，其他值对应 `contextualMenuForItems`。`language` 只允许 `zh-Hans` 或 `en`，来自构造该菜单的快照，用于冻结本次文件名语言；`openTool` 虽然也携带该字段，但不使用它决定行为。`itemKinds`、`itemIdentities` 与 `urls` 三者一一对应，只允许 `file` 或 `directory`；identity 固定为菜单构造时不跟随最终符号链接的 `lstat` 返回的 `{ device, inode }` 无符号十进制值，不得由路径字符串替代。空白处仍包含当前目录 URL、一个 `directory` 和该目录的 identity。`createFile` 与 Terminal 命令必须额外携带 `targetDirectoryIdentity`；VS Code/自定义工具命令在目标为目录时也携带该 identity。扩展不把任意输出文件名、命令行或可执行路径写入命令。

命令不能在 pending 目录中写临时文件。主程序和扩展统一用公开的 BSD `flock(2)` 作为锁原语，不能一边使用 `flock`、另一边使用 `fcntl` record lock。`state/host.lock` 和 `commands/queue.lock` 都以 `O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW`、模式 `0600` 打开并经 `fstat` 确认是预期普通文件；对各自 file descriptor 调用 `flock(fd, LOCK_EX | LOCK_NB)`。锁由持有该 descriptor 的进程在 close 或退出时释放。扩展取得 queue lock 失败时立即以 `queueBusy` 失败并发出系统提示音，不能在 Finder 回调中等待；主程序取得失败时延后 drainer/清理。阶段 0 必须用真实沙盒扩展和非沙盒主程序证明两边对同一个 queue lock inode 互斥。

扩展持有 queue lock 后有界统计名称规范且为普通文件的 `staging + pending + processing`，三种状态合计硬上限是 256；达到上限时以 `queueFull` 失败。未超限时以 `O_CREAT | O_EXCL | O_NOFOLLOW` 创建 `commands/staging/<UUID>.json.tmp` 作为槽位预留，然后释放 queue lock。多个扩展进程必须使用同一把锁完成“计数加预留”，不能先在锁外计数再创建 staging。

扩展只向已独占创建的 staging 文件执行 `write loop -> 设置权限和必要属性 -> fsync(fd) -> close 并检查错误`，全部成功后才用同一 Group Container 内的原子 rename 发布为 `commands/pending/<UUID>.json`。发布 rename 不改变队列总数；rename 失败时不得打开 URL Scheme。写入或发布失败时，扩展重新取得 queue lock 后删除自己的 staging 预留；如果锁仍忙，则保留该文件交给下述过期回收并立即返回失败，不能在 Finder 回调中等待。

`queue.lock` 保护所有会改变上述三种状态计数的操作。主程序删除无效/过期 pending、完成或恢复后删除 processing、回收 staging，以及扩展失败后删除自己的 staging，都必须在持有同一 exclusive lock 时重新确认目标仍是预期的规范普通文件再删除。pending 原子移动到 processing 虽不改变总数，也在这把锁内完成，以免与协议错误清理或启动恢复竞态。主程序暂时取不到锁时只延后该次领取或清理，不得绕过锁；result 清理不计入 256 条命令容量，不要求持有 queue lock。

主程序正常 drainer 只枚举 pending，绝不读取或删除仍可能处于发布中的 staging。它只可在启动恢复或周期维护中回收 staging：在 queue lock 内二次确认名称精确匹配规范 UUID 的 `<UUID>.json.tmp`、项目是未跟随链接打开并经 `fstat` 确认的普通文件、修改时间已超过 10 分钟、且没有同 UUID 的 pending 或 processing；未来时间、非规范名称、非普通文件和未超过阈值的项目均保留并只记录结构化异常。扩展发布必须在预留后 5 分钟内成功或放弃；若进程挂起后跨过 10 分钟阈值，回收与 rename 谁先完成由原子文件系统操作决定，rename 失败的一方必须按发布失败处理，不能重建或重放命令。成功发布后扩展打开：

```text
zongmactools://command/<UUID>
```

URL 只传 UUID，不传文件路径、模板内容或工具路径。URL 只是唤醒提示，不是唯一队列索引；主程序每次启动以及每次收到任一合法命令 URL 后都必须尝试排空全部 pending 命令。这样单次 URL 通知丢失、合并或乱序不会让已经持久化的其他 pending 命令永久滞留。

### 9.4 领取、排空和 at-most-once

主程序正常生命周期启动时无条件初始化队列并扫描 pending，这一步独立于启动参数。已经运行的主程序收到外部 URL 时，先验证 scheme 必须为 `zongmactools`、host 必须为 `command`、path 必须只有一个规范 UUID；非法 URL handler 不额外调度扫描，冷启动期间仍可能由独立的正常启动扫描处理此前已经存在的合法 pending。合法 URL 中的 UUID 只用于日志关联，主程序随后调度全量 pending 扫描；没有 pending 时安静返回。

同一进程只有一个串行 drainer。主程序取得 host lock 后先安装 pending 目录的公开文件系统事件观察，再做第一次全量 scan；观察安装、重建或报告事件丢失/合并后都必须全量 rescan。观察事件和 URL 最终只调度同一个 drainer，不忙轮询。drainer 在每轮处理后再次扫描，直到一轮没有发现可领取 pending 且观察器没有记录新变化，才算达到 quiescent；这消除 scan 与 observer arm 之间的丢失窗口。

drainer 解码所有有效 pending 文件，按 `createdAt` 升序、UUID 字符串升序作为稳定并列顺序逐个处理。领取单条命令时在 queue lock 内把它原子移动到 `processing`；只有成功移动的进程可以继续。URL 重复投递、同一应用内的重复扫描以及两个应用副本竞争领取时，都不能让同一个命令开始两次。发布验证仍禁止保留多个注册同一 URL Scheme 的应用副本，因为原子领取不能解决版本和设置写入冲突。

主程序在执行副作用前完整验证命令，并拒绝：

- 未知 schema 版本。
- UTF-8 JSON 超过 1 MiB、URL 数量为 0 或超过 256、单个 URL 字符串超过 16 KiB。
- 文件内 ID 与文件名不一致，或 UUID 不是规范大写连字符格式。
- 创建时间早于当前墙上时间 5 分钟以上，或晚于当前墙上时间 1 分钟以上。
- 非本机 `file:` URL。host 只允许为空或 `localhost`，不能接受远程 file host。
- 非法 `language`、未知 `context`，或主程序从冻结 URL 重新推导的上下文、数量和项目分类与命令不一致。
- 缺少、无法解析或与命令不一致的 `itemIdentities`、`targetDirectoryIdentity`；主程序必须用不跟随最终符号链接的 `lstat` 重新读取 identity，并在卷、文件或目录身份变化时拒绝动作，即使路径和类型仍然相同。
- 不存在、已禁用或类型不匹配的模板和工具 ID。
- `createFile` 不是单一空白处、单文件夹或单文件上下文；`openTool` 的 URL 数量或 Terminal 唯一目录规则不符合第 8 节矩阵。

文件名是规范 UUID 但内容损坏或违反上述规则的 pending 文件，主程序写入 `failed` result，并在 queue lock 内二次确认后删除该 pending；无法从规范文件名取得 UUID 的项目只记录结构化协议错误。目录中非普通文件和不符合 `<UUID>.json` 命名的项目不打开、不跟随，也不自动删除。所有枚举、大小检查和解码都必须有界，不能把整个未知文件无上限读入内存。

配置、模板事务、菜单快照发布和命令 drainer 由同一个主程序状态协调器串行化。删除或停用模板/工具必须等待已经领取并完成验证的命令结束；尚未领取的命令按执行时的最新配置验证，引用已停用或删除记录时失败。

命令采用明确的 at-most-once 语义。领取后不自动重试：执行成功时先原子写入无路径的 `succeeded` result，再在 queue lock 内删除 processing；可判定失败时写入 `failed` result，再在 queue lock 内删除 processing。result 写入失败时保留 processing，后续启动把它视为中断而不是重放。

主程序每次启动先恢复 processing。若同 UUID 已有 result，只在 queue lock 内删除残留 processing，不改变既有结果；否则先写入无路径的 `unknown` result，再在 queue lock 内删除 processing。它不得猜测工具是否已经打开，也不得因找不到结果记录而重放外部动作。这个规则意味着副作用边界崩溃时可能丢失尚未执行的动作，但不会自动重复可能已经执行的动作。

`failed` 或 `unknown` result 需要用户反馈时，主程序先通过原子更新为它写入 `feedbackClaimedAt`，只有成功领取的调用可以展示一次错误。若进程在领取后、展示前崩溃，反馈可能缺失但不得重复；这是与命令一致的 at-most-once 取舍。成功结果不展示反馈。

超过 5 分钟的 pending 按过期失败处理并产生 result，再在 queue lock 内删除，不静默删除。result 最长保留 24 小时后清理；处理完成的命令文件按上述锁契约立即删除。统一日志只记录命令 ID、动作类型、状态和错误分类，不记录完整用户路径。相同 UUID 已有 result 时，任何重复 URL 都不执行动作；错误反馈是否已经领取只由 `feedbackClaimedAt` 决定。

`results` 最多保留 4,096 条记录。写入新 result 前依次删除超过 24 小时的记录、最早的 `succeeded`、最早且已领取反馈的 `failed`/`unknown`；不能为腾出空间删除 24 小时内尚未领取的错误。仍无空间时 drainer 在领取下一条 pending 前暂停，记录并显示一次 `resultStoreFull`，不得执行一个无法持久化结果的动作。result 被清理后，旧 URL 仍不能执行动作，因为对应 pending 已经删除；它只失去历史诊断记录。

## 10. 模板库

### 10.1 内置模板

内置模板随主程序资源发布，有稳定 ID 和不可删除的内容。用户只可以在第 7.1 节规定的固定分组内调整顺序或停用，不能修改应用内资源。每次发布前必须验证资源存在、扩展名正确，并对 OOXML ZIP 包检查以下明确入口和关系闭包：

- 三类文件都必须包含可解析的 `[Content_Types].xml`、`_rels/.rels`，根 relationship 必须指向实际存在的主部件。ZIP 条目不得使用绝对路径、`..` 路径穿越或重复规范化路径。
- DOCX 主部件必须是可解析的 `word/document.xml`，其 content type 和 relationship 类型必须匹配 WordprocessingML。
- XLSX 主部件必须是可解析的 `xl/workbook.xml`，至少引用一个实际存在且关系有效的 worksheet。
- PPTX 主部件必须是可解析的 `ppt/presentation.xml`，至少引用一张实际存在且关系有效的 slide。
- 发布记录保存三个二进制模板的 SHA-256；资源哈希变化必须重新执行真实应用验收。

Office 模板至少进行以下真实应用人工验证：

- `.docx` 可在 Microsoft Word 或 WPS Writer 中打开且不提示损坏。
- `.xlsx` 可在 Microsoft Excel 或 WPS Spreadsheets 中打开且包含一个空工作表。
- `.pptx` 可在 Microsoft PowerPoint 或 WPS Presentation 中打开且包含一张空白幻灯片。

如果测试机器只安装 WPS，则以 WPS 结果作为标准 OOXML 技术预览的最低验收，并在验证记录和下载页明确写明“Microsoft Office 未验证”。WPS 通过不能表述为 Microsoft Office 兼容性已经证明。RTF 资源还必须在当前受支持 macOS 的 TextEdit 中打开且不提示损坏。

### 10.2 自定义模板导入

用户通过文件选择面板选择一个普通文件。导入服务必须：

1. 拒绝目录、符号链接和其他特殊文件。
2. 为模板生成稳定 UUID。
3. 使用 `O_NOFOLLOW` 打开源文件并以 `fstat` 确认是最大 64 MiB 的普通文件；记录 device、inode、类型、大小、mtime 和 ctime，从该文件描述符按声明大小有界复制并确认随后是 EOF，同时计算 SHA-256。随后把同一描述符重置到偏移 0 做第二次有界读取，只计算并确认第二个 SHA-256、大小和 EOF；两次内容摘要或身份/修改信息不一致则失败。该双读规则用于拒绝复制过程中产生的非稳定内容，不把一次读取的结果宣称为源文件快照。
4. 把文件内容复制到 App Group 的模板目录，而不是保存对原文件的依赖。
5. 不复制原文件的执行位、ACL、资源 fork 或扩展属性；托管内容和创建出的文件使用 `0666 & ~umask`，不得包含执行位。目标目录自身的继承 ACL 可以生效，但不能从模板源复制 ACL。无法满足这些属性约束时导入失败。
6. 保存原文件最后一个 path extension 的原始大小写。扩展名不含前导点，必须为 1 至 32 个扩展字素，不得包含 `/`、`:`、控制字符或路径分隔符；不符合限制时拒绝导入。
7. 对没有 path extension 的文件不附加扩展名。`.env` 这类只有前导点的 dotfile 视为“无扩展名”，默认显示名称保留 `.env`。
8. 默认显示名称使用原文件名去掉最后一个扩展名；去除后为空时使用完整文件名。用户修改后的名称仍受第 9.2 节限制。

默认显示名称在导入事务开始前就使用第 9.2 节的同一验证器检查：去除首尾空白后必须为 1 至 80 个扩展字素，不能包含换行或其他控制字符。默认值不做截断或隐式替换；不符合限制时拒绝导入并不创建 `importing` 记录。

所有自定义模板创建出的目标文件仍使用本地化 `未命名` / `Untitled` 作为基础名称，再附加模板记录中的扩展名。修改模板显示名称只影响菜单，不改变创建文件名称规则。

导入是可恢复事务：先持久化 `importing` 记录，再把内容写入 `templates/.staging/<TemplateID>/content`，严格执行 `write loop -> 设置权限和必要属性 -> fsync(fd) -> close 并检查错误`，随后从路径重新打开并验证大小、SHA-256 和属性，再把预期大小与 SHA-256 原子写回 `importing` 记录。只有该记录持久化成功，才以不覆盖既有目标的原子 rename 把整个 staging 目录发布为 `templates/<TemplateID>`；最终 UUID 目录已经存在时导入失败，不替换其内容。最后把记录原子更新为 `active` 并发布菜单快照。任一步失败都不发布菜单项。只有 current 配置完整有效时，启动恢复才删除无对应 `importing` 记录的 staging 目录；`importing` 记录只有在最终内容与其持久化的大小、SHA-256 和属性全部匹配时才可完成提交，否则删除归属于该 UUID 的 staging/最终残留和记录。使用 previous 回退时未知目录保持原状并报告，不做破坏性推断。

删除先把记录原子改为带重试信息的 `deleting` 状态并发布不含该模板的新快照，再删除托管目录，成功后删除记录。删除失败时保留 `deleting` tombstone，由每次启动和用户主动重试继续清理；同一 UUID 在清理完成前不得复用。启动时还清理没有任何 `active`、`importing` 或 `deleting` 记录的最终模板目录。`active` 记录缺少内容时立即停用、从快照移除并显示可修复错误，不允许继续创建。

### 10.3 创建文件的原子性

主程序使用命令中的 `targetDirectoryIdentity` 和不跟随最终符号链接的 `lstat` 重新验证目标目录，并逐级以不会跟随符号链接的方式打开路径分量；只对最终分量使用 `O_DIRECTORY | O_NOFOLLOW` 不足以满足本规格。打开后用 `fstat` 确认 directory file descriptor 与 `targetDirectoryIdentity` 相同。之后的临时创建、属性设置、名称限制查询和最终提交全部相对该 directory file descriptor 执行，不能重新使用可能发生竞态替换的绝对目标路径。主程序先以包含命令 UUID、随机后缀和固定应用前缀的隐藏临时名称独占创建一个普通文件，只把模板内容写入一次，并严格执行 `write loop -> 设置普通文档权限和必要属性 -> fsync(fd) -> close 并检查错误`。所有正式创建文件使用 `0666 & ~umask`，不得带执行位。只有这些步骤全部成功才使用创建命令冻结的语言依次生成候选名称，通过 `fpathconf(directoryFD, _PC_NAME_MAX)` 拒绝 UTF-8 文件名超过目标卷限制的候选，最多尝试第 2.2 节规定的 10,000 个候选。

每次提交使用 SDK 自 macOS 10.12 公开声明的 `renameatx_np(directoryFD, temporaryName, directoryFD, candidateName, RENAME_EXCL)`；可以先用公开的 `URLResourceKey.volumeSupportsExclusiveRenamingKey` 快速判断卷能力，但最终以实际系统调用结果为准。`EEXIST` 只表示候选冲突，原临时文件必须保持不变并继续尝试下一个编号；`ENOTSUP`、`EINVAL` 或等价的“不支持不覆盖提交”错误直接映射为 `atomicCommitUnsupported`，其他错误映射为 `atomicCommitFailed`，都不得回退为允许覆盖的 rename/move。若 `_PC_NAME_MAX` 返回不可用或无法确定名称上限，也必须以 `nameLimitUnknown` 失败，不能猜测限制。

候选已存在时保留本次临时文件并尝试下一个编号；成功提交或耗尽候选后不再复用它。写入、同步、文件名限制或提交发生其他错误时删除临时文件并报告；删除也失败时错误必须包含“目标目录中可能留有隐藏临时文件”的可执行清理提示，但日志仍不记录完整路径。恢复 processing 时，主程序只在该命令冻结的目标目录内清理同时匹配固定前缀、该命令 UUID 和合法临时名语法的文件；它不遍历其他用户目录。无法从 processing 安全推导目标目录时不执行自动删除，只报告可能残留。

阶段 0 必须在启动磁盘实际文件系统验证该公开提交原语的成功、目标冲突、并发竞争和崩溃行为。若某个外置卷不支持相同语义，该卷上的文件创建必须在执行时以明确错误拒绝；不能退回会覆盖或暴露非空模板半成品的实现。空模板的零字节最终文件是预期内容。

创建成功后：

1. 确认最终提交成功且所有写入 descriptor 已关闭。
2. 使用 `NSWorkspace.shared.activateFileViewerSelecting([newURL])` 请求 Finder 选中它。
3. 不发送 Return、不模拟键盘，也不自动打开编辑器。

Finder 选择是文件创建成功后的独立 UI 动作。公开 API 没有提供可依赖的完成结果，因此文件已经原子提交后不得因“未观察到选择”删除或重复创建；人工验收若在支持范围内稳定无法选中新文件，则发布门禁失败并更新产品承诺，不能伪造键盘补救。

## 11. 开发工具注册与打开

### 11.1 Visual Studio Code

主程序使用 bundle identifier `com.microsoft.VSCode` 通过 `NSWorkspace` 定位稳定版 Visual Studio Code。找不到时菜单仍可根据最后快照显示，但执行会提示未安装或已移动，并引导用户在设置中检查；首版不自动把 VS Code Insiders 当作稳定版。

内置 VS Code 明确跟随 Launch Services 为该 bundle identifier 选出的应用 URL；主程序重新验证候选确实是 `CFBundlePackageType = APPL`、bundle identifier 精确匹配且可由 `NSWorkspace` 打开。存在多个稳定版副本时不承诺选择其中哪一份，发布验证环境必须移除旧副本；需要固定特定副本的用户应把它作为自定义工具添加。

调用 `NSWorkspace` 的 URL 打开接口，把一个或多个 Finder URL 交给 VS Code。首版不依赖 `code` 命令、不创建 shell 进程，也不擅自添加 `--new-window`、`--reuse-window` 等参数，由 VS Code 自己决定窗口复用行为。

### 11.2 自定义开发工具

“添加开发工具”文件选择面板只允许选择 `.app`，拒绝符号链接和 alias。主程序验证 `CFBundlePackageType = APPL`、主 executable 存在且为可执行普通文件、`NSWorkspace` 可以打开该 Bundle，并保存：

- 稳定工具 UUID。
- 显示名称。
- bundle identifier（存在时）。
- 应用 URL 的普通持久书签数据。主程序非沙盒，不创建也不声称依赖 security-scoped bookmark。
- 排序和启用状态。

执行时先解析普通书签并再次执行上述 Bundle 校验；书签返回 stale 但 URL 仍有效时，先原子刷新书签再打开。书签无法解析、解析到非应用或 bundle identifier 与已保存的非空值不一致时，主程序不得自动打开按 bundle identifier 找到的其他副本，而是把工具标记为不可用、从菜单快照移除并提示用户重新绑定。`NSWorkspace` 找到的同 bundle identifier 候选只能显示在设置页供用户确认；用户确认后才替换书签并重新启用。菜单快照不包含书签和应用路径。

设置页支持添加、显示名称修改、排序、启用/停用、重新绑定和删除。重复选择同一标准化路径时复用已有记录；相同 bundle identifier 但路径不同，或 bundle identifier 为空但书签资源不同，不得静默合并，设置页要求用户选择“替换现有记录”或取消。无论选择哪条路径，都不能产生两个指向同一标准化应用 URL 的菜单项。

自定义工具使用 `NSWorkspace` 的“以指定应用打开 URL 集合”接口。首版不提供命令行参数编辑，因此不会执行用户文件中的文本，也不会把文件路径插入 shell 命令。

### 11.3 Terminal Service

Terminal launcher 根据设置把目标目录作为文件 URL 写入专用 `NSPasteboard`，然后调用对应的公开 Service 名称。返回失败时不使用 AppleScript、`osascript` 或辅助功能补救。

正式实现只能使用阶段 0 已回填到版本化 Terminal Service descriptor 表的公开调用 API、精确 Service 名称和 pasteboard 类型；运行时根据当前 macOS build 与系统语言精确查表，不提供未验证的动态服务发现，也不能猜测本地化字符串。descriptor 缺失时菜单构造即可禁用 Terminal；Service 被用户禁用或调用失败只能在执行阶段判定并产生明确错误，菜单构造不得为此查询或等待。调用 API 返回成功只表示 Service 接受请求；人工验收必须另行观察窗口/标签页结果。

设置值是版本化枚举：

- `newWindow` -> 当前 descriptor 中语义为 `newWindow` 的 Service
- `newTab` -> 当前 descriptor 中语义为 `newTab` 的 Service

首版默认值是“新窗口”；设置缺失或非法时也回退为“新窗口”。如果选择“新标签页”但 Terminal 当前没有窗口，实际结果由 Terminal Service 决定，通常会创建可承载标签页的窗口。本工具不伪造窗口状态，也不尝试反向读取或覆盖 Terminal 自己的偏好。

### 11.4 外部工具副作用完成契约

VS Code、Terminal 和自定义 `.app` 的成功边界统一定义为“公开 API 接受 URL 交付请求”：

- `NSWorkspace` 调用有同步失败结果时，返回失败即写入 `failed`；异步 completion 明确报告错误时写入 `failed`，无错误完成时写入 `succeeded`。
- Terminal Service 的公开调用返回成功即表示 Service 接受请求并写入 `succeeded`；窗口是否出现、是否复用窗口以及标签页是否实际建立不纳入本工具的成功保证。
- 调用 API 没有可观察 completion，或主程序在调用返回与 completion 之间终止时，恢复流程写入 `unknown`，不得自动重试。实现不得用固定睡眠时间猜测第三方应用状态。
- 外部 API 调用必须在主程序状态协调器之外的受控执行队列中运行，并向协调器返回一次性完成事件；完成事件丢失、超时或重复到达都不能导致第二次外部调用。阶段 2 测试必须覆盖这些边界。

## 12. 设置界面

现有“右键扩展”禁用占位替换为真实设置页，保持当前设置窗口的 sidebar/detail 结构。页面包含：

- Finder 扩展状态区：使用 macOS 10.14 起公开的 `FIFinderSyncController.isExtensionEnabled` 显示查询时刻的“已启用/未启用”，并单独显示最近一次扩展 heartbeat 的活动时间。
- “管理 Finder 扩展”按钮：调用公开的 `FIFinderSyncController.showExtensionManagementInterface()`。
- 内置文件类型列表：排序和启用/停用。
- 自定义模板列表：添加、修改显示名称、排序、启用/停用和删除。
- Terminal 打开方式分段控件：新窗口 / 新标签页。
- Terminal 当前没有匹配的 Service descriptor 时显示不可用状态；用户仍可保留其启用偏好，但不能从设置页绕过 descriptor 直接提交调用。
- 开发工具列表：Terminal、Visual Studio Code 和用户添加的应用。
- Terminal 和 Visual Studio Code：分别启用/停用，顺序固定。
- 自定义工具操作：添加、重新绑定、修改显示名称、排序、启用/停用和删除；排序只作用于自定义工具子菜单。

设置页在首次出现、主程序重新变为 active，以及从扩展管理界面返回时重新查询 `isExtensionEnabled`；该值只表示用户在系统中的当前启用选择，不证明 Finder 已经加载扩展、目录覆盖有效或 App Group 正常。heartbeat 只表示最近实际活动，也不能替代启用状态：例如“已启用，尚未检测到活动”和“未启用，上次活动于……”都是合法组合。应用不缓存启用状态为长期事实，不自动运行 `pluginkit`，不自动重启 Finder。

相关设置变化立即写入主程序设置存储，并重新发布原子菜单快照。模板内容复制完成前不发布对应菜单项。

内置模板设置按第 7.1 节显示两个固定分组，只支持组内排序。自定义模板是第三个独立排序域。设置 UI 不提供跨组拖放，也不把 Terminal、VS Code 与自定义工具显示成一个可自由混排的列表。

## 13. 错误处理与用户反馈

### 13.1 扩展侧

扩展不能弹出阻塞 Finder 的复杂对话框。它采用以下降级：

- App Group 不可用：不发布业务菜单，记录结构化错误。
- 菜单快照缺失：显示禁用的初始化提示。
- 新快照损坏：继续使用进程内最后一份有效快照。
- 命令文件写入失败：不打开 URL Scheme，记录错误并发出系统提示音。
- URL Scheme 打开失败：保留 pending 文件；主程序下次启动或收到任意合法唤醒时仍会排空，不重复提交动作。

### 13.2 主程序侧

成功创建或成功打开工具时保持安静；创建文件仅让 Finder 选中新文件。如果一条未过期命令由本次有效 URL 唤醒直接触发并立即失败，主程序可以激活一个最小错误提示，但不得顺带打开设置窗口。由 pending 目录观察器、普通应用启动或 processing 恢复发现的失败不抢占 Finder 焦点，保留未领取的 result，用户下一次主动打开主程序时再显示。以下用户发起的失败由主程序显示一次非重复错误：

- 目标目录不存在、只读或卷已弹出。
- 模板内容缺失或损坏。
- Visual Studio Code 或自定义工具找不到。
- Terminal Service 不可用或调用失败。
- 命令过期、协议版本不支持或上下文无效。
- 上一次进程中断导致结果未知。

错误信息说明失败动作和可执行下一步，不暴露内部 JSON 或完整 entitlement 内容。只有确定即将显示错误时才领取 `feedbackClaimedAt`；相同命令 ID 最多显示一次。后台发现的失败不提前领取，用户下一次主动打开主程序或设置页时可以查看最近一次未领取错误。

主程序收到 Finder 命令 URL 时默认不激活主窗口；只有用户主动打开主程序、设置页或 Finder 扩展管理按钮时才激活 UI。首次访问 Desktop/Documents/Downloads 或外置卷若系统显示隐私权限提示，提示由执行文件创建的主程序触发；用户拒绝时显示一次“无法访问目标位置”的错误，并保留原命令的 `failed` result，不重试或把权限提示转交扩展。

### 13.3 隐私和安全

- 所有菜单、模板和命令数据只保存在本机。
- 不上传文件名、路径、模板或工具列表。
- Finder 目标路径只存在于短生命周期命令文件中，处理后删除；自定义开发工具的应用路径会编码在 `configuration.json` 的普通持久书签中，直到用户删除或重新绑定该工具。
- URL Scheme 不携带路径。
- URL Scheme 只用于唤醒；它不是认证边界，主程序仍必须验证 pending 文件、命令 schema、目标 URL 和登记 ID。
- 命令不能指定任意可执行文件或 shell 文本，只能引用主程序已登记的工具 ID。
- 文件创建永不覆盖已有文件。
- 模板导入不保留执行权限，避免“创建文件”隐式产生可执行程序。

本版本的安全前提是“同一登录用户下的其他非沙盒进程属于可信环境”。App Group、普通持久书签和 URL Scheme 都不能证明命令来自 Finder Sync 扩展；能够写入共享容器的进程理论上可以伪造合法 schema、URL 和登记 ID。下载说明和安全评审必须明确这一威胁模型；如果产品要求抵抗同用户恶意进程，当前方案不得发布，必须另行设计带调用方认证的 IPC 或签名命令。

## 14. 生命周期和恢复

- 主程序启动时只通过 App Group API 取得容器，并以不会跟随符号链接的方式创建固定子目录后按第 9.3 节规定的 `flock(fd, LOCK_EX | LOCK_NB)` 契约锁定 `state/host.lock`，在进程生命周期内持续持有 descriptor。已有实例持锁时，当前实例不读取或修改其他共享状态并直接退出；持锁实例通过第 9.4 节的 pending 目录观察器领取扩展已经写入的命令。取得锁后先按第 9.1 节验证 current/previous 配置，再恢复 processing、处理过期命令和验证内置模板；只有 current 完整有效时才执行模板 staging/孤儿目录的破坏性清理。命令 staging 只按第 9.3 节的 10 分钟规则在 queue lock 内回收，不受配置回退驱动；最后发布菜单快照。
- 扩展启动时解析容器和菜单快照，注册 Finder 根目录，并写入节流后的 heartbeat。
- 扩展被 Finder 终止后不需要恢复内存状态；下次启动从最新快照重建。
- 主程序未运行时，扩展仍可从快照构造菜单；点击动作写入命令并通过 URL Scheme 启动主程序。
- 主程序启动或收到任意合法唤醒时都扫描 pending，按 `createdAt`/UUID 顺序串行领取；每条命令采用 at-most-once，重复 URL 不重复执行。
- 外置卷在菜单打开后弹出时，主程序把它当作正常执行失败，不重试到其他目录。
- 菜单快照 schema 不支持时，扩展不猜测字段含义，回退到最后有效版本或初始化提示。

处理 processing、template staging、隐藏创建临时文件和 result 的清理都必须使用本应用固定前缀、UUID 和状态元数据进行归属判断；不能按年龄删除目录中任意未知文件。

## 15. 测试设计

### 15.1 自动测试

共享领域测试：

- 空白处、单文件夹、单文件和多选目标解析矩阵；分别覆盖 `contextualMenuForContainer`/`targetedURL()`、`contextualMenuForItems`/`selectedItemURLs()`、空值、两个 API 同时有值和未记录的 API 组合。
- 多选 Terminal 相同目录、不同目录、文件夹加子文件和重复 URL。
- package、`.app`、普通目录、卷根、符号链接、Finder alias 和链接目标变化；VS Code/自定义工具始终收到冻结的原始 URL。
- 菜单构造后 Finder 选择变化、项目移动、类型变化、同路径同类型对象替换、目标目录替换、中间路径分量变成符号链接或所属卷弹出；动作不得改用新选择，identity 或类型变化必须拒绝。
- 非文件 URL、远程 file host、缺少父目录、目标消失、未来时间和无效上下文。
- 原始数组 256/257 项边界、重复 URL 去重后的稳定顺序、单 URL 16 KiB 和命令 1 MiB 限制。
- 菜单快照 schema、512 KiB 限制、语言白名单/英文回退、Terminal `availability` 合法值与 descriptor 缺失禁用状态、固定分组、分组内排序、并列 `sortOrder` 的 ID tie-break、停用过滤、分隔线消除、全部模板/工具停用空状态和损坏快照回退。
- 命令编码解码、UUID/文件名匹配、5 分钟有效期、语言冻结、上下文枚举、item/target directory identity 冻结与未知 action 拒绝；规范 UUID 但无法解码 action 的命令必须产生 `action = unknown` 的 `failed` result。
- URL 丢失、合并、重复和乱序时，合法唤醒排空全部 pending；正常冷启动的独立 startup scan 能排空既有 pending，运行中收到非法 URL 不额外调度扫描。
- pending observer 先 arm 再 scan 的窗口、事件合并、事件丢失和 source 重建；每种情况都必须 full rescan 并 drain 到 quiescent。
- 多个扩展进程并发“计数加预留”时使用同一 queue lock，`staging + pending + processing` 的 255/256 边界不能超额；分别覆盖 `queueBusy`、`queueFull` 和预留成功。
- staging 发布与 pending drainer 并发；drainer 不读取半写 staging，只有完成 `fsync`、成功 close 和原子 rename 后才能解码命令。
- 扩展在预留、写入、`fsync`、close、rename 和唤醒各边界崩溃；遗留 staging 未满 10 分钟不清理，超过 10 分钟后只按规范名称/普通文件/无同 UUID 活跃状态规则在 queue lock 内回收。
- pending/processing 256 条容量边界、超限拒绝和有界损坏文件读取；删除任何规范 staging/pending/processing 前必须持有 queue lock 并二次确认。
- 原子领取保证重复 URL 和重复扫描最多开始一次；按 `(createdAt, UUID)` 稳定排序。
- 在领取前、领取后、外部副作用前后、result 写入前后和 processing 删除前后注入进程终止，验证 at-most-once、`unknown` 恢复、已有 result 优先和绝不自动重放。
- `feedbackClaimedAt` 原子领取保证错误最多展示一次，包括领取后、展示前崩溃。
- result 的 24 小时/4,096 条清理顺序、未领取错误保护和 `resultStoreFull` 时不领取/不执行新命令。

文件创建测试：

- `未命名.ext`、`未命名 2.ext` 及连续冲突命名。
- 中文/英文语言冻结、无扩展名、dotfile、32/33 扩展字素、文件名长度不足和 10,000 次冲突上限。
- 大小写不敏感卷语义通过可注入文件系统 fake 覆盖。
- 大小写敏感与不敏感真实卷各至少验证一种；硬件/卷格式不可用时明确记录未覆盖。
- 同目录临时写入和不覆盖原子提交；竞争期间候选被抢占时继续编号，不覆盖已有文件。
- 写入失败、`fsync` 失败、close 失败、磁盘满、提交 rename 不支持和临时文件删除失败的结果与提示。
- 在临时创建、写入、设置属性、`fsync`、close 和最终 rename 各边界注入终止；非空模板不得留下零字节/截断最终文件，清理不得删除未知文件。覆盖 `_PC_NAME_MAX` 未知、`EEXIST` 冲突、`ENOTSUP`/`EINVAL` 不支持和其他提交错误的结果分类。
- 14 个内置模板的扩展名和基础内容验证。
- DOCX、XLSX、PPTX 是无路径穿越和重复规范化条目的可解析 ZIP，content types、根 relationship、主部件及 worksheet/slide 关系闭包有效，资源 SHA-256 与发布记录一致。
- RTF、JSON、XML、HTML 和 YAML 的最小格式有效性；RTF 另做 TextEdit 人工打开验证。
- 自定义模板导入后删除原文件仍可创建。
- 拒绝目录、符号链接、特殊文件、超过 64 MiB 和导入期间 device/inode/大小/mtime/ctime、双读 SHA-256 或提前/延后 EOF 变化的文件；复制流 SHA-256 与重新打开的 staging 内容必须一致，不复制执行位、ACL、xattr 和资源 fork。覆盖默认显示名称含控制字符、超长或空白的拒绝路径。
- 导入在 `importing`/摘要持久化/staging/不覆盖 rename/最终目录/`active` 每个边界终止后的恢复；最终 UUID 目录冲突不得覆盖，删除 tombstone 重试、孤儿 staging/最终目录回收和 active 内容缺失停用。

工具测试：

- Terminal 设置到阶段 0 回填的版本化 Service descriptor 表的精确映射；覆盖 English/简体中文和支持的最低/当前系统版本，以及 descriptor 缺失时菜单禁用和错误文案。
- Terminal 只接收一个解析后的目录。
- VS Code 单文件、文件夹和多选 URL 转发；覆盖 synchronous failure、异步 completion 成功/失败、completion 丢失、超时和主程序终止后的 `unknown` 恢复。
- 自定义工具普通书签成功、stale 刷新、内容失效、bundle ID 变化、同 bundle ID 多副本、无 bundle ID 和用户确认重新绑定。
- 拒绝 alias、符号链接、非 `APPL`、缺少可执行文件和不可打开 Bundle。
- 未登记 tool ID、已停用工具和重复工具记录拒绝。

设置和文案测试：

- 右键扩展替换占位后出现在设置导航。
- 中英文菜单、设置标题、错误和状态文案。
- `isExtensionEnabled` true/false 与 heartbeat 有/无/过期的独立组合；设置页出现、应用重新 active 和从管理界面返回时重新查询。
- “管理 Finder 扩展”精确调用公开管理界面 API，不运行 `pluginkit` 或重启 Finder。
- 内置项目默认顺序、固定分组内排序、启停、空分组分隔线和非法跨组设置回退。
- Terminal/VS Code 固定顺序与独立启停，自定义工具仅在子菜单内排序。
- Terminal 默认值和非法枚举回退新窗口。
- 设置变化触发菜单 snapshot revision 增加。
- 模板/工具数量和显示名称边界；超限设置不写入 `configuration.json` 或快照。
- 干净 App Group 的首次初始化默认配置、`initialization.json` 的 `starting`/`complete` 恢复、首份 current rename 前后和 marker 更新前后崩溃；保留既有 App Group 数据重新安装、marker/菜单快照/模板/命令任一既有状态或两个配置副本损坏时均不得写入默认值。
- `configuration.json` schema/2 MiB 限制、current/previous 回退、两个副本都损坏时不覆盖旧状态、旧 schema 幂等迁移和未知未来 schema 拒绝，以及后续配置更新各原子替换边界的崩溃恢复。

### 15.2 Bundle 与签名自动检查

- 主程序包含 `Contents/PlugIns/RightClickFinderExtension.appex`。
- 主程序、扩展 executable 和 Info.plist 均存在且合法。
- 外层 `CFBundleExecutable` 必须为 `DockHoverPreviewProbe`，并与实际主 executable、SwiftPM product name 一致；阶段 0 Bundle 不得因此启用正式业务能力。
- SwiftPM、主程序 Info.plist 和扩展 deployment target 均为 macOS 14.0。
- 外层主程序 Info.plist 包含非空的 `NSDesktopFolderUsageDescription`、`NSDocumentsFolderUsageDescription`、`NSDownloadsFolderUsageDescription` 和 `NSRemovableVolumesUsageDescription`，`en` 与 `zh-Hans` 的 `InfoPlist.strings` 都能为四项解析出非空本地化文案。
- 主程序和扩展 bundle identifier 精确匹配设计值。
- 两者实际签名 entitlements 包含同一个 App Group。
- 主程序实际 entitlements 不包含 `com.apple.security.app-sandbox`；扩展实际 entitlements 包含 App Sandbox。
- 扩展声明正确的 Finder Sync extension point 和 principal class。
- 外层 `CFBundleURLTypes` 包含稳定 URL name、合法 bundle type role 和唯一的 `zongmactools` scheme；注册项与当前主程序 bundle identifier 一致。
- 先签扩展、后签主程序后通过 `codesign --verify --deep --strict`。
- release ZIP 包含已签名的完整 `.appex`，解压后再次通过检查。
- `lipo -archs` 或等价检查记录主程序和扩展实际架构且两者一致；发布元数据和下载页只承诺产物实际包含的架构。

### 15.3 探针和人工验收

阶段 0，架构门槛：

阶段 0 的可执行产物只包含：最小 `.appex` 与主程序 probe host、冻结 Finder 上下文的诊断输出、带 staging/pending/processing/result 恢复的最小队列、一个只递增专用 probe counter 的可观察副作用、Terminal Service 调用 probe，以及在专用测试目录执行的 `RENAME_EXCL` 原子发布 probe。队列副作用不得创建用户文件或打开第三方工具；probe counter 用于证明重复/丢失/崩溃路径是否满足本规格的 at-most-once 取舍。该阶段不创建 14 个正式模板、自定义模板库、VS Code/自定义工具注册、正式 `configuration.json` 或设置 UI。

以下全部阶段 0 强制项必须分别在 macOS 14 的最新可用小版本和发布时当前支持的最新 macOS 上执行；同一个系统版本不能同时充当最低与当前版本证据。每份记录必须包含 OS build、硬件与 CPU 架构、主程序/扩展实际签名和 entitlements。Terminal 子矩阵还必须在 English 与简体中文系统语言下各执行一次，记录实际 Service 名称、发现方式和 pasteboard 类型，不能只在一种语言下推断另一种语言。

1. 导出实际 entitlements，确认非沙盒主程序与沙盒 Finder 扩展通过 App Group 双向往返。
2. Finder 空白、单选文件夹、单选文件、多选、package、`.app`、符号链接、alias 和卷根上下文读取；分别记录两种 `FIMenuKind` 的 `targetedURL()`/`selectedItemURLs()` 实际组合，验证 API 空值、同时有值和原始数组 256/257 边界；菜单打开后改变选择、替换同路径对象或改变 resource identity 不能改变或重新解释冻结命令。
3. URL Scheme 在主程序运行和未运行时都能唤醒；连续写入多条命令后模拟一个 URL 丢失、重复和乱序，主程序仍只执行一次并排空全部 pending。
4. 验证 URL Scheme 在开发目录副本、`/Applications` 发布候选、旧副本和替换安装场景中的实际解析目标；发布环境不能保留可争用同一 scheme 的副本。
5. 验证 `/` 或明确卷根注册能覆盖用户主目录、桌面、文稿和普通项目目录。
6. 在启动磁盘验证同目录、不覆盖原子提交的成功、冲突、并发竞争和边界崩溃；不能稳定复现则停止文件创建实现。
7. 按第 2.5 和 5.5 节完成 Terminal Service 专项矩阵，不以字符串映射单元测试代替。
8. 主程序、Finder 和扩展重启后的最小探针状态、App Group 队列状态、processing/result 恢复和重复验证；不验收正式设置、模板或工具注册的保留。
9. ad-hoc 重建、替换和重新启用扩展后的重复验证。
10. 按第 7.4 节完成 1、64、256 项的冷/热菜单性能测量并满足 p95 门槛。
11. 通过最小探针或测试 harness 使用公开 `isExtensionEnabled` 在系统界面启用/停用前后读取正确点时状态，并验证该状态与 heartbeat 分开记录；阶段 0 不实现正式设置页。
12. 使用真实沙盒扩展和非沙盒主程序验证 `flock` 互斥；并发扩展进程覆盖预留成功、`queueBusy`、`queueFull` 和 256 条不超额，强制终止发布者后验证未满 10 分钟不清理、超过 10 分钟按规则回收以及 probe counter 不重复递增。
13. 用阶段 0 最小产物生成与发布候选相同结构和签名顺序的 ad-hoc ZIP；在没有旧副本、旧 URL Scheme 注册和旧 App Group 数据的干净用户/VM 中通过浏览器下载或等价方式保留隔离属性，移动到 `/Applications`，按系统提供的 Control-点击“打开”或“隐私与安全性”方式人工放行并手动启用扩展，再重复 App Group、Finder 菜单/上下文、URL 冷热唤醒和最小队列往返。无法完成这条路径时阶段 0 失败。

阶段 1，文件创建：

1. 在本地普通目录的空白处、文件和文件夹上下文创建全部内置类型；package、链接和 alias 按冻结矩阵处理。
2. 验证冲突编号、10,000 次上限、并发名称竞争、Finder 选中和 Return 手动重命名。
3. 多选时创建菜单禁用。
4. 导入自定义模板，删除原件后仍可创建；在导入、删除和创建各事务边界强制终止后验证恢复和孤儿清理。
5. 在 WPS 中打开 DOCX、XLSX、PPTX，确认无损坏提示；安装 Microsoft Office 的机器还要分别验证并记录版本，否则验收记录和下载页标记 Microsoft Office 未验证。
6. 用 TextEdit 打开内置 RTF，确认不提示损坏。
7. 只读目录、隐私权限拒绝、磁盘满、目标删除、提交原语不支持和卷弹出时显示正确错误；非空模板不留下可见的零字节/截断最终文件。

阶段 2，开发工具：

1. Terminal 新窗口和新标签页各验证一次，并记录公开 Service 调用返回的接受/失败状态；不以窗口可见性替代该状态。
2. Terminal 未运行/已运行、有窗口/无窗口、Service 启用/禁用，以及单文件、文件夹、相同目录多选和不同目录多选的状态正确；新标签页但无窗口时按第 11.4 节记录，不把不可观察的窗口结果伪造为失败。
3. VS Code 收到单文件、文件夹和多个选中项；分别验证 API 同步失败、completion 成功/失败、completion 超时和调用边界进程终止后的 result 状态。
4. 添加另一款 `.app`，验证添加、排序、停用、移动、stale bookmark、同 bundle ID 多副本、用户确认重新绑定和删除；分别验证 API 接受/拒绝、completion 超时和 `unknown` 恢复。验收只声称系统接受 URL 交付，不声称任意应用处理了全部 URL。

阶段 3，覆盖范围：

1. 用户主目录、桌面、文稿和普通项目目录。
2. Desktop、Documents 和 Downloads 分别在重置过 TCC 状态的干净用户/VM 中验证首次允许、首次拒绝和允许后撤销访问时的主程序行为及中英文用途说明；每个状态都以真实文件操作结果判定，不能从缓存配置推断。Finder 命令冷启动不无故显示主设置窗口或抢占焦点。
3. 正常挂载的外置磁盘在重置过 TCC 状态的干净用户/VM 中分别验证首次允许、首次拒绝和允许后撤销访问时的 `NSRemovableVolumesUsageDescription` 文案、菜单覆盖、读写权限和不覆盖原子提交；硬件不可用时记录 `blocked / not available`，且在验证完成前下载页不得承诺外置卷支持。
4. iCloud、OneDrive、Dropbox 和文件提供程序目录只记录观察结果，不据此扩大支持承诺。
5. 自定义 `.app` 位于 Desktop、Documents、Downloads 或外置卷时，分别验证普通书签解析、Bundle 校验、`NSWorkspace` 打开请求和 TCC 拒绝/撤销后的错误路径；不得把目标目录访问的授权假定为对应用 Bundle 位置的授权。

### 15.4 网站技术预览分发验证

本机开发目录中的探针通过不等于网站下载可用。第 15.3 节第 13 项已在阶段 0 验证最小隔离 ZIP 的架构路径；本节是在正式业务完成后，对完整发布候选重复并扩展该验证。发布前必须在没有旧应用副本、旧 URL Scheme 注册和旧 App Group 数据的干净用户账户或干净 VM 中验证首次安装；升级保留行为在另一个具有旧版本数据的环境中单独验证：

1. 生成 release ZIP 和 SHA-256。
2. 通过浏览器下载或用等价方式保留下载隔离属性。
3. 解压并移动到 `/Applications`。
4. 使用系统当时提供的 Control-点击“打开”或“隐私与安全性”中的“仍要打开”处理首次 Gatekeeper 提示，不指导关闭 Gatekeeper。
5. 首次启动主程序并打开系统 Finder 扩展管理界面。
6. 用户手动启用扩展后，重新执行 App Group、菜单、文件创建和 Terminal 最小流程。
7. 替换为下一 build 后验证扩展注册和设置/模板保留行为；若该 build 提升 configuration schema，必须在真实旧 schema 数据上验证幂等迁移、失败回退和未知未来 schema 拒绝。
8. 至少在 macOS 14 的最新可用小版本和发布时当前支持的最新 macOS 各验证一次；同一版本不能同时充当最低系统与当前系统证据。
9. 记录主程序和扩展的实际 CPU 架构。首版产物由固定构建机器决定，不默认声称 Universal 2；仅在主程序、扩展和所有嵌入二进制都同时包含 `arm64` 与 `x86_64` 且两类机器完成 smoke test 后，才可宣传为 Universal。
10. 验证主程序因 Dock 预览能力产生的系统辅助功能/屏幕录制提示与 Finder 文件创建的目标目录访问提示在下载说明中被准确区分；不得声称 Finder 功能本身需要前两项权限。

技术预览下载页必须明确：未使用 Developer ID、未公证、首次打开和扩展启用需要用户操作、仅承诺经过上述矩阵验证的 macOS 14 或更新版本与 CPU 架构、同一登录用户下其他非沙盒进程属于可信环境，以及云盘、未验证外置卷、未验证 Microsoft Office 等实际限制。

## 16. 实施顺序和停止条件

实施计划必须按以下阶段拆分，不能越过失败门槛：

1. **阶段 0 平台探针**：只建立最小 `.appex`、entitlements、App Group 往返、Finder 上下文/目录覆盖/菜单性能、URL Scheme 冷热启动、观察器和最小队列/恢复探针。队列唯一业务无关副作用是递增专用 probe counter，另有 Terminal Service probe 和启动磁盘专用测试目录中的不覆盖原子发布 probe；必须以浏览器隔离属性安装的 ad-hoc 最小 ZIP 在干净环境重新验证扩展加载与基本往返。不实现正式模板、用户文件创建、VS Code/自定义工具注册、正式配置模型或设置 UI。
2. **探针评审**：逐项记录通过、失败或明确允许的硬件不可用，回填实际 OS/架构/签名/entitlements/API 输入输出和日志；所有强制项通过后再次评审本规格，未经评审不得进入第 3 步。
3. **共享协议和纯领域模型**：菜单快照、命令、目标解析及测试。
4. **主程序文件创建能力**：模板库、命名、原子创建和 Finder 选择。
5. **开发工具能力**：Terminal、VS Code 和自定义应用。
6. **Finder 菜单和设置页集成**：替换占位并连接完整数据流。
7. **Bundle、签名和人工验收**：本地目录、外置盘和真实办公文件。
8. **网站分发 smoke test**：从隔离 ZIP 安装并启用扩展。

停止条件：

- App Group 探针失败。
- URL Scheme 无法从 Finder 扩展可靠唤醒主程序。
- 运行中或冷启动时无法通过 URL/目录观察可靠排空 pending，或重复通知会让同一命令开始两次。
- Finder Sync 的公开目录注册无法覆盖普通本地目录。
- Finder 空白/单选/多选无法通过公开 API取得并冻结本规格矩阵要求的上下文。
- `menu(for:)` 在启动磁盘本地目录无法满足第 7.4 节 p95 门槛。
- 启动磁盘无法用公开系统原语稳定实现同卷、原子、不覆盖的最终文件发布。
- Terminal Service 的公开调用、pasteboard 输入或两种模式无法在阶段 0 矩阵中稳定复现。
- ad-hoc Bundle 无法在目标 macOS 上加载嵌入扩展。
- 带下载隔离属性的阶段 0 ad-hoc ZIP 无法在干净环境人工放行、安装到 `/Applications`、启用扩展并完成最小 App Group/Finder/URL 往返。

发生停止条件时保留探针和验证记录，不继续堆叠业务代码；重新进入需求设计，为方案 B 或其他公开 API 路线编写独立规格。

## 17. 未来 Developer ID 迁移

未来正式网站发行时需要：

- 在 Apple Developer 账户中注册主程序、扩展和可用的 App Group 能力。
- 为主程序和扩展使用匹配的 Developer ID / provisioning 配置。
- 启用 Hardened Runtime，完成公证、票据装订和干净机器验证。
- 保持“扩展先签、主程序后签”的顺序。
- 如果正式 App Group 标识必须变化，由主程序提供一次性模板和设置迁移；扩展只读取新容器。

共享容器定位、命令处理和模板存储必须通过明确接口隔离，不能在业务服务中散落 Group ID 或绝对路径。这样迁移签名身份或容器时不需要重写 Finder 选择、命名、模板和工具打开逻辑。

## 18. 验收结论

本功能达到技术预览可发布状态，需要同时满足：

- 阶段 0 全部强制探针可重复通过并完成独立架构复审。
- Finder 在支持范围内的上下文、冻结规则、菜单状态和性能正确。
- 文件创建使用经探针验证的不覆盖原子发布，14 类内置模板均有效；外置卷只在真实验证过的卷类型上承诺支持。
- 自定义模板独立于原文件，导入/删除事务和崩溃恢复可验证。
- Terminal 两种模式、VS Code 和自定义工具按目标矩阵交付；第三方工具验收不夸大为已处理全部 URL。
- 扩展异常不会卡住 Finder；命令满足明确的 at-most-once 语义，崩溃后使用 `unknown` 而不是自动重放，错误反馈最多领取一次。
- ad-hoc `.app` 内嵌 `.appex` 的签名和 Bundle 检查通过。
- 从带下载隔离属性的 ZIP 完成人工安装和扩展启用 smoke test。
- 下载页明确标注未使用 Developer ID、未公证技术预览的安装摩擦和兼容性限制。
