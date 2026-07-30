# Finder 右键扩展：文件创建与开发工具设计

日期：2026-07-30

## 1. 目标

在现有 `zongMacTools` 中增加一个 Finder Sync 右键扩展，为普通本地目录和正常挂载的外置磁盘提供两类操作：

1. 从内置类型或用户导入的模板创建新文件。
2. 使用 Terminal、Visual Studio Code 或用户添加的 `.app` 打开 Finder 当前上下文。

首个可发布版本采用 ad-hoc 签名，定位为可从网站下载的免费技术预览版。它不使用 Developer ID，不进行 Apple 公证，也不宣传为通过 Gatekeeper 验证的正式发行版。设计必须只使用公开 API，并保留以后迁移到 Developer ID 和公证发行的入口。

## 2. 已确认的产品决策

### 2.1 Finder 上下文

- 在 Finder 空白处打开菜单时，当前目录是操作上下文。
- 单选文件夹时，文件创建目标是该文件夹内部。
- 单选文件时，文件创建目标是该文件所在目录。
- 多选时禁用文件创建。
- 普通本地目录和正常挂载的外置磁盘属于支持范围。
- iCloud Drive、OneDrive、Dropbox、网络卷、文件提供程序虚拟目录和 Finder 特殊位置不作可靠性承诺。
- 不使用全局鼠标监听，不实现 Finder 之外的第二套自定义右键菜单。

### 2.2 文件创建

- 第一个候选名称是 `未命名.ext`；英文界面使用 `Untitled.ext`。
- 名称冲突后依次尝试 `未命名 2.ext`、`未命名 3.ext`，英文同理。
- 创建成功后使用公开 API 让 Finder 选中新文件。
- 不使用 Apple Events 或系统辅助功能强制 Finder 进入行内重命名；用户可按 Return 重命名。
- 用户导入的模板复制到应用管理的模板库，之后不依赖原始文件位置。
- 模板设置支持显示名称修改、排序、启用/停用和删除。

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
- 自定义工具默认使用应用原生“打开 URL”语义接收选中项，不额外构造命令行参数。

### 2.5 Terminal 行为

Finder 菜单只显示一个“在 Terminal 中打开”。`zongMacTools` 设置页提供“新窗口”和“新标签页”两个选项，并保存本工具自己的默认值。

执行时使用 Terminal 注册的公开 macOS Services：

- `New Terminal at Folder`
- `New Terminal Tab at Folder`

在当前可观察到的 Terminal 版本中，这两个服务分别对应新窗口和新标签页。系统没有供第三方稳定读取的统一“目录应在窗口还是标签页打开”偏好，因此本工具不声称跟随 Terminal 自身设置，也不请求自动化权限。服务不可用或调用失败时显示明确错误，不退回 Apple Events。

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
- 串行领取并验证扩展提交的命令。
- 创建文件、调用 Terminal Service、通过 `NSWorkspace` 打开工具。
- 显示成功后的 Finder 选择和用户可理解的错误。

扩展不得在 Finder 菜单回调中扫描应用、复制模板、创建 Office 文档或等待主程序 IPC。这样可以控制 Finder 进程中的工作量，并避免主程序未运行时卡住 Finder 菜单。

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

主程序和扩展都声明 `com.apple.security.application-groups`。扩展还声明其运行所需的 App Sandbox entitlement。探针使用当前 ad-hoc 身份签名，不需要 Developer ID 或公证。

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

### 5.4 失败标准

- 任一进程无法解析 Group Container。
- 两边得到不同容器。
- 扩展因沙盒、entitlement 或签名被拒绝访问。
- 只能在一次偶然安装中成功，重建或重启后不可复现。
- 必须手工访问系统 Group Containers 路径才能成功。

任何一条失败都阻止方案 A 的业务开发，并触发方案 B 的独立设计。探针不通过时不能通过忽略错误、关闭扩展沙盒或直接读写其他应用容器继续实现。

### 5.5 探针同时记录但不混淆的能力

App Group 往返是硬门槛。为了避免下一阶段立即遇到另一个平台阻塞，探针构建还要记录：

- Finder 能加载嵌入的 ad-hoc `.appex`。
- 空白处、单选和多选菜单回调能取得预期 URL。
- 扩展可以通过 `zongmactools://command/<UUID>` 唤醒已运行或未运行的主程序。
- `/` 或明确卷根目录的 Finder Sync 注册方式能覆盖普通本地目录。
- 正常挂载的外置磁盘能否显示菜单；没有可用外置盘时记录为 `blocked / not available`，不能写成通过。

