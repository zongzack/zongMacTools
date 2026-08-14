import { GITHUB_RELEASES_URL, fetchReleaseState } from "./release-state.js";

const languageStorageKey = "zong-mac-tools-language";

const messages = {
  zh: {
    title: "zongMacTools | 面向 macOS 的桌面工具",
    description: "zongMacTools 让更好的桌面体验，在 Mac 上继续生长。当前首个已实现工具是 Dock Window Quick Look（Dock 窗口速览）。",
    ogDescription: "将已被验证有用的桌面体验重新做成适合 macOS 的工具，也补齐 macOS 日常操作的效率空白。",
    ogLocale: "zh_CN",
    skipLink: "跳至主要内容",
    primaryNavigation: "主导航",
    homeLink: "zongMacTools 首页",
    toolNav: "查看工具案例",
    languageSwitch: "切换为英文",
    githubSourceLink: "在 GitHub 查看 zongMacTools 源码",
    githubSource: "GitHub 源码",
    heroEyebrow: "连续桌面叙事",
    heroStatement: "让更好的桌面体验，在 Mac 上继续生长。",
    heroSummary: "将已被验证有用的桌面体验重新做成适合 macOS 的工具，也补齐值得被补上的日常操作细节。",
    heroAction: "查看首个工具",
    continueReading: "继续阅读",
    heroDeviceLabel: "Z / 桌面输入",
    originsEyebrow: "工具来源",
    originsTitle: "为什么是 zongMacTools",
    originsSummary: "有些好用的体验已在别处证明自己，但需要重新做成符合 macOS 使用方式的工具；也有些效率空白，值得直接为 Mac 补上。",
    originRail: "zongMacTools 的工具来源",
    migrationKicker: "体验迁移路径",
    migrationTitle: "体验迁移工具",
    migrationCopy: "从其他桌面系统中被反复验证的交互能力出发，按 macOS 的使用习惯、系统限制和公开 API 重新实现，而不是复制原有界面。",
    gainKicker: "macOS 效率空白",
    gainTitle: "macOS 增益工具",
    gainCopy: "不以别处的功能为起点，直接改善 Mac 日常操作中值得被补齐的细节，让工具集合沿着真实工作流继续扩展。",
    toolEyebrow: "首个已实现工具",
    toolTitle: "Dock Window Quick Look（Dock 窗口速览）",
    toolSummary: "停在 Dock，快速辨认正在运行应用的当前可枚举窗口，再把注意力准确带回要继续的任务。",
    implementedStatus: "首个已实现工具",
    toolDetail: "悬停正在运行的 Dock 应用图标后查看预览卡片；选择卡片可切换目标窗口，右键卡片可使用当前可用的窗口操作。",
    toolBoundaries: "Dock Window Quick Look 当前能力",
    boundaryHover: "查看当前可枚举窗口预览",
    boundarySwitch: "选择卡片切换窗口",
    boundaryMenu: "右键使用可用窗口操作",
    toolMediaAction: "查看真实运行画面占位媒体",
    desktopModelLabel: "交互原理演示：可操作的抽象 Dock 桌面模型",
    principleDemo: "交互原理演示",
    modelStepsLabel: "Dock 窗口速览步骤控制器",
    modelStepsIntro: "用文字步骤查看同一交互原理",
    modelCurrentStage: "当前阶段：",
    modelStageDock: "停在 Dock",
    modelStageWindows: "查看窗口",
    modelStageSwitch: "切换窗口",
    modelStageActions: "窗口操作",
    modelDockControl: "查看当前可枚举窗口",
    modelWindowControl: "选择抽象窗口卡片并切换窗口",
    modelActionsControl: "打开抽象窗口操作菜单",
    modelStages: {
      dock: { progress: "步骤 1 / 4", title: "停在 Dock", description: "停在正在运行的 Dock 应用图标上。" },
      windows: { progress: "步骤 2 / 4", title: "查看窗口", description: "预览展示当前可枚举窗口，不是实时视频。" },
      switch: { progress: "步骤 3 / 4", title: "切换窗口", description: "选择抽象窗口卡片后，注意力回到目标窗口。" },
      actions: { progress: "步骤 4 / 4", title: "窗口操作", description: "展示当前可用窗口操作的位置。" }
    },
    modelNote: "抽象模型，不是产品界面截图",
    mediaEyebrow: "真实运行画面",
    mediaTitle: "真实运行画面",
    mediaCopy: "当前显示的是本地占位素材，不代表 App 真实运行画面。真实素材必须来自干净测试环境，并在人工审核后替换。",
    mediaPending: "真实演示素材尚待干净测试环境采集与人工审核。",
    mediaVideoLabel: "Dock Window Quick Look 占位视频，不是 App 运行录屏",
    mediaPlaceholderCaption: "占位内容：不代表 App 真实运行画面",
    mediaReserveMark: "占位素材 / 待替换",
    explorationEyebrow: "探索方向",
    explorationTitle: "Finder 右键新建文件",
    buildingStatus: "正在构建",
    explorationCopy: "从 Finder 文件夹空白区域开始，快速创建常用格式的本地文件。它是一个正在构建的 macOS 增益方向，不是当前可下载工具。",
    exploreGithubLink: "在 GitHub 探索项目",
    exploreGithub: "在 GitHub 探索项目",
    finderDirectionLabel: "新建 / 文件",
    acquireEyebrow: "获取区",
    acquireTitle: "获取公开测试版",
    acquireCopy: "公开 Release 出现匹配下载资产后，此处将从 GitHub 确认准确版本、日期和下载入口。在此之前，发行与源码信息只以 GitHub 为准。",
    acquireLoading: "正在确认 GitHub 公开 Release 状态",
    acquirePending: "暂无可验证的公开下载资产，请在 GitHub 查看项目与发行详情。",
    acquireUnavailable: "暂时无法确认版本或下载资产，请在 GitHub 查看最新状态。",
    acquireAvailable: "{version} 发布于 {date}",
    downloadBeta: "下载 {version} 的公开测试版",
    releaseDetailsForVersion: "在 GitHub 查看 {version} 发行详情",
    requirementLabel: "系统要求",
    requirementValue: "macOS 14 或更高版本",
    permissionLabel: "需要授权",
    permissionValue: "辅助功能与屏幕录制",
    releaseLabel: "发行状态",
    releaseValue: "未公证公开测试版",
    releaseDetailsLink: "在 GitHub 查看 zongMacTools 发行详情",
    releaseDetails: "在 GitHub 查看发行详情",
    footerCopy: "面向 macOS 的桌面工具集合。",
    privacyCopy: "本站不收集个人数据。"
  },
  en: {
    title: "zongMacTools | Desktop tools for macOS",
    description: "zongMacTools grows better desktop experiences for the Mac. Its first implemented tool is Dock Window Quick Look.",
    ogDescription: "Desktop interactions proven useful elsewhere, rebuilt for macOS, plus tools that fill everyday macOS gaps.",
    ogLocale: "en_US",
    skipLink: "Skip to main content",
    primaryNavigation: "Primary navigation",
    homeLink: "zongMacTools home",
    toolNav: "View tool case study",
    languageSwitch: "切换为中文",
    githubSourceLink: "View zongMacTools source on GitHub",
    githubSource: "Source on GitHub",
    heroEyebrow: "Continuous desktop narrative",
    heroStatement: "Better desktop experiences, grown for the Mac.",
    heroSummary: "We rebuild useful, proven desktop interactions for macOS and fill the everyday details that deserve to work better on a Mac.",
    heroAction: "See the first tool",
    continueReading: "Continue reading",
    heroDeviceLabel: "Z / DESKTOP INPUT",
    originsEyebrow: "Where tools begin",
    originsTitle: "Why zongMacTools",
    originsSummary: "Some useful experiences have proved themselves elsewhere, yet need to be rebuilt for how macOS works. Others are everyday gaps worth filling directly for the Mac.",
    originRail: "The origins of zongMacTools tools",
    migrationKicker: "Experience migration path",
    migrationTitle: "Experience migration tools",
    migrationCopy: "Starting from interaction patterns proven on other desktop systems, then rebuilding them around macOS habits, system boundaries, and public APIs instead of copying another interface.",
    gainKicker: "Everyday macOS gaps",
    gainTitle: "macOS gain tools",
    gainCopy: "Not derived from another platform. These tools improve everyday Mac work where a small missing detail deserves a deliberate, native-feeling answer.",
    toolEyebrow: "First implemented tool",
    toolTitle: "Dock Window Quick Look",
    toolSummary: "Pause on the Dock, identify the currently enumerable windows of a running app, then return precisely to the task you meant to continue.",
    implementedStatus: "First implemented tool",
    toolDetail: "Hover a running Dock app to view preview cards. Select a card to switch windows, or use the available window actions from a card's context menu.",
    toolBoundaries: "Current Dock Window Quick Look capabilities",
    boundaryHover: "Preview currently enumerable windows",
    boundarySwitch: "Select a card to switch windows",
    boundaryMenu: "Use available actions from the context menu",
    toolMediaAction: "View the real-run media placeholder",
    desktopModelLabel: "Interaction principle demonstration: an operable abstract Dock desktop model",
    principleDemo: "Interaction principle demonstration",
    modelStepsLabel: "Dock Window Quick Look step controls",
    modelStepsIntro: "Use the text steps to inspect the same interaction principle",
    modelCurrentStage: "Current stage:",
    modelStageDock: "Pause on the Dock",
    modelStageWindows: "View windows",
    modelStageSwitch: "Switch windows",
    modelStageActions: "Window actions",
    modelDockControl: "View currently enumerable windows",
    modelWindowControl: "Select an abstract window card and switch windows",
    modelActionsControl: "Open the abstract window actions menu",
    modelStages: {
      dock: { progress: "Step 1 of 4", title: "Pause on the Dock", description: "Pause on a running app in the Dock." },
      windows: { progress: "Step 2 of 4", title: "View windows", description: "The previews show currently enumerable windows, not live video." },
      switch: { progress: "Step 3 of 4", title: "Switch windows", description: "Select an abstract window card to return attention to the target window." },
      actions: { progress: "Step 4 of 4", title: "Window actions", description: "Show where the currently available window actions appear." }
    },
    modelNote: "Abstract model, not a product interface screenshot",
    mediaEyebrow: "Real running footage",
    mediaTitle: "Real running footage",
    mediaCopy: "This is local placeholder media, not real App footage. Replace it only with media captured in a clean test environment and reviewed by hand.",
    mediaPending: "Real demonstration media is pending clean-environment capture and manual review.",
    mediaVideoLabel: "Dock Window Quick Look placeholder video, not an App screen recording",
    mediaPlaceholderCaption: "Placeholder content: not real App footage",
    mediaReserveMark: "PLACEHOLDER MEDIA / REPLACE AFTER REVIEW",
    explorationEyebrow: "Exploration direction",
    explorationTitle: "Create new files from Finder",
    buildingStatus: "Built in progress",
    explorationCopy: "Starting from empty space in a Finder folder, create common local file formats quickly. This is a macOS gain direction under construction, not a tool available to download today.",
    exploreGithubLink: "Explore the project on GitHub",
    exploreGithub: "Explore on GitHub",
    finderDirectionLabel: "NEW / FILE",
    acquireEyebrow: "Acquire",
    acquireTitle: "Get the public beta",
    acquireCopy: "Once a public GitHub Release has a matching download asset, this area will confirm its exact version, date, and download. Until then, GitHub remains the only source for release and source details.",
    acquireLoading: "Checking the public GitHub Release status",
    acquirePending: "No verifiable public download asset is available. View the project and releases on GitHub.",
    acquireUnavailable: "The version and download asset cannot be confirmed. View the latest status on GitHub.",
    acquireAvailable: "{version} published on {date}",
    downloadBeta: "Download the {version} public beta",
    releaseDetailsForVersion: "View {version} release details on GitHub",
    requirementLabel: "System",
    requirementValue: "macOS 14 or later",
    permissionLabel: "Permissions",
    permissionValue: "Accessibility and Screen Recording",
    releaseLabel: "Release state",
    releaseValue: "Unnotarized public beta",
    releaseDetailsLink: "View zongMacTools release details on GitHub",
    releaseDetails: "Release details on GitHub",
    footerCopy: "A collection of desktop tools for macOS.",
    privacyCopy: "This site does not collect personal data."
  }
};

