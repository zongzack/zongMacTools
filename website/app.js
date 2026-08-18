import { GITHUB_RELEASES_URL, fetchReleaseState } from "./release-state.js";

const languageStorageKey = "zongmactools-site-language";
const demoStageOrder = ["dock", "windows", "switch", "actions"];

const messages = {
  zh: {
    title: "zongMacTools | 让更好的桌面体验，在 Mac 上继续生长",
    description:
      "zongMacTools 把其他桌面系统中已验证有用的交互重新做成适合 macOS 的工具，也补齐 macOS 日常操作的效率空白。首个已实现工具是 Dock Window Quick Look（Dock 窗口速览）。",
    ogDescription: "把已被验证有用的桌面体验重新做成适合 macOS 的工具，也补齐值得被补上的 macOS 日常操作细节。",
    ogLocale: "zh_CN",
    skipLink: "跳至主要内容",
    primaryNavigation: "主导航",
    homeLink: "zongMacTools 首页",
    toolNav: "工具案例",
    languageSwitch: "Switch to English",
    githubSourceLink: "在 GitHub 查看 zongMacTools 源码（新标签页打开）",
    githubSource: "GitHub 源码",
    githubSourceShort: "GitHub 源码",
    heroEyebrow: "macOS 桌面工具集合",
    heroStatement: "让更好的桌面体验，在 Mac 上继续生长。",
    heroSummary: "把其他桌面系统中已验证有用的交互，重新做成符合 macOS 使用方式的工具；也为 Mac 补上那些值得被补上的日常操作细节。",
    heroAction: "查看首个工具",
    heroHint: "向下滚动，沿着一个连续的 macOS 桌面了解这个工具集合。",
    originsEyebrow: "工具来源",
    originsTitle: "为什么是 zongMacTools",
    originsSummary:
      "有些好用的体验已在别的桌面系统里证明过自己，但需要重新做成符合 macOS 使用方式的工具；也有些 Mac 日常操作里的效率空白，值得被直接补上。zongMacTools 沿着这两条路径持续构建。",
    migrationTag: "体验迁移工具",
    migrationTitle: "已在别处验证，为 Mac 重做",
    migrationCopy: "从其他桌面系统中被反复验证的交互出发，按照 macOS 的习惯、系统边界和公开 API 重新实现。迁移的是体验，不是界面复刻。",
    gainTag: "macOS 增益工具",
    gainTitle: "直接补齐 Mac 的效率空白",
    gainCopy: "不以其他平台为起点，从 Mac 日常操作里真实遇到的别扭细节出发，给出顺手、克制、像系统自带一样的答案。",
    toolEyebrow: "首个工具",
    toolTitle: "Dock Window Quick Look（Dock 窗口速览）",
    implementedStatus: "首个已实现工具",
    toolSummary: "停在 Dock 上正在运行的应用图标，查看它当前可枚举的窗口；选择预览卡片切换窗口，或在卡片上右键使用当前可用的窗口操作。",
    demoLabel: "交互原理演示：可操作的抽象 Dock 桌面模型",
    demoBadge: "交互原理演示 · 抽象模型，不是产品界面截图",
    demoStepsLabel: "Dock 窗口速览步骤控制器",
    demoStepsIntro: "使用文字步骤查看同一交互原理：",
    stageDock: "停在 Dock",
    stageWindows: "查看窗口",
    stageSwitch: "切换窗口",
    stageActions: "窗口操作",
    demoStages: {
      dock: { progress: "步骤 1 / 4", title: "停在 Dock", description: "指针停在正在运行的 Dock 应用图标上。" },
      windows: { progress: "步骤 2 / 4", title: "查看窗口", description: "预览展示当前可枚举窗口的静态缩略图，不是实时视频。" },
      switch: { progress: "步骤 3 / 4", title: "切换窗口", description: "选择预览卡片后，目标窗口被激活并来到前景。" },
      actions: { progress: "步骤 4 / 4", title: "窗口操作", description: "在预览卡片上右键，可使用当前可用的窗口操作。" }
    },
    boundaryListLabel: "Dock Window Quick Look 当前能力",
    boundaryHover: "悬停 Dock 图标，预览当前可枚举窗口（静态缩略图，非实时视频）",
    boundarySwitch: "选择预览卡片，切换并激活目标窗口",
    boundaryMenu: "在卡片上右键，使用当前可用的窗口操作",
    boundaryNote: "不承诺实时预览、跨 Space 窗口、恢复最小化窗口或多显示器行为；这些边界以 GitHub 发行详情为准。",
    toolMediaLink: "接着查看真实运行画面",
    mediaEyebrow: "真实运行画面",
    mediaTitle: "Dock 窗口速览运行录屏",
    mediaReviewMark: "素材预览 / 待审核",
    mediaCopy:
      "以下画面来自本地录屏，覆盖停在 Dock、预览出现、选择窗口卡片与打开右键窗口操作菜单。正式发布前，所有素材还需在干净测试环境完成人工隐私与能力一致性审核；当前仅作为占位预览。",
    mediaVideoLabel: "Dock Window Quick Look 本地录屏预览，发布前待审核",
    mediaPosterAlt: "本地录屏海报帧：Dock 预览卡片旁打开窗口操作菜单，发布前待审核",
    mediaCaption: "本地录屏预览（待审核）：悬停 Dock、预览出现、选择窗口与窗口操作。",
    mediaStillsLabel: "Dock Window Quick Look 录屏关键帧",
    stillPreviewAlt: "录屏关键帧：运行中应用的多个窗口预览卡片出现在 Dock 上方",
    stillPreviewCaption: "预览出现",
    stillSwitchAlt: "录屏关键帧：选择预览卡片后目标窗口来到前景",
    stillSwitchCaption: "切换窗口",
    stillActionsAlt: "录屏关键帧：预览卡片上打开可用窗口操作菜单",
    stillActionsCaption: "窗口操作",
    explorationEyebrow: "探索方向",
    explorationTitle: "Finder 右键新建文件",
    buildingStatus: "正在构建",
    explorationCopy:
      "目标工作流：在 Finder 文件夹的空白区域右键，直接新建常用格式的本地文件。这是一个正在构建的 macOS 增益方向，今天还不能下载，也不提供时间承诺或订阅入口。",
    exploreGithubLink: "在 GitHub 探索 zongMacTools 项目（新标签页打开）",
    exploreGithub: "在 GitHub 探索项目",
    acquireEyebrow: "获取区",
    acquireTitle: "获取公开测试版",
    acquireCopy: "下载资产与发行详情的唯一事实来源是 GitHub Release。这里只读取公开 Release 状态；无法确认时，请直接以 GitHub 为准。",
    acquireLoading: "正在确认 GitHub 公开 Release 状态…",
    acquirePending: "暂无可验证的公开下载资产。请前往 GitHub 查看项目与发行详情。",
    acquireUnavailable: "暂时无法确认版本或下载资产。请前往 GitHub 查看最新状态。",
    acquireAvailable: "{version} · 发布于 {date}",
    downloadBeta: "下载公开测试版",
    downloadBetaForVersion: "下载 {version} 公开测试版（ZIP）",
    releaseDetails: "GitHub 发行详情",
    releaseDetailsLink: "在 GitHub 查看 zongMacTools 发行详情（新标签页打开）",
    releaseDetailsForVersion: "在 GitHub 查看 {version} 发行详情（新标签页打开）",
    requirementLabel: "系统要求",
    requirementValue: "macOS 14 或更高版本",
    permissionLabel: "需要授权",
    permissionValue: "辅助功能与屏幕录制",
    releaseLabel: "发行状态",
    releaseValue: "未公证公开测试版",
    acquireNote: "完整安装、校验、签名、权限引导与已知限制，请以 GitHub 发行详情为准。",
    footerCopy: "面向 macOS 的桌面工具集合，沿连续桌面叙事持续生长。",
    privacyCopy: "本站为无数据站点：不收集个人数据，不使用 Cookie、分析或第三方媒体服务。"
  },
  en: {
    title: "zongMacTools | Better desktop experiences, grown for the Mac",
    description:
      "zongMacTools rebuilds desktop interactions that proved useful elsewhere into tools that feel at home on macOS, and fills everyday macOS efficiency gaps. Its first implemented tool is Dock Window Quick Look.",
    ogDescription: "Proven desktop interactions rebuilt for macOS, plus tools that fill the everyday gaps worth filling on a Mac.",
    ogLocale: "en_US",
    skipLink: "Skip to main content",
    primaryNavigation: "Primary navigation",
    homeLink: "zongMacTools home",
    toolNav: "Tool case study",
    languageSwitch: "切换为中文",
    githubSourceLink: "View the zongMacTools source on GitHub (opens in a new tab)",
    githubSource: "Source on GitHub",
    githubSourceShort: "Source on GitHub",
    heroEyebrow: "Desktop tools for macOS",
    heroStatement: "Better desktop experiences, grown for the Mac.",
    heroSummary:
      "We take interactions that proved useful on other desktop systems and rebuild them the macOS way — and we fill the everyday details that deserve a better answer on the Mac.",
    heroAction: "See the first tool",
    heroHint: "Scroll to follow one continuous macOS desktop through this tool collection.",
    originsEyebrow: "Where tools begin",
    originsTitle: "Why zongMacTools",
    originsSummary:
      "Some useful experiences have already proved themselves on other desktop systems, yet need to be rebuilt for how macOS works. Others are everyday efficiency gaps on the Mac that deserve to be filled directly. zongMacTools keeps building along both paths.",
    migrationTag: "Experience migration tools",
    migrationTitle: "Proven elsewhere, rebuilt for the Mac",
    migrationCopy:
      "Starting from interactions validated on other desktop systems, rebuilt around macOS habits, system boundaries, and public APIs. What migrates is the experience, not a copy of someone's interface.",
    gainTag: "macOS gain tools",
    gainTitle: "Filling the Mac's efficiency gaps",
    gainCopy:
      "Not derived from another platform. These start from real friction in everyday Mac work and answer it with something that feels native and restrained.",
    toolEyebrow: "The first tool",
    toolTitle: "Dock Window Quick Look",
    implementedStatus: "First implemented tool",
    toolSummary:
      "Pause on a running app's Dock icon to see its currently enumerable windows. Select a preview card to switch windows, or right-click a card for the window actions available today.",
    demoLabel: "Interaction principle demonstration: an operable abstract Dock desktop model",
    demoBadge: "Interaction principle demonstration · abstract model, not a product screenshot",
    demoStepsLabel: "Dock Window Quick Look step controls",
    demoStepsIntro: "Inspect the same interaction principle with text steps:",
    stageDock: "Pause on the Dock",
    stageWindows: "View windows",
    stageSwitch: "Switch windows",
    stageActions: "Window actions",
    demoStages: {
      dock: { progress: "Step 1 of 4", title: "Pause on the Dock", description: "The pointer pauses on a running app's Dock icon." },
      windows: {
        progress: "Step 2 of 4",
        title: "View windows",
        description: "The preview shows static thumbnails of currently enumerable windows, not live video."
      },
      switch: {
        progress: "Step 3 of 4",
        title: "Switch windows",
        description: "Selecting a preview card activates the target window and brings it forward."
      },
      actions: {
        progress: "Step 4 of 4",
        title: "Window actions",
        description: "Right-clicking a preview card offers the window actions available today."
      }
    },
    boundaryListLabel: "Current Dock Window Quick Look capabilities",
    boundaryHover: "Hover a Dock icon to preview currently enumerable windows (static thumbnails, not live video)",
    boundarySwitch: "Select a preview card to switch to and activate the target window",
    boundaryMenu: "Right-click a card to use the window actions available today",
    boundaryNote:
      "No live previews, cross-Space windows, minimized-window recovery, or multi-display behavior is promised; the GitHub release details remain the source of truth for these boundaries.",
    toolMediaLink: "Continue to the real running footage",
    mediaEyebrow: "Real running footage",
    mediaTitle: "Dock Window Quick Look in action",
    mediaReviewMark: "FOOTAGE PREVIEW / REVIEW PENDING",
    mediaCopy:
      "The footage below comes from a local recording and covers pausing on the Dock, the preview appearing, selecting a window card, and opening the window actions menu. Before public release, every asset still needs a human privacy and capability review in a clean test environment; for now it serves only as a placeholder preview.",
    mediaVideoLabel: "Dock Window Quick Look local recording preview, pending release review",
    mediaPosterAlt: "Recording poster frame: window actions menu open beside Dock preview cards, pending release review",
    mediaCaption: "Local recording preview (pending review): Dock hover, preview appearing, window switching, and window actions.",
    mediaStillsLabel: "Dock Window Quick Look recording key frames",
    stillPreviewAlt: "Recording key frame: preview cards for a running app's windows appear above the Dock",
    stillPreviewCaption: "Preview appears",
    stillSwitchAlt: "Recording key frame: the target window comes to the foreground after selecting a preview card",
    stillSwitchCaption: "Switch window",
    stillActionsAlt: "Recording key frame: the available window actions menu open on a preview card",
    stillActionsCaption: "Window actions",
    explorationEyebrow: "Exploration direction",
    explorationTitle: "Create new files from Finder",
    buildingStatus: "Under construction",
    explorationCopy:
      "The target workflow: right-click empty space in a Finder folder and create a new local file in a common format. This macOS gain direction is under construction — no download, release date, or waitlist today.",
    exploreGithubLink: "Explore the zongMacTools project on GitHub (opens in a new tab)",
    exploreGithub: "Explore the project on GitHub",
    acquireEyebrow: "Acquire",
    acquireTitle: "Get the public beta",
    acquireCopy:
      "GitHub Releases are the single source of truth for download assets and release details. This area only reads the public release state; when it cannot be confirmed, GitHub is the place to check.",
    acquireLoading: "Checking the public GitHub Release status…",
    acquirePending: "No verifiable public download asset yet. Visit GitHub for the project and release details.",
    acquireUnavailable: "The version and download asset cannot be confirmed right now. Visit GitHub for the latest status.",
    acquireAvailable: "{version} · published on {date}",
    downloadBeta: "Download the public beta",
    downloadBetaForVersion: "Download the {version} public beta (ZIP)",
    releaseDetails: "Release details on GitHub",
    releaseDetailsLink: "View zongMacTools release details on GitHub (opens in a new tab)",
    releaseDetailsForVersion: "View {version} release details on GitHub (opens in a new tab)",
    requirementLabel: "System",
    requirementValue: "macOS 14 or later",
    permissionLabel: "Permissions",
    permissionValue: "Accessibility and Screen Recording",
    releaseLabel: "Release state",
    releaseValue: "Unnotarized public beta",
    acquireNote: "For full installation, verification, signature, permission guidance, and known limitations, refer to the GitHub release details.",
    footerCopy: "A collection of desktop tools for macOS, growing along one continuous desktop narrative.",
    privacyCopy: "This is a no-data site: no personal data collection, no cookies, no analytics, and no third-party media services."
  }
};

