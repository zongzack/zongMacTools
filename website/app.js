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

function wireDemoDialog() {
  const dialog = document.querySelector("[data-demo-dialog]");
  const title = document.querySelector("#demo-dialog-title");
  const media = document.querySelector("[data-demo-media]");
  const video = document.querySelector("[data-demo-video-player]");
  const closeButton = document.querySelector("[data-demo-close]");
  const triggers = document.querySelectorAll("[data-demo-trigger]");

  if (!dialog || !title || !media || !video || !closeButton || triggers.length === 0) return;

  let activeTrigger = null;

  const resetVideo = () => {
    video.pause();
    video.removeAttribute("src");
    video.load();
  };

  const closeDialog = () => {
    if (dialog.open) dialog.close();
  };

  triggers.forEach((trigger) => {
    trigger.addEventListener("click", () => {
      activeTrigger = trigger;
      title.textContent = trigger.dataset.demoTitle ?? "实机演示";
      media.style.setProperty("--demo-video-aspect-ratio", trigger.dataset.demoAspectRatio ?? "16 / 9");
      video.src = trigger.dataset.demoVideo;
      video.load();
      dialog.showModal();

      // 点击入口是用户手势，加载完成后可直接开始播放；浏览器拒绝时仍保留原生播放控件。
      video.play().catch(() => {});
    });
  });

  closeButton.addEventListener("click", closeDialog);

  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) closeDialog();
  });

  dialog.addEventListener("close", () => {
    resetVideo();
    activeTrigger?.focus();
    activeTrigger = null;
  });
}

wireDownloadButtons();
wireDemoDialog();