URL Scheme 唤醒失败也会阻止正式方案 A，因为写入命令但无法可靠通知主程序会形成无反馈的失效路径。

## 6. 构建和 Bundle 结构

### 6.1 保留 SwiftPM 作为主程序与测试入口

现有 SwiftPM executable、源码布局和 `swift test` 流程继续保留。Finder 扩展是独立 `.appex`，不能伪装成主 executable 中的普通类型。

`zongMacTools.xcodeproj` 用于声明原生 Finder Sync Extension target 和生成合法 `.appex`。主程序仍可由 SwiftPM 构建，打包脚本负责组合两个产物。共享的协议模型使用源文件级共享，不引入动态框架，也不让扩展链接整个 Dock 窗口速览实现。

### 6.2 最终目录

```text
zongMacTools.app/
  Contents/
    Info.plist
    MacOS/DockHoverPreviewProbe
    Resources/
      BuiltInTemplates/
    PlugIns/
      RightClickFinderExtension.appex/
        Contents/
          Info.plist
          MacOS/RightClickFinderExtension
```

### 6.3 签名顺序

打包脚本必须：

1. 构建主程序和扩展。
2. 组装主程序 Bundle 并嵌入 `.appex`。
3. 使用扩展 entitlements 签名 `.appex`。
4. 使用主程序 entitlements 签名外层 `.app`。
5. 用 `codesign --verify --deep --strict` 验证完整 Bundle。
6. 分别导出并检查主程序和扩展的实际 entitlements。

签名必须从内到外，不依赖 `codesign --deep --force` 自动替内层选择 entitlements。默认身份仍是 `-`；以后配置 Developer ID 时只替换签名与 provisioning 流程，不改变命令协议和业务边界。

## 7. Finder 菜单设计

### 7.1 菜单层级

扩展在 Finder 上下文菜单中提供一个稳定的 `zongMacTools` 根项，子菜单为：

```text
zongMacTools
  新建文件 >
    TXT
    Markdown
    JSON
    XML
    --------
    Word
    Excel
    PowerPoint
    --------
    YAML
    Python
    HTML
    CSS
    JavaScript
    TypeScript
    RTF
    --------
    <用户模板，按设置顺序>
  --------
  在 Terminal 中打开
  使用 Visual Studio Code 打开
  使用开发工具打开 >
    <用户添加的 .app，按设置顺序>
```

没有启用的自定义工具时隐藏“使用开发工具打开”子菜单。用户在设置中停用的模板或工具不出现在菜单中。多选时“新建文件”保留但禁用；Terminal 目标不唯一时保留但禁用，使菜单结构稳定且状态可理解。

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
- 运行纯内存目标解析。
- 使用内存中的最后一份有效菜单快照创建 `NSMenu`。

它不得启动主程序、枚举已安装应用、读取模板内容、访问网络或等待异步结果。扩展发现 `menu-catalog.json` 版本变化时可以重新解码小型文件；解码失败则保留进程内最后一份有效快照。进程内没有有效快照时只显示一个禁用的“请先打开 zongMacTools”状态项。

## 8. 目标解析规则

目标解析是共享的纯领域逻辑，由自动测试覆盖。URL 先标准化并去重，同时保留 Finder 首次提供的顺序。

| Finder 上下文 | 创建文件目标目录 | Terminal 目标 | VS Code / 自定义工具目标 |
| --- | --- | --- | --- |
| 空白处 | 当前目录 | 当前目录 | 当前目录 |
| 单个文件夹 | 文件夹内部 | 该文件夹 | 该文件夹 |
| 单个文件 | 文件所在目录 | 文件所在目录 | 该文件 |
| 多选且目标目录相同 | 禁用 | 唯一目标目录 | 全部选中项 |
| 多选且目标目录不同 | 禁用 | 禁用 | 全部选中项 |

多选 Terminal 的“目标目录”按以下规则计算：文件夹对应自身，文件对应父目录。例如同时选择文件夹 `A` 和 `A/file.txt` 时，两项都解析到 `A`，Terminal 可以启用。

以下情况禁用对应动作：

- Finder 没有提供文件 URL。
- 空白处没有有效的目标目录。
- 项目在动作执行前被移走、删除或所属卷被弹出。
- Terminal 多选不能归一到一个目录。

扩展不在菜单构建路径中执行昂贵的可写性检查。主程序在真正执行时重新验证目录存在、是目录并可创建文件；失败时给出错误，不覆盖任何已有项目。