const languageToggle = document.querySelector("#language-toggle");
const demo = document.querySelector("#demo");
const demoStepButtons = document.querySelectorAll("[data-demo-stage]");
const demoProgress = document.querySelector("[data-demo-progress]");
const demoStageTitle = document.querySelector("[data-demo-stage-title]");
const demoStageDescription = document.querySelector("[data-demo-stage-description]");
const sceneDockControl = document.querySelector("[data-demo-hover]");
const acquireStatus = document.querySelector("#acquire-status");
const downloadAction = document.querySelector("#download-action");
const releaseAction = document.querySelector("#release-action");
const mediaVideo = document.querySelector("#quicklook-video");

const motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
const finePointerQuery = window.matchMedia("(hover: hover) and (pointer: fine)");

// 与 styles.css 断点保持一致：44rem 窄屏媒体查询对应 704px（根字号 16px）。
const desktopPointerMinWidth = 768;
const videoAutoplayMinWidth = 704;

let activeLanguage = "zh";
let activeDemoStage = "dock";
let releaseState = { kind: "loading" };
let scrollFrame;
let demoTouchedDirectly = false;
let mediaOnScreen = false;

/* ---------- 语言 ---------- */

function preferredLanguage() {
  try {
    const saved = localStorage.getItem(languageStorageKey);
    if (saved === "zh" || saved === "en") {
      return saved;
    }
  } catch {
    // 隐私受限环境下 localStorage 可能不可用，退回浏览器语言。
  }

  return navigator.languages?.some((language) => language.toLowerCase().startsWith("zh")) ? "zh" : "en";
}

