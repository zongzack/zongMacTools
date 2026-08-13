# 使用静态 Cloudflare Pages 产品站与 GitHub Release 下载资产

公开产品站以当前仓库的 `website/` 目录承载静态内容，并由 Cloudflare Pages 通过 GitHub 集成随 `develop` 分支中的网站改动发布。公开测试版的下载资产、校验信息和源码入口以 GitHub 仓库与 GitHub Release 为唯一事实来源；浏览器只读取公开 Release API，无法得到公开资产时降级为 GitHub 入口。这个边界避免首版引入 R2 文件分发、Worker 服务端逻辑、用户数据收集、Cloudflare 凭据管理和第二套发布状态，同时保留可验证的 release 历史。
