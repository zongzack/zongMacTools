import { GITHUB_RELEASES_URL, fetchReleaseState } from "./release-state.js";

// 将页面上所有「下载公开测试版」按钮接到最新公开发行的资产上。
// 查询失败或未发布时，诚实降级到 Releases 列表页。
async function wireDownloadButtons() {
  const buttons = document.querySelectorAll("[data-download]");
  if (buttons.length === 0) return;

  const state = await fetchReleaseState();
  const href = state.kind === "available" ? state.assetUrl : GITHUB_RELEASES_URL;

  buttons.forEach((button) => {
    button.href = href;
    button.target = "_blank";
    button.rel = "noopener noreferrer";

    if (state.kind === "available") {
      button.setAttribute("aria-label", `下载 zongMacTools ${state.tagName}（新标签页打开）`);
    }
  });
}

wireDownloadButtons();