function setMetaContent(selector, content) {
  document.querySelector(selector)?.setAttribute("content", content);
}

function fillTemplate(template, values) {
  return Object.entries(values).reduce((text, [key, value]) => text.replace(`{${key}}`, value), template);
}

function renderLanguage(language, { persist = false } = {}) {
  const copy = messages[language];
  activeLanguage = language;
  document.documentElement.lang = language === "zh" ? "zh-Hans" : "en";
  document.title = copy.title;
  setMetaContent('meta[name="description"]', copy.description);
  setMetaContent('meta[property="og:title"]', copy.title);
  setMetaContent('meta[property="og:description"]', copy.ogDescription);
  setMetaContent('meta[property="og:locale"]', copy.ogLocale);
  setMetaContent('meta[name="twitter:title"]', copy.title);
  setMetaContent('meta[name="twitter:description"]', copy.ogDescription);

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

  document.querySelectorAll("[data-i18n-alt]").forEach((element) => {
    const key = element.dataset.i18nAlt;
    if (copy[key]) {
      element.setAttribute("alt", copy[key]);
    }
  });

  languageToggle.dataset.language = language;
  renderDemoStage();
  renderReleaseState();

  if (persist) {
    try {
      localStorage.setItem(languageStorageKey, language);
    } catch {
      // 无法持久化时，语言切换在本次会话内仍然可用。
    }
  }
}

