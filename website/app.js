import { GITHUB_RELEASES_URL, GITHUB_REPOSITORY_URL, fetchReleaseState } from "./release-state.js";

const appearanceButtons = [...document.querySelectorAll("[data-theme]")];
const releaseStatus = document.querySelector("#release-status");
const heroAction = document.querySelector("#hero-action");
const installDialog = document.querySelector("#install-dialog");
const confirmDownload = document.querySelector("#confirm-download");

let releaseAssetUrl = null;
let installTrigger = null;

function setAppearance(theme) {
  if (theme === "system") {
    delete document.documentElement.dataset.theme;
  } else {
    document.documentElement.dataset.theme = theme;
  }

  appearanceButtons.forEach((button) => {
    button.setAttribute("aria-pressed", String(button.dataset.theme === theme));
  });

  localStorage.setItem("zong-mac-tools-appearance", theme);
}

function initializeAppearance() {
  const savedAppearance = localStorage.getItem("zong-mac-tools-appearance");
  setAppearance(["system", "light", "dark"].includes(savedAppearance) ? savedAppearance : "system");
  appearanceButtons.forEach((button) => {
    button.addEventListener("click", () => setAppearance(button.dataset.theme));
  });
}

function renderReleaseStatus({ state, label, assetUrl = null }) {
  releaseStatus.dataset.state = state;
  releaseStatus.replaceChildren();

  const dot = document.createElement("span");
  dot.className = "status-dot";
  dot.setAttribute("aria-hidden", "true");
  const text = document.createElement("span");
  text.textContent = label;
  releaseStatus.append(dot, text);

  releaseAssetUrl = assetUrl;

  if (assetUrl) {
    heroAction.href = "#install";
    heroAction.target = "";
    heroAction.rel = "";
    heroAction.textContent = "下载公开测试版";
    heroAction.append(document.createTextNode(" ↗"));
    return;
  }

  heroAction.href = state === "unavailable" ? GITHUB_RELEASES_URL : GITHUB_REPOSITORY_URL;
  heroAction.target = "_blank";
  heroAction.rel = "noreferrer";
  heroAction.textContent = state === "unavailable" ? "在 GitHub 查看版本" : "查看 GitHub 源码";
  heroAction.append(document.createTextNode(" ↗"));
}

async function loadReleaseStatus() {
  renderReleaseStatus({ state: "loading", label: "正在确认公开测试版状态" });
  const state = await fetchReleaseState();
  renderReleaseStatus({ state: state.kind, label: state.label, assetUrl: state.assetUrl });
}

function openInstallDialog(trigger) {
  if (!releaseAssetUrl) {
    return;
  }

  installTrigger = trigger;
  installDialog.showModal();
  confirmDownload.focus();
}

function initializeInstallGuide() {
  heroAction.addEventListener("click", (event) => {
    if (!releaseAssetUrl) {
      return;
    }

    event.preventDefault();
    openInstallDialog(heroAction);
  });

  confirmDownload.addEventListener("click", () => {
    if (releaseAssetUrl) {
      window.location.assign(releaseAssetUrl);
    }
  });

  installDialog.addEventListener("close", () => {
    installTrigger?.focus();
  });

  installDialog.addEventListener("click", (event) => {
    if (event.target === installDialog) {
      installDialog.close();
    }
  });
}

initializeAppearance();
initializeInstallGuide();
loadReleaseStatus();