const languageSwitch = document.querySelector("#language-switch");
const desktopModel = document.querySelector(".desktop-model");
const modelStageButtons = document.querySelectorAll("[data-model-stage]");
const modelStageTitle = document.querySelector("[data-model-stage-title]");
const modelStageDescription = document.querySelector("[data-model-stage-description]");
const modelProgress = document.querySelector("[data-model-progress]");
const modelCurrentStage = document.querySelector("[data-model-current-stage]");
const modelScene = document.querySelector(".model-scene");
const acquireState = document.querySelector("#acquire-state");
const downloadBeta = document.querySelector("#download-beta");
const releaseDetails = document.querySelector("#release-details");
const mediaVideo = document.querySelector("#media-video");
const motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
const desktopPointerQuery = window.matchMedia("(hover: hover) and (pointer: fine)");
const modelStageOrder = ["dock", "windows", "switch", "actions"];
let activeLanguage = "zh";
let activeModelStage = "dock";
let scrollFrame;
let modelHasDirectInteraction = false;
let currentReleaseState = { kind: "loading" };

function preferredLanguage() {
  try {
    const saved = localStorage.getItem(languageStorageKey);
    if (saved === "zh" || saved === "en") {
      return saved;
    }
  } catch {
    // Local storage may be unavailable in a privacy-restricted context.
  }

  return navigator.languages?.some((language) => language.toLowerCase().startsWith("zh")) ? "zh" : "en";
}

