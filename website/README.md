# zongMacTools 公开产品站

该目录是 zongMacTools 的公开产品站静态发布根目录。它不参与 SwiftPM 构建、macOS app 打包或 GitHub Release 打包。

## 本地验证

```bash
npm install
npm run test:site
```

测试会启动一个本地静态服务器，并运行发布状态、安装引导、键盘访问、减少动态效果、响应式及静态交付工件的浏览器验证。

## Cloudflare Pages 交接

通过 Cloudflare Pages 的 GitHub Integration 配置本仓库时，使用：

- 生产分支：`develop`
- 构建命令：留空
- 构建输出目录：`website`

不要为本网站创建 Cloudflare API token、GitHub 部署密钥、Worker、Pages Function 或 R2 存储。站点只通过浏览器请求 GitHub 的公开 Release API；下载资产、校验信息、签名状态与完整发行详情继续由 GitHub Release 承载。

Cloudflare 实际创建项目并提供 Pages 子域后，再统一写入 canonical、分享 URL、`robots.txt` 和 `sitemap.xml`；未配置的阶段不要猜测或预写任何 `pages.dev` 或自定义域名。

## 录屏预览素材

当前媒体区使用本地托管的录屏预览和三张关键帧，全部保持原始 `2704 × 1434` 比例：

- `assets/dock-window-quick-look.mp4`：去除音轨的 H.264 录屏预览，聚焦 Dock 窗口预览、窗口操作和窗口切换。
- `assets/dock-window-quick-look-poster.jpg`：右键窗口操作画面，同时作为窄屏和减少动态效果下的海报图。
- `assets/dock-window-quick-look-preview.jpg`：窗口预览关键帧。
- `assets/dock-window-quick-look-switch.jpg`：切换窗口关键帧。

这些文件由 `Assets/demonstrate/zongmactools.mp4` 截取和转码得到。当前页面将其明确标为本地预览，不能替代正式发布素材。正式发布前仍需在干净测试环境人工确认窗口标题、路径、桌面图标、通知、浏览器标签、头像、画面边缘和当前能力一致性；不通过审核的素材不得接入公开站。不要使用合成画面、库存图或人工拼绘的应用界面替代真实运行素材。
