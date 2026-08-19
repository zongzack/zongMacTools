# zongMacTools 公开产品站

该目录是 zongMacTools 的公开产品站静态发布根目录。它不参与 SwiftPM 构建、macOS app 打包或 GitHub Release 打包。

站点围绕“Windows → macOS”功能迁移展开七段产品叙事（品牌首屏、迁移来源、已实现工具、真实运行画面、下一项迁移、获取公开测试版、页脚），使用原生 HTML/CSS/ES Module，无框架、无构建步骤、无 CDN、无分析、无 Cookie、无第三方媒体服务。

## 本地验证

```bash
npm install
npm run test:site
```

测试会启动一个本地静态服务器，并运行七段叙事、双语切换、交互原理演示、发布状态降级、键盘访问、减少动态效果、响应式与无数据站点边界的浏览器验证。

## Cloudflare Pages 交接

通过 Cloudflare Pages 的 GitHub Integration 配置本仓库时，使用：

- 生产分支：`develop`
- 构建命令：留空
- 构建输出目录：`website`

不要为本网站创建 Cloudflare API token、GitHub 部署密钥、Worker、Pages Function 或 R2 存储。站点只通过浏览器请求 GitHub 的公开 Release API；下载资产、校验信息、签名状态与完整发行详情继续由 GitHub Release 承载。

Cloudflare 实际创建项目并提供 Pages 子域后，再统一写入 canonical、分享 URL 和 `sitemap.xml`；未配置的阶段不要猜测或预写任何 `pages.dev` 或自定义域名。

## 录屏素材

当前媒体区使用本地托管的录屏预览与三张关键帧，全部保持原始 `2704 × 1434` 比例，不做裁切：

- `assets/quick-look-recording.mp4`：去除音轨的 H.264 录屏预览，覆盖 Dock 停留、预览出现、窗口切换与窗口操作。
- `assets/quick-look-poster.jpg`：窗口操作画面，同时作为窄屏与减少动态效果下的海报图。
- `assets/quick-look-frame-preview.jpg` / `quick-look-frame-switch.jpg` / `quick-look-frame-actions.jpg`：预览出现、切换窗口、窗口操作关键帧。

这些文件由 `Assets/demonstrate/zongmactools.mp4` 截取和转码得到，页面直接展示 Dock 窗口速览的实际运行路径。录屏中的窗口标题、文件路径和桌面环境来自本地测试机，具体能力和安装要求以应用与 GitHub Release 为准；不要使用合成画面、库存图或人工拼绘的应用界面替代真实运行素材。