## 9. App Group 数据协议

### 9.1 目录布局

```text
<Group Container>/
  right-click/
    menu-catalog.json
    commands/
      pending/<UUID>.json
      processing/<UUID>.json
    templates/
      <TemplateID>/content
    state/
      extension-heartbeat.json
    probe/
      request.json
      response.json
```

主程序是菜单快照和模板库的唯一写入者。扩展只读取 `menu-catalog.json` 和必要的模板元数据，不读取模板正文。扩展是 pending 命令的写入者，主程序通过原子移动领取命令。

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
      "enabled": true,
      "sortOrder": 30
    }
  ],
  "tools": [
    {
      "id": "builtin.terminal",
      "displayName": "Terminal",
      "kind": "terminal",
      "enabled": true,
      "sortOrder": 10
    }
  ]
}
```

快照只包含构造菜单所需的稳定 ID、显示名称、类型、启用状态和排序，不包含自定义工具书签、应用完整路径或模板正文。主程序在启动、相关设置变化和模板导入删除后，通过同目录临时文件加原子替换发布新 revision。

### 9.3 命令文件

每次菜单动作写入一个单独文件：

```json
{
  "schemaVersion": 1,
  "id": "2F95B633-2B8A-4F70-B3A7-62F1886D4698",
  "createdAt": "2026-07-30T10:01:00Z",
  "action": "createFile",
  "subjectID": "builtin.json",
  "context": "singleFile",
  "urls": ["file:///Users/example/Project/README.md"]
}
```

`action` 首版只有 `createFile` 和 `openTool`。`subjectID` 引用主程序管理的模板或工具记录。扩展不把任意输出文件名、命令行或可执行路径写入命令。

命令先写入临时文件，完整同步后原子移动为 `commands/pending/<UUID>.json`。随后扩展打开：

```text
zongmactools://command/<UUID>
```

URL 只传 UUID，不传文件路径、模板内容或工具路径。

### 9.4 领取和幂等

主程序收到 URL 后验证 scheme、host、UUID 格式和对应 pending 文件，再把文件原子移动到 `processing`。只有成功移动的一次调用可以执行命令，因此 URL 重复投递、应用重开或用户快速点击不会让同一个命令执行两次。

命令处理在一个串行执行器中完成。主程序拒绝：

- 未知 schema 版本。
- 文件内 ID 与文件名或 URL ID 不一致。
- 创建时间超过 5 分钟的命令。
- 非 `file:` URL、空 URL 或不符合 action 的上下文。
- 不存在、已禁用或类型不匹配的模板和工具 ID。

处理完成或失败后删除 processing 文件。启动时清除超过 10 分钟的 pending 和 processing 文件，避免路径信息长期残留。统一日志只记录命令 ID、动作类型和错误分类，不记录完整用户路径。

## 10. 模板库

### 10.1 内置模板

内置模板随主程序资源发布，有稳定 ID 和不可删除的内容。用户可以调整顺序或停用，但不能修改应用内资源。每次发布前必须验证资源存在、扩展名正确，并对 OOXML ZIP 包检查必要入口。

Office 模板至少进行以下真实应用人工验证：

- `.docx` 可在 Microsoft Word 或 WPS Writer 中打开且不提示损坏。
- `.xlsx` 可在 Microsoft Excel 或 WPS Spreadsheets 中打开且包含一个空工作表。
- `.pptx` 可在 Microsoft PowerPoint 或 WPS Presentation 中打开且包含一张空白幻灯片。

如果测试机器只安装 WPS，则以 WPS 结果作为技术预览最低验收，并在验证记录中注明未验证的 Microsoft Office 应用。

### 10.2 自定义模板导入

用户通过文件选择面板选择一个普通文件。导入服务必须：

1. 拒绝目录、符号链接和其他特殊文件。
2. 为模板生成稳定 UUID。
3. 把文件内容复制到 App Group 的模板目录，而不是保存对原文件的依赖。
4. 不复制原文件的执行位、ACL 或扩展属性；创建的新文件使用普通文档权限。
5. 保存原文件的最后一个扩展名；没有扩展名时创建名称不附加扩展名。
6. 默认显示名称使用原文件名去掉最后一个扩展名，用户可以在设置中修改。

所有自定义模板创建出的目标文件仍使用本地化 `未命名` / `Untitled` 作为基础名称，再附加模板记录中的扩展名。修改模板显示名称只影响菜单，不改变创建文件名称规则。

删除模板先从设置与菜单快照中移除，再删除托管内容。导入复制失败时不创建半成品记录；删除失败时记录可重试的本地错误，但菜单中保持移除，避免用户继续选择损坏模板。

### 10.3 创建文件的原子性

主程序为目标目录生成候选名称，并以“不覆盖已有文件”的独占创建语义领取名称。名称竞争时继续尝试下一个编号，不能先检查存在再无条件覆盖。

写入模板内容失败时删除本次创建的未完成文件，并报告错误。创建成功后：

1. 关闭并完成文件写入。
2. 使用 `NSWorkspace.shared.activateFileViewerSelecting([newURL])` 让 Finder 选中它。
3. 不发送 Return、不模拟键盘，也不自动打开编辑器。

## 11. 开发工具注册与打开

### 11.1 Visual Studio Code

主程序使用 bundle identifier `com.microsoft.VSCode` 通过 `NSWorkspace` 定位稳定版 Visual Studio Code。找不到时菜单仍可根据最后快照显示，但执行会提示未安装或已移动，并引导用户在设置中检查；首版不自动把 VS Code Insiders 当作稳定版。

调用 `NSWorkspace` 的 URL 打开接口，把一个或多个 Finder URL 交给 VS Code。首版不依赖 `code` 命令、不创建 shell 进程，也不擅自添加 `--new-window`、`--reuse-window` 等参数，由 VS Code 自己决定窗口复用行为。

### 11.2 自定义开发工具

“添加开发工具”文件选择面板只允许选择 `.app`。主程序验证它是可打开的应用 Bundle，并保存：

- 稳定工具 UUID。
- 显示名称。
- bundle identifier（存在时）。
- 应用 URL 的书签数据。
- 排序和启用状态。

执行时先解析书签；路径失效时再按 bundle identifier 通过 `NSWorkspace` 查找。两种方式都失败则把工具标记为不可用并提示用户重新添加。菜单快照不包含书签和应用路径。

设置页支持添加、显示名称修改、排序、启用/停用和删除。重复选择相同 bundle identifier 或标准化路径时复用已有记录，不创建重复菜单项。

自定义工具使用 `NSWorkspace` 的“以指定应用打开 URL 集合”接口。首版不提供命令行参数编辑，因此不会执行用户文件中的文本，也不会把文件路径插入 shell 命令。

### 11.3 Terminal Service

Terminal launcher 根据设置把目标目录作为文件 URL 写入专用 `NSPasteboard`，然后调用对应的公开 Service 名称。返回失败时不使用 AppleScript、`osascript` 或辅助功能补救。

设置值是版本化枚举：

- `newWindow` -> `New Terminal at Folder`
- `newTab` -> `New Terminal Tab at Folder`

首版默认值是“新窗口”；设置缺失或非法时也回退为“新窗口”。如果选择“新标签页”但 Terminal 当前没有窗口，实际结果由 Terminal Service 决定，通常会创建可承载标签页的窗口。本工具不伪造窗口状态，也不尝试反向读取或覆盖 Terminal 自己的偏好。

## 12. 设置界面

现有“右键扩展”禁用占位替换为真实设置页，保持当前设置窗口的 sidebar/detail 结构。页面包含：

- Finder 扩展状态区：显示最近一次扩展 heartbeat，而不是声称能准确读取系统启用状态。
- “管理 Finder 扩展”按钮：调用公开的 Finder Sync 扩展管理界面。
- 内置文件类型列表：排序和启用/停用。
- 自定义模板列表：添加、修改显示名称、排序、启用/停用和删除。
- Terminal 打开方式分段控件：新窗口 / 新标签页。
- 开发工具列表：Terminal、Visual Studio Code 和用户添加的应用。
- 自定义工具操作：添加、修改显示名称、排序、启用/停用和删除。

Finder 扩展的系统启用状态没有稳定公开查询接口，因此页面不能把“最近收到 heartbeat”显示成“系统已启用”。状态文案使用“最近活动时间”“尚未检测到活动”这类可验证表述。应用不自动运行 `pluginkit`，不自动重启 Finder。

相关设置变化立即写入主程序设置存储，并重新发布原子菜单快照。模板内容复制完成前不发布对应菜单项。

## 13. 错误处理与用户反馈

### 13.1 扩展侧

扩展不能弹出阻塞 Finder 的复杂对话框。它采用以下降级：

- App Group 不可用：不发布业务菜单，记录结构化错误。
- 菜单快照缺失：显示禁用的初始化提示。
- 新快照损坏：继续使用进程内最后一份有效快照。
- 命令文件写入失败：不打开 URL Scheme，记录错误并发出系统提示音。
- URL Scheme 打开失败：保留短期 pending 文件供清理和诊断，不重复提交动作。

### 13.2 主程序侧

成功创建或成功打开工具时保持安静；创建文件仅让 Finder 选中新文件。以下用户发起的失败由主程序显示一次非重复错误：

- 目标目录不存在、只读或卷已弹出。
- 模板内容缺失或损坏。
- Visual Studio Code 或自定义工具找不到。
- Terminal Service 不可用或调用失败。
- 命令过期、协议版本不支持或上下文无效。

错误信息说明失败动作和可执行下一步，不暴露内部 JSON 或完整 entitlement 内容。相同命令 ID 只显示一次错误。

### 13.3 隐私和安全

- 所有菜单、模板和命令数据只保存在本机。
- 不上传文件名、路径、模板或工具列表。
- 路径只存在于短生命周期命令文件中，处理后删除。
- URL Scheme 不携带路径。
- 命令不能指定任意可执行文件或 shell 文本，只能引用主程序已登记的工具 ID。
- 文件创建永不覆盖已有文件。
- 模板导入不保留执行权限，避免“创建文件”隐式产生可执行程序。

## 14. 生命周期和恢复

- 主程序启动时创建 App Group 子目录、清理过期命令、验证内置模板并发布菜单快照。
- 扩展启动时解析容器和菜单快照，注册 Finder 根目录，并写入节流后的 heartbeat。
- 扩展被 Finder 终止后不需要恢复内存状态；下次启动从最新快照重建。
- 主程序未运行时，扩展仍可从快照构造菜单；点击动作写入命令并通过 URL Scheme 启动主程序。
- 主程序收到多个 URL 时按命令创建时间串行领取，但每条命令仍以 UUID 幂等。
- 外置卷在菜单打开后弹出时，主程序把它当作正常执行失败，不重试到其他目录。
- 菜单快照 schema 不支持时，扩展不猜测字段含义，回退到最后有效版本或初始化提示。

## 15. 测试设计

### 15.1 自动测试

共享领域测试：

- 空白处、单文件夹、单文件和多选目标解析矩阵。
- 多选 Terminal 相同目录、不同目录、文件夹加子文件和重复 URL。
- 非文件 URL、缺少父目录、目标消失和无效上下文。
- 菜单快照 schema、排序、停用过滤和损坏快照回退。
- 命令编码解码、UUID 匹配、5 分钟有效期和未知 action 拒绝。
- 原子领取保证重复 URL 只执行一次。

文件创建测试：

- `未命名.ext`、`未命名 2.ext` 及连续冲突命名。
- 大小写不敏感卷语义通过可注入文件系统 fake 覆盖。
- 竞争期间独占创建不覆盖已有文件。
- 写入失败删除半成品。
- 14 个内置模板的扩展名和基础内容验证。
- DOCX、XLSX、PPTX 是可解析 ZIP，包含各自必要 OOXML 入口。
- RTF、JSON、XML、HTML 和 YAML 的最小格式有效性。
- 自定义模板导入后删除原文件仍可创建。
- 拒绝目录、符号链接和特殊文件；不复制执行位。

工具测试：

- Terminal 设置到两个 Service 名称的精确映射。
- Terminal 只接收一个解析后的目录。
- VS Code 单文件、文件夹和多选 URL 转发。
- 自定义工具书签成功、按 bundle identifier 恢复和完全失效。
- 未登记 tool ID、已停用工具和重复工具记录拒绝。

设置和文案测试：

- 右键扩展替换占位后出现在设置导航。
- 中英文菜单、设置标题、错误和状态文案。
- 内置项目默认顺序、启停、排序和非法设置回退。
- Terminal 默认值和非法枚举回退新窗口。
- 设置变化触发菜单 snapshot revision 增加。

### 15.2 Bundle 与签名自动检查

- 主程序包含 `Contents/PlugIns/RightClickFinderExtension.appex`。
- 主程序、扩展 executable 和 Info.plist 均存在且合法。
- 主程序和扩展 bundle identifier 精确匹配设计值。
- 两者实际签名 entitlements 包含同一个 App Group。
- 扩展声明正确的 Finder Sync extension point 和 principal class。
- 主程序注册 `zongmactools` URL Scheme。
- 先签扩展、后签主程序后通过 `codesign --verify --deep --strict`。
- release ZIP 包含已签名的完整 `.appex`，解压后再次通过检查。

### 15.3 探针和人工验收

阶段 0，架构门槛：

1. App Group 双向往返。
2. Finder 空白、单选和多选上下文读取。
3. URL Scheme 在主程序运行和未运行时都能领取一次命令。
4. 主程序、Finder 和扩展重启后的重复验证。
5. ad-hoc 重建、替换和重新启用扩展后的重复验证。

阶段 1，文件创建：

1. 在本地普通目录的空白处、文件和文件夹上下文创建全部内置类型。
2. 验证冲突编号、Finder 选中和 Return 手动重命名。
3. 多选时创建菜单禁用。
4. 导入自定义模板，删除原件后仍可创建。
5. 在 WPS 中打开 DOCX、XLSX、PPTX，确认无损坏提示。
6. 只读目录、目标删除和卷弹出时显示正确错误且不留半成品。

阶段 2，开发工具：

1. Terminal 新窗口和新标签页各验证一次。
2. 单文件、文件夹、相同目录多选和不同目录多选的 Terminal 状态正确。
3. VS Code 收到单文件、文件夹和多个选中项。
4. 添加另一款 `.app`，验证添加、排序、停用、移动后的恢复和删除。

阶段 3，覆盖范围：

1. 用户主目录、桌面、文稿和普通项目目录。
2. 正常挂载的外置磁盘；硬件不可用时记录 `blocked / not available`。
3. iCloud、OneDrive、Dropbox 和文件提供程序目录只记录观察结果，不据此扩大支持承诺。

### 15.4 网站技术预览分发验证

本机开发目录中的探针通过不等于网站下载可用。发布前还要在与构建目录分离的环境中验证：

1. 生成 release ZIP 和 SHA-256。
2. 通过浏览器下载或用等价方式保留下载隔离属性。
3. 解压并移动到 `/Applications`。
4. 使用系统当时提供的 Control-点击“打开”或“隐私与安全性”中的“仍要打开”处理首次 Gatekeeper 提示，不指导关闭 Gatekeeper。
5. 首次启动主程序并打开系统 Finder 扩展管理界面。
6. 用户手动启用扩展后，重新执行 App Group、菜单、文件创建和 Terminal 最小流程。
7. 替换为下一 build 后验证扩展注册和设置/模板保留行为。

技术预览下载页必须明确：未使用 Developer ID、未公证、首次打开和扩展启用需要用户操作、仅承诺 macOS 14 或更新版本，以及云盘等已知限制。

## 16. 实施顺序和停止条件

实施计划必须按以下阶段拆分，不能越过失败门槛：

1. **App Group 与 Finder 加载探针**：只建立最小 `.appex`、entitlements、往返文件和 URL Scheme 唤醒。
2. **探针评审**：记录每项通过、失败或硬件不可用；App Group 或 URL 唤醒失败则停止。
3. **共享协议和纯领域模型**：菜单快照、命令、目标解析及测试。
4. **主程序文件创建能力**：模板库、命名、原子创建和 Finder 选择。
5. **开发工具能力**：Terminal、VS Code 和自定义应用。
6. **Finder 菜单和设置页集成**：替换占位并连接完整数据流。
7. **Bundle、签名和人工验收**：本地目录、外置盘和真实办公文件。
8. **网站分发 smoke test**：从隔离 ZIP 安装并启用扩展。

停止条件：

- App Group 探针失败。
- URL Scheme 无法从 Finder 扩展可靠唤醒主程序。
- Finder Sync 的公开目录注册无法覆盖普通本地目录。
- ad-hoc Bundle 无法在目标 macOS 上加载嵌入扩展。

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

- App Group 和 URL Scheme 探针可重复通过。
- Finder 在支持范围内的上下文和菜单状态正确。
- 文件创建不覆盖已有文件，14 类内置模板均有效。
- 自定义模板独立于原文件并可完整管理。
- Terminal 两种模式、VS Code 和自定义工具按目标矩阵工作。
- 扩展异常不会卡住 Finder，主程序错误可理解且不重复执行命令。
- ad-hoc `.app` 内嵌 `.appex` 的签名和 Bundle 检查通过。
- 从带下载隔离属性的 ZIP 完成人工安装和扩展启用 smoke test。
- 下载页明确标注未使用 Developer ID、未公证技术预览的安装摩擦和兼容性限制。
