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
    toolMediaAction: "查看真实运行画面预留",
    desktopModelLabel: "交互原理演示：从 Dock 停留到窗口预览的抽象桌面模型",
    principleDemo: "交互原理演示",
    modelNote: "抽象模型，不是产品界面截图",
    mediaEyebrow: "真实运行画面",
    mediaTitle: "真实运行画面",
    mediaCopy: "交互原理演示之后，这里将接入来自干净测试环境、经人工审阅的短静音本地素材，用于证明当前能力而不混淆网页模型与 App 界面。",
    mediaPending: "真实演示素材尚待干净测试环境采集与人工审核。",
    mediaReserveLabel: "真实运行画面素材预留，尚未接入视频或海报图",
    mediaReserveMark: "本地素材 / 待审核",
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
    acquirePending: "正在等待 GitHub 公开 Release 状态",
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
    desktopModelLabel: "Interaction principle demonstration: an abstract desktop model from a Dock pause to window previews",
    principleDemo: "Interaction principle demonstration",
    modelNote: "Abstract model, not a product interface screenshot",
    mediaEyebrow: "Real running footage",
    mediaTitle: "Real running footage",
    mediaCopy: "After the interaction principle demonstration, this area will hold short, muted local media captured in a clean test environment and reviewed by hand. It will prove current behavior without conflating the web model with the app interface.",
    mediaPending: "Real demonstration media is pending clean-environment capture and manual review.",
    mediaReserveLabel: "Reserved space for real running footage, with no video or poster image connected yet",
    mediaReserveMark: "LOCAL MEDIA / PENDING REVIEW",
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
    acquirePending: "Waiting for a public GitHub Release status",
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
const motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");

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

  if (persist) {
    try {
      localStorage.setItem(languageStorageKey, language);
    } catch {
      // Language switching remains available even when persistence is unavailable.
    }
  }
}

function updateMotionState() {
  const reduced = motionQuery.matches;
  document.documentElement.dataset.reducedMotion = String(reduced);
  document.querySelectorAll(".desktop-model").forEach((model) => {
    model.dataset.motion = reduced ? "reduced" : "full";
  });
}

languageSwitch.addEventListener("click", () => {
  const nextLanguage = languageSwitch.dataset.language === "zh" ? "en" : "zh";
  renderLanguage(nextLanguage, { persist: true });
});

if (typeof motionQuery.addEventListener === "function") {
  motionQuery.addEventListener("change", updateMotionState);
} else {
  motionQuery.addListener(updateMotionState);
}

renderLanguage(preferredLanguage());
updateMotionState();
