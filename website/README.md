# zongMacTools 公开产品站

`website/` 是 zongMacTools 的公开产品站静态发布根目录。它独立于 SwiftPM 构建、macOS app 打包和 GitHub Release 打包，可以直接作为静态目录部署。

站点围绕“把 Windows 的顺手，原样搬到 Mac”展开，当前页面包含：

- 首屏品牌叙事与两组 CSS 产品示意图
- Dock 窗口速览与 Finder 新建文件两张核心功能卡片
- 按需打开的实机演示弹窗
- Windows 到 Mac 的迁移对照
- 能力细节、常见问题、下载区和页脚链接

页面使用原生 HTML、CSS 和 ES Module，无框架、无构建步骤、无 CDN、无分析脚本、无 Cookie，也不依赖第三方媒体服务。

## 文件结构

- `index.html`：产品站页面结构、SEO 元信息、核心文案、导航、功能区、FAQ、下载区和视频弹窗。
- `styles.css`：整站视觉系统、响应式布局、CSS 产品示意图、功能卡片、演示弹窗和减少动态效果适配。
- `app.js`：下载按钮的 GitHub Release 接线，以及“观看实机演示”弹窗的打开、播放、关闭和焦点回收。
- `release-state.js`：读取公开 GitHub Release，选择可下载 zip 资产，并在失败时降级到 Releases 列表页。
- `assets/zong-mac-tools-logo.png`：站点 favicon、Apple touch icon、导航和页脚品牌图标。
- `assets/quick-look-recording.mp4`：Dock 窗口速览实机演示视频。
- `assets/right‑click-extension.mp4`：Finder 右键新建文件实机演示视频。
- `robots.txt` / `sitemap.xml`：搜索引擎入口文件。

## 本地验证

```bash
npm install
npm run test:site
```

测试会启动本地静态服务器，并覆盖产品叙事、核心功能数量、实机演示按需加载、GitHub Release 下载与降级、键盘访问、外部资源边界、许可证链接和响应式布局。

## 部署交接

通过 Cloudflare Pages 的 GitHub Integration 配置本仓库时，使用：

- 生产分支：`develop`
- 构建命令：留空
- 构建输出目录：`website`

不要为本网站创建 Cloudflare API token、GitHub 部署密钥、Worker、Pages Function 或 R2 存储。站点只通过浏览器请求 GitHub 的公开 Release API；下载资产、校验信息、签名状态与完整发行详情继续由 GitHub Release 承载。

canonical 与 `sitemap.xml` 当前指向 `https://zongmactools.pages.dev/`。如果正式域名变化，需要同步更新 `index.html`、`robots.txt` 和 `sitemap.xml`。

## 资源策略

`assets/` 只保留页面实际加载的产品资源。当前没有 jpg 封面或关键帧素材；演示视频在用户点击“观看实机演示”后才写入 `<video>` 的 `src` 并开始播放，初始页面不会预加载 mp4。

录屏素材由本地测试录屏截取和转码得到。录屏中的窗口标题、文件路径和桌面环境来自本地测试机，具体能力、权限要求和安装方式以应用本体与 GitHub Release 为准。