/* ---------- 发布状态 ---------- */

function localizedReleaseDate(isoDate) {
  return new Intl.DateTimeFormat(activeLanguage === "zh" ? "zh-CN" : "en-US", {
    year: "numeric",
    month: "long",
    day: "numeric"
  }).format(new Date(isoDate));
}

function renderReleaseState() {
  if (!acquireStatus || !downloadAction || !releaseAction) {
    return;
  }

  const copy = messages[activeLanguage];
  const available = releaseState.kind === "available";

  acquireStatus.dataset.state = releaseState.kind;

  if (available) {
    acquireStatus.textContent = fillTemplate(copy.acquireAvailable, {
      version: releaseState.tagName,
      date: localizedReleaseDate(releaseState.publishedAt)
    });
  } else {
    const key = `acquire${releaseState.kind[0].toUpperCase()}${releaseState.kind.slice(1)}`;
    acquireStatus.textContent = copy[key];
  }

  downloadAction.hidden = !available;
  if (available) {
    const label = fillTemplate(copy.downloadBetaForVersion, { version: releaseState.tagName });
    downloadAction.href = releaseState.assetUrl;
    downloadAction.setAttribute("aria-label", label);
    downloadAction.textContent = `${copy.downloadBeta} · ${releaseState.tagName}`;
    releaseAction.href = releaseState.releaseUrl;
    releaseAction.setAttribute("aria-label", fillTemplate(copy.releaseDetailsForVersion, { version: releaseState.tagName }));
  } else {
    downloadAction.removeAttribute("href");
    downloadAction.removeAttribute("aria-label");
    downloadAction.textContent = copy.downloadBeta;
    releaseAction.href = GITHUB_RELEASES_URL;
    releaseAction.setAttribute("aria-label", copy.releaseDetailsLink);
  }
  releaseAction.textContent = copy.releaseDetails;
}