function setMeta(name, content) {
  document.querySelector(name)?.setAttribute("content", content);
}

function renderLanguage(language, { persist = false } = {}) {
  const copy = messages[language];
  activeLanguage = language;
  document.documentElement.lang = language === "zh" ? "zh-Hans" : "en";
  document.title = copy.title;
  setMeta('meta[name="description"]', copy.description);
  setMeta('meta[property="og:title"]', copy.title);
  setMeta('meta[property="og:description"]', copy.ogDescription);
  setMeta('meta[property="og:locale"]', copy.ogLocale);
  setMeta('meta[name="twitter:title"]', copy.title);
  setMeta('meta[name="twitter:description"]', copy.ogDescription);

  document.querySelectorAll("[data-i18n]").forEach((element) => {
    const key = element.dataset.i18n;
    if (copy[key]) {
      element.textContent = copy[key];
    }
  });

  document.querySelectorAll("[data-i18n-aria-label]").forEach((element) => {
    const key = element.dataset.i18nAriaLabel;
    if (copy[key]) {
      element.setAttribute("aria-label", copy[key]);
    }
  });

  languageSwitch.dataset.language = language;
  renderModelStage();
  renderReleaseState();

  if (persist) {
    try {
      localStorage.setItem(languageStorageKey, language);
    } catch {
      // Language switching remains available even when persistence is unavailable.
    }
  }
}

