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

## 截图素材

首版预留四个固定比例的真实效果图位置：Dock 悬停预览、预览卡片激活、右键窗口操作和设置。只有在人工审阅确认其不包含个人信息、无关窗口且准确反映当前 app 能力后，才可把真机截图接入这些位置。不要使用合成画面、库存图或人工拼绘的应用界面替代。