async function loadReleaseState() {
  releaseState = { kind: "loading" };
  renderReleaseState();
  releaseState = await fetchReleaseState();
  renderReleaseState();
}

/* ---------- 交互原理演示 ---------- */

function isFineDesktopPointer() {
  return window.innerWidth >= desktopPointerMinWidth && finePointerQuery.matches;
}

function renderDemoStage() {
  if (!demo || !demoProgress || !demoStageTitle || !demoStageDescription) {
    return;
  }

  const stage = messages[activeLanguage].demoStages[activeDemoStage];
  demo.dataset.stage = activeDemoStage;
  demoProgress.textContent = stage.progress;
  demoStageTitle.textContent = stage.title;
  demoStageDescription.textContent = stage.description;

  demoStepButtons.forEach((button) => {
    button.setAttribute("aria-pressed", String(button.dataset.demoStage === activeDemoStage));
  });
}

function setDemoStage(stage, { source = "direct" } = {}) {
  if (!demoStageOrder.includes(stage)) {
    return;
  }

  if (source !== "scroll") {
    demoTouchedDirectly = true;
    if (scrollFrame !== undefined) {
      window.cancelAnimationFrame(scrollFrame);
      scrollFrame = undefined;
    }
  }

  if (stage === activeDemoStage) {
    return;
  }

  activeDemoStage = stage;
  renderDemoStage();
}

function resumeScrollNarrative() {
  demoTouchedDirectly = false;
  scheduleDemoScrollSync();
}