function formatCopy(template, values) {
  return Object.entries(values).reduce((copy, [key, value]) => copy.replace(`{${key}}`, value), template);
}

function localizedReleaseDate(isoDate) {
  return new Intl.DateTimeFormat(activeLanguage === "zh" ? "zh-CN" : "en-US", {
    year: "numeric",
    month: "long",
    day: "numeric"
  }).format(new Date(isoDate));
}

function renderReleaseState() {
  if (!acquireState || !downloadBeta || !releaseDetails) {
    return;
  }

  const copy = messages[activeLanguage];
  const available = currentReleaseState.kind === "available";
  const stateCopy = available
    ? formatCopy(copy.acquireAvailable, { version: currentReleaseState.tagName, date: localizedReleaseDate(currentReleaseState.publishedAt) })
    : copy[`acquire${currentReleaseState.kind[0].toUpperCase()}${currentReleaseState.kind.slice(1)}`];

  acquireState.dataset.state = currentReleaseState.kind;
  acquireState.textContent = stateCopy;
  downloadBeta.hidden = !available;
  releaseDetails.href = available ? currentReleaseState.releaseUrl : GITHUB_RELEASES_URL;

  if (available) {
    const downloadCopy = formatCopy(copy.downloadBeta, { version: currentReleaseState.tagName });
    downloadBeta.href = currentReleaseState.assetUrl;
    downloadBeta.textContent = downloadCopy;
    downloadBeta.setAttribute("aria-label", downloadCopy);
    const detailsCopy = formatCopy(copy.releaseDetailsForVersion, { version: currentReleaseState.tagName });
    releaseDetails.textContent = copy.releaseDetails;
    releaseDetails.setAttribute("aria-label", detailsCopy);
    return;
  }

  downloadBeta.removeAttribute("href");
  downloadBeta.removeAttribute("aria-label");
  releaseDetails.textContent = copy.releaseDetails;
  releaseDetails.setAttribute("aria-label", copy.releaseDetailsLink);
}

async function loadReleaseState() {
  currentReleaseState = { kind: "loading" };
  renderReleaseState();
  currentReleaseState = await fetchReleaseState();
  renderReleaseState();
}

function renderModelStage() {
  if (!desktopModel || !modelStageTitle || !modelStageDescription || !modelProgress || !modelCurrentStage) {
    return;
  }

  const stage = messages[activeLanguage].modelStages[activeModelStage];
  desktopModel.dataset.stage = activeModelStage;
  modelStageTitle.textContent = stage.title;
  modelStageDescription.textContent = stage.description;
  modelProgress.textContent = stage.progress;
  modelCurrentStage.textContent = `${messages[activeLanguage].modelCurrentStage} ${stage.title}`;

  modelStageButtons.forEach((button) => {
    button.setAttribute("aria-pressed", String(button.dataset.modelStage === activeModelStage));
  });
}