function syncDemoStageWithScroll() {
  scrollFrame = undefined;

  if (!demo || !isFineDesktopPointer() || demoTouchedDirectly || motionQuery.matches) {
    return;
  }

  const { top } = demo.getBoundingClientRect();
  const start = window.innerHeight * 0.82;
  const end = window.innerHeight * 0.2;
  const progress = Math.min(1, Math.max(0, (start - top) / (start - end)));
  const stageIndex = Math.min(demoStageOrder.length - 1, Math.floor(progress * demoStageOrder.length));
  setDemoStage(demoStageOrder[stageIndex], { source: "scroll" });
}

function scheduleDemoScrollSync() {
  if (scrollFrame === undefined) {
    scrollFrame = window.requestAnimationFrame(syncDemoStageWithScroll);
  }
}

/* ---------- 媒体播放 ---------- */

function updateMediaPlayback() {
  if (!mediaVideo) {
    return;
  }

  // 自动播放只在适用环境发生：无减少动态效果偏好、足够宽的视口，且媒体区实际进入视野。
  const canAutoplay = !motionQuery.matches && window.innerWidth > videoAutoplayMinWidth && mediaOnScreen;
  mediaVideo.autoplay = canAutoplay;

  if (!canAutoplay) {
    mediaVideo.pause();
    return;
  }

  mediaVideo.play().catch(() => {
    // 自动播放被浏览器拒绝时，保留海报帧与控件。
  });
}

if (mediaVideo && typeof IntersectionObserver === "function") {
  new IntersectionObserver(
    (entries) => {
      mediaOnScreen = entries.some((entry) => entry.isIntersecting);
      updateMediaPlayback();
    },
    { threshold: 0.25 }
  ).observe(mediaVideo);
}

/* ---------- 减少动态效果 ---------- */

function updateMotionState() {
  document.documentElement.dataset.reducedMotion = String(motionQuery.matches);
  updateMediaPlayback();
  scheduleDemoScrollSync();
}

/* ---------- 事件 ---------- */

languageToggle.addEventListener("click", () => {
  renderLanguage(languageToggle.dataset.language === "zh" ? "en" : "zh", { persist: true });
});

demoStepButtons.forEach((button) => {
  button.addEventListener("click", () => setDemoStage(button.dataset.demoStage));
});

sceneDockControl?.addEventListener("pointerenter", () => {
  if (isFineDesktopPointer()) {
    setDemoStage(sceneDockControl.dataset.demoHover);
  }
});

sceneDockControl?.addEventListener("click", () => {
  if (isFineDesktopPointer()) {
    setDemoStage(sceneDockControl.dataset.demoHover);
  }
});

document.querySelectorAll("[data-demo-scene-card]").forEach((card) => {
  card.addEventListener("click", () => {
    if (isFineDesktopPointer()) {
      setDemoStage("switch");
    }
  });

  card.addEventListener("contextmenu", (event) => {
    if (!isFineDesktopPointer()) {
      return;
    }

    event.preventDefault();
    setDemoStage("actions");
  });
});

sceneDockControl?.addEventListener("contextmenu", (event) => {
  if (!isFineDesktopPointer()) {
    return;
  }

  event.preventDefault();
  setDemoStage("actions");
});

demo?.addEventListener("pointerleave", () => {
  if (isFineDesktopPointer()) {
    resumeScrollNarrative();
  }
});

window.addEventListener("scroll", scheduleDemoScrollSync, { passive: true });
window.addEventListener("wheel", resumeScrollNarrative, { passive: true });
window.addEventListener("keydown", (event) => {
  if (["ArrowDown", "ArrowUp", "PageDown", "PageUp", "Home", "End"].includes(event.key)) {
    resumeScrollNarrative();
  }
});
window.addEventListener("resize", () => {
  updateMediaPlayback();
  scheduleDemoScrollSync();
});

if (typeof finePointerQuery.addEventListener === "function") {
  finePointerQuery.addEventListener("change", scheduleDemoScrollSync);
} else {
  finePointerQuery.addListener(scheduleDemoScrollSync);
}

if (typeof motionQuery.addEventListener === "function") {
  motionQuery.addEventListener("change", updateMotionState);
} else {
  motionQuery.addListener(updateMotionState);
}

/* ---------- 启动 ---------- */

renderLanguage(preferredLanguage());
updateMotionState();
scheduleDemoScrollSync();
loadReleaseState();