function setModelStage(stage, { source = "direct" } = {}) {
  if (!modelStageOrder.includes(stage)) {
    return;
  }

  if (source !== "scroll" && scrollFrame !== undefined) {
    window.cancelAnimationFrame(scrollFrame);
    scrollFrame = undefined;
  }

  if (source !== "scroll") {
    modelHasDirectInteraction = true;
  }

  if (stage === activeModelStage) {
    return;
  }

  activeModelStage = stage;
  renderModelStage();
}

function isDesktopPointer() {
  return window.innerWidth >= 768 && desktopPointerQuery.matches;
}

function updateModelSceneAccessibility() {
  modelScene?.setAttribute("aria-hidden", String(!isDesktopPointer()));
}

function syncModelStageWithScroll() {
  scrollFrame = undefined;

  if (!desktopModel || !isDesktopPointer() || modelHasDirectInteraction) {
    return;
  }

  const { top } = desktopModel.getBoundingClientRect();
  const start = window.innerHeight * 0.78;
  const end = window.innerHeight * 0.22;
  const progress = Math.min(1, Math.max(0, (start - top) / (start - end)));
  const stageIndex = Math.min(modelStageOrder.length - 1, Math.floor(progress * modelStageOrder.length));
  setModelStage(modelStageOrder[stageIndex], { source: "scroll" });
}

function scheduleModelScrollSync() {
  if (scrollFrame === undefined) {
    scrollFrame = window.requestAnimationFrame(syncModelStageWithScroll);
  }
}

function resumeScrollNarrative() {
  modelHasDirectInteraction = false;
  scheduleModelScrollSync();
}

function updateMotionState() {
  const reduced = motionQuery.matches;
  document.documentElement.dataset.reducedMotion = String(reduced);
  document.querySelectorAll(".desktop-model").forEach((model) => {
    model.dataset.motion = reduced ? "reduced" : "full";
  });
  updateModelSceneAccessibility();
  updateMediaPlayback();
  scheduleModelScrollSync();
}

function updateMediaPlayback() {
  if (!mediaVideo) {
    return;
  }

  const canAutoplay = !motionQuery.matches && window.innerWidth > 620;
  mediaVideo.autoplay = canAutoplay;

  if (!canAutoplay) {
    mediaVideo.pause();
    return;
  }

  mediaVideo.play().catch(() => {});
}

languageSwitch.addEventListener("click", () => {
  const nextLanguage = languageSwitch.dataset.language === "zh" ? "en" : "zh";
  renderLanguage(nextLanguage, { persist: true });
});

modelStageButtons.forEach((button) => {
  button.addEventListener("click", () => setModelStage(button.dataset.modelStage));
});

document.querySelectorAll("[data-model-action]").forEach((control) => {
  control.addEventListener("click", () => {
    if (isDesktopPointer()) {
      setModelStage(control.dataset.modelAction);
    }
  });
});

document.querySelectorAll(".model-window").forEach((windowCard) => {
  windowCard.addEventListener("contextmenu", (event) => {
    if (!isDesktopPointer()) {
      return;
    }

    event.preventDefault();
    setModelStage("actions");
  });
});

document.querySelector(".model-dock")?.addEventListener("pointerenter", () => {
  if (isDesktopPointer()) {
    setModelStage("windows");
  }
});

desktopModel?.addEventListener("pointerleave", () => {
  if (isDesktopPointer()) {
    resumeScrollNarrative();
  }
});

window.addEventListener("scroll", scheduleModelScrollSync, { passive: true });
window.addEventListener("wheel", resumeScrollNarrative, { passive: true });
window.addEventListener("keydown", (event) => {
  if (["ArrowDown", "ArrowUp", "PageDown", "PageUp", "Home", "End"].includes(event.key)) {
    resumeScrollNarrative();
  }
});
window.addEventListener("resize", () => {
  updateModelSceneAccessibility();
  updateMediaPlayback();
  scheduleModelScrollSync();
});

if (typeof desktopPointerQuery.addEventListener === "function") {
  desktopPointerQuery.addEventListener("change", () => {
    updateModelSceneAccessibility();
    scheduleModelScrollSync();
  });
} else {
  desktopPointerQuery.addListener(() => {
    updateModelSceneAccessibility();
    scheduleModelScrollSync();
  });
}

if (typeof motionQuery.addEventListener === "function") {
  motionQuery.addEventListener("change", updateMotionState);
} else {
  motionQuery.addListener(updateMotionState);
}

renderLanguage(preferredLanguage());
updateMotionState();
scheduleModelScrollSync();
loadReleaseState();
