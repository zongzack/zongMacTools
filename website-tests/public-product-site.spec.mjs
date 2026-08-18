import { expect, test } from "@playwright/test";

test.use({ locale: "zh-CN" });

const githubRepositoryUrl = "https://github.com/zongzack/zongMacTools";
const githubReleasesUrl = `${githubRepositoryUrl}/releases`;
const githubReleasesApiUrl = "https://api.github.com/repos/zongzack/zongMacTools/releases?per_page=10";
const publicRelease = {
  draft: false,
  tag_name: "v0.2.0",
  published_at: "2026-08-14T12:00:00Z",
  html_url: `${githubReleasesUrl}/tag/v0.2.0`,
  assets: [{ name: "zongMacTools-0.2.0.zip", browser_download_url: `${githubReleasesUrl}/download/v0.2.0/zongMacTools-0.2.0.zip` }]
};

async function mockReleases(page, { status = 200, body = [] } = {}) {
  await page.unroute(githubReleasesApiUrl);
  await page.route(githubReleasesApiUrl, (route) => route.fulfill({ status, contentType: "application/json", body: JSON.stringify(body) }));
}

test.beforeEach(async ({ page }) => {
  await mockReleases(page);
});

test("访客按七段连续桌面叙事理解产品方向", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/");

  await expect(page.getByRole("heading", { level: 1, name: "zongMacTools" })).toBeVisible();
  await expect(page.getByText("让更好的桌面体验，在 Mac 上继续生长。")).toBeVisible();
  await expect(page.getByRole("link", { name: "查看首个工具" })).toBeVisible();

  const sectionTitles = await page.getByRole("heading", { level: 2 }).allTextContents();
  expect(sectionTitles).toEqual([
    "为什么是 zongMacTools",
    "Dock Window Quick Look（Dock 窗口速览）",
    "Dock 录屏素材预览",
    "Finder 右键新建文件",
    "获取公开测试版"
  ]);

  await expect(page.getByText("体验迁移工具", { exact: true })).toBeVisible();
  await expect(page.getByText("macOS 增益工具", { exact: true })).toBeVisible();
  await expect(page.locator(".status-cyan")).toHaveText("首个已实现工具");
  await expect(page.getByText("正在构建", { exact: true })).toBeVisible();
  await expect(page.getByText("这是从你提供的录屏截取的本地素材预览，用于确认页面布局；正式发布前需在干净测试环境重新审核。", { exact: true })).toBeVisible();
  await expect(page.getByText("素材预览 / 待审核", { exact: true })).toBeVisible();
  await expect(page.getByText("Z / 桌面输入", { exact: true })).toBeVisible();
  await expect(page.getByText("新建 / 文件", { exact: true })).toBeVisible();
});

test("顶栏仅提供品牌、工具、语言和 GitHub 源码入口", async ({ page }) => {
  await page.goto("/");

  const navigation = page.getByRole("navigation", { name: "主导航" });
  await expect(navigation.getByRole("link", { name: "zongMacTools 首页" })).toBeVisible();
  await expect(navigation.getByRole("link", { name: "查看工具案例" })).toBeVisible();
  await expect(navigation.getByRole("button", { name: "切换为英文" })).toBeVisible();
  await expect(navigation.getByRole("link", { name: "在 GitHub 查看 zongMacTools 源码" })).toHaveAttribute("target", "_blank");
  await expect(navigation.getByRole("link", { name: /下载|获取|安装/ })).toHaveCount(0);
  await expect(navigation.locator("[data-theme]")).toHaveCount(0);
});

test("中文和英文在整个公开站中同步切换并保留本地选择", async ({ page }) => {
  await page.goto("/");

  const languageSwitch = page.getByRole("button", { name: "切换为英文" });
  await languageSwitch.click();

  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await expect(page).toHaveTitle("zongMacTools | Desktop tools for macOS");
  await expect(page.getByText("Better desktop experiences, grown for the Mac.")).toBeVisible();
  await expect(page.getByRole("link", { name: "See the first tool" })).toBeVisible();
  await expect(page.getByText("Built in progress", { exact: true })).toBeVisible();
  await expect(page.getByText("RECORDING PREVIEW / REVIEW PENDING", { exact: true })).toBeVisible();
  await expect(page.getByText("Z / DESKTOP INPUT", { exact: true })).toBeVisible();
  await expect(page.getByText("NEW / FILE", { exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "切换为中文" })).toBeVisible();

  await page.reload();
  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await expect(page.getByText("Better desktop experiences, grown for the Mac.")).toBeVisible();
});

test("浏览器英文语言在首次访问时得到英文完整内容", async ({ browser }) => {
  const context = await browser.newContext({ locale: "en-US" });
  await context.route(githubReleasesApiUrl, (route) => route.fulfill({ status: 200, contentType: "application/json", body: "[]" }));
  const page = await context.newPage();
  await page.goto("/");

  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await expect(page.getByText("Better desktop experiences, grown for the Mac.")).toBeVisible();
  await expect(page.getByRole("link", { name: "Explore the project on GitHub" })).toBeVisible();
  await context.close();
});

test("匹配的公开 Release 显示准确版本、日期和 ZIP 下载", async ({ page }) => {
  await mockReleases(page, { body: [publicRelease] });
  await page.goto("/");

  const acquire = page.locator("#acquire");
  await expect(acquire.getByRole("status")).toContainText("v0.2.0");
  await expect(acquire.getByRole("status")).toContainText("2026年8月14日");
  await expect(acquire.getByRole("link", { name: "下载 v0.2.0 的公开测试版" })).toHaveAttribute("href", publicRelease.assets[0].browser_download_url);
  await expect(acquire.getByRole("link", { name: "在 GitHub 查看 v0.2.0 发行详情" })).toHaveAttribute("href", publicRelease.html_url);
  await expect(acquire.getByRole("link", { name: "在 GitHub 查看 zongMacTools 源码" })).toHaveAttribute("href", githubRepositoryUrl);
  await expect(acquire.getByRole("link", { name: "下载 v0.2.0 的公开测试版" })).toHaveAttribute("rel", "noopener noreferrer");

  await page.getByRole("button", { name: "切换为英文" }).click();
  await expect(acquire.getByRole("link", { name: "Download the v0.2.0 public beta" })).toHaveAttribute("href", publicRelease.assets[0].browser_download_url);
});

for (const [name, releaseResponse] of [
  ["没有公开资产", []],
  ["只有 Draft Release", [{ ...publicRelease, draft: true }]],
  ["缺失匹配 ZIP 资产", [{ ...publicRelease, assets: [] }]]
]) {
  test(`${name}时获取区诚实引导至 GitHub`, async ({ page }) => {
    await mockReleases(page, { body: releaseResponse });
    await page.goto("/");

    const acquire = page.locator("#acquire");
    await expect(acquire.getByText("暂无可验证的公开下载资产", { exact: false })).toBeVisible();
    await expect(acquire.getByRole("link", { name: /下载公开测试版/ })).toHaveCount(0);
    await expect(acquire.getByRole("link", { name: "在 GitHub 查看 zongMacTools 发行详情" })).toHaveAttribute("href", githubReleasesUrl);
  });
}

for (const [name, options] of [
  ["畸形 Release 数据", { body: [{ draft: false, assets: [] }] }],
  ["畸形发布日期", { body: [{ ...publicRelease, published_at: "2026-02-30T12:00:00Z" }] }],
  ["不匹配的发行详情路径", { body: [{ ...publicRelease, html_url: `${githubReleasesUrl}/tag/v0.1.0` }] }],
  ["不匹配的资产路径", { body: [{ ...publicRelease, assets: [{ name: "zongMacTools-0.2.0.zip", browser_download_url: "https://example.com/file.zip" }] }] }],
  ["限流", { status: 429, body: { message: "rate limited" } }]
]) {
  test(`${name}时获取区不猜测版本或下载`, async ({ page }) => {
    await mockReleases(page, options);
    await page.goto("/");

    const acquire = page.locator("#acquire");
    await expect(acquire.getByText("暂时无法确认版本或下载资产", { exact: false })).toBeVisible();
    await expect(acquire.getByRole("link", { name: /下载公开测试版/ })).toHaveCount(0);
    await expect(acquire.getByRole("link", { name: "在 GitHub 查看 zongMacTools 发行详情" })).toHaveAttribute("href", githubReleasesUrl);
    await expect(acquire.getByText("v0.2.0", { exact: false })).toHaveCount(0);
  });
}

test("网络失败时获取区降级至 GitHub", async ({ page }) => {
  await page.unroute(githubReleasesApiUrl);
  await page.route(githubReleasesApiUrl, (route) => route.abort("failed"));
  await page.goto("/");

  const acquire = page.locator("#acquire");
  await expect(acquire.getByText("暂时无法确认版本或下载资产", { exact: false })).toBeVisible();
  await expect(acquire.getByRole("link", { name: /下载公开测试版/ })).toHaveCount(0);
});

test("键盘用户可跳过导航，减少动态效果时全部叙事保持直接可读", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");

  const skipLink = page.getByRole("link", { name: "跳至主要内容" });
  await skipLink.press("Enter");
  await expect(page.locator("main")).toBeFocused();
  await expect(page.getByText("交互原理演示", { exact: true })).toBeVisible();
  await expect(page.getByText("Dock 录屏素材预览", { exact: true })).toBeVisible();
  await expect(page.getByText("正在构建", { exact: true })).toBeVisible();
});

test("媒体区提供本地录屏预览、关键帧，并在窄屏和减少动态效果下展示海报", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/");

  const media = page.locator("#media");
  const video = media.locator("video");
  await expect(video).toBeVisible();
  await expect(video).toHaveAttribute("poster", "assets/dock-window-quick-look-poster.jpg");
  await expect(video.locator("source")).toHaveAttribute("src", "assets/dock-window-quick-look.mp4");
  await expect(video).toHaveJSProperty("muted", true);
  await expect(media.getByText("这是从你提供的录屏截取的本地素材预览，用于确认页面布局；正式发布前需在干净测试环境重新审核。", { exact: true })).toBeVisible();
  await expect(media.locator(".media-evidence figcaption")).toContainText("公开发布前需复核素材");
  await expect(media.getByText("素材预览 / 待审核", { exact: true })).toBeVisible();
  await expect(media.locator(".media-still")).toHaveCount(3);
  await expect(media.locator(".media-still img")).toHaveCount(3);
  await expect.poll(() => media.locator(".media-still img").evaluateAll((images) =>
    images.every((image) => image.complete && image.naturalWidth === 2704 && image.naturalHeight === 1434)
  )).toBe(true);
  await expect.poll(() => media.locator(".media-evidence").evaluate((element) => {
    const { width, height } = element.getBoundingClientRect();
    return Math.abs(width / height - 2704 / 1434) < 0.01;
  })).toBe(true);

  await page.setViewportSize({ width: 390, height: 844 });
  await expect(video).toBeHidden();
  const poster = media.locator(".media-poster");
  await expect(poster).toBeVisible();
  await media.scrollIntoViewIfNeeded();
  await expect.poll(() => poster.evaluate((image) => image.complete && image.naturalWidth === 2704 && image.naturalHeight === 1434)).toBe(true);

  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.setViewportSize({ width: 1440, height: 900 });
  await expect(video).toBeHidden();
  await expect(poster).toBeVisible();
});

test("Dock Window Quick Look 模型以四个具名阶段说明当前交互", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/");

  const model = page.getByRole("group", { name: /交互原理演示/ });
  const stageStatus = model.getByRole("status");
  await model.scrollIntoViewIfNeeded();
  await model.getByRole("button", { name: "停在 Dock", exact: true }).click();
  await expect(stageStatus).toContainText("停在 Dock");
  await expect(stageStatus).toContainText("停在正在运行的 Dock 应用图标上。");
  await expect(model.getByRole("button", { name: "停在 Dock", exact: true })).toHaveAttribute("aria-pressed", "true");

  await model.getByRole("button", { name: "查看当前可枚举窗口" }).hover();
  await expect(stageStatus).toContainText("查看窗口");
  await expect(stageStatus).toContainText("预览展示当前可枚举窗口，不是实时视频。");

  await model.getByRole("button", { name: "选择抽象窗口卡片并切换窗口" }).first().click();
  await expect(stageStatus).toContainText("切换窗口");
  await expect(model.getByRole("button", { name: "切换窗口", exact: true })).toHaveAttribute("aria-pressed", "true");

  await model.getByRole("button", { name: "选择抽象窗口卡片并切换窗口" }).first().click({ button: "right" });
  await expect(stageStatus).toContainText("窗口操作");
  await expect(stageStatus).toContainText("展示当前可用窗口操作的位置。");
});

test("桌面滚动和键盘步骤控制器都能推进 Dock 案例", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/");

  const model = page.getByRole("group", { name: /交互原理演示/ });
  await model.scrollIntoViewIfNeeded();
  await page.evaluate(() => window.scrollBy(0, -520));
  const scrollBefore = await page.evaluate(() => window.scrollY);
  await page.evaluate(() => window.scrollBy(0, 520));
  await expect.poll(() => page.evaluate((previous) => window.scrollY > previous, scrollBefore)).toBe(true);
  await expect(model.getByRole("status")).toContainText("窗口操作");

  const dockStep = model.getByRole("button", { name: "停在 Dock", exact: true });
  await dockStep.focus();
  await dockStep.press("Enter");
  await expect(model.getByRole("status")).toContainText("停在 Dock");
  await expect(dockStep).toHaveAttribute("aria-pressed", "true");

  for (const [stage, description] of [
    ["查看窗口", "预览展示当前可枚举窗口，不是实时视频。"],
    ["切换窗口", "选择抽象窗口卡片后，注意力回到目标窗口。"],
    ["窗口操作", "展示当前可用窗口操作的位置。"]
  ]) {
    const step = model.getByRole("button", { name: stage, exact: true });
    await step.press("Space");
    await expect(model.getByRole("status")).toContainText(description);
    await expect(step).toHaveAttribute("aria-pressed", "true");
  }
});

test("触控和减少动态效果用户可用文字步骤控制器操作同一模型", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");

  const model = page.getByRole("group", { name: /交互原理演示/ });
  await expect(model.getByRole("button", { name: "查看当前可枚举窗口" })).toHaveCount(0);

  for (const [stage, description] of [
    ["停在 Dock", "停在正在运行的 Dock 应用图标上。"],
    ["查看窗口", "预览展示当前可枚举窗口，不是实时视频。"],
    ["切换窗口", "选择抽象窗口卡片后，注意力回到目标窗口。"],
    ["窗口操作", "展示当前可用窗口操作的位置。"]
  ]) {
    const step = model.getByRole("button", { name: stage, exact: true });
    await step.click();
    await expect(model.getByRole("status")).toContainText(description);
    await expect(step).toHaveAttribute("aria-pressed", "true");
  }
});

test("关键链接与行动控件具备触控尺寸和可见焦点", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");

  const undersizedTargets = await page.locator("a[href], button").evaluateAll((elements) =>
    elements
      .map((element) => {
        const rect = element.getBoundingClientRect();
        return { label: element.textContent?.trim(), width: rect.width, height: rect.height };
      })
      .filter((target) => target.width > 0 && target.height > 0)
      .filter((target) => target.width < 44 || target.height < 44)
  );

  expect(undersizedTargets).toEqual([]);
  const languageSwitch = page.getByRole("button", { name: "切换为英文" });
  await languageSwitch.press("Enter");
  await expect(page.getByText("Better desktop experiences, grown for the Mac.")).toBeVisible();
});

test("探索方向不展示下载、发布日期、等待名单或已完成能力", async ({ page }) => {
  await page.goto("/");

  const exploration = page.locator("#exploration");
  await expect(exploration.getByText("正在构建", { exact: true })).toBeVisible();
  await expect(exploration.getByRole("link", { name: "在 GitHub 探索项目" })).toHaveAttribute("target", "_blank");
  await expect(exploration.getByRole("link", { name: /下载|获取|安装/ })).toHaveCount(0);
  await expect(exploration.getByText(/发布日期|等待名单|即将发布/)).toHaveCount(0);
});

test("站点不提供主题控制器，也不加载追踪或第三方资源", async ({ page }) => {
  const requests = [];
  page.on("request", (request) => requests.push(request.url()));
  await page.goto("/");

  await expect(page.getByRole("button", { name: /深色|浅色|系统|外观/ })).toHaveCount(0);
  await expect(page.locator("link[rel=canonical]")).toHaveCount(0);

  const robots = await page.request.get("/robots.txt");
  const sitemap = await page.request.get("/sitemap.xml");
  expect(await robots.text()).toContain("Allow: /");
  expect(await robots.text()).not.toContain("pages.dev");
  expect(await sitemap.text()).not.toContain("pages.dev");
  expect(requests.filter((url) => !url.startsWith("http://127.0.0.1:4173") && url !== githubReleasesApiUrl)).toEqual([]);
});

for (const width of [1440, 1024, 390]) {
  test(`站点在 ${width}px 视口不产生横向溢出、文字裁切或控件重叠`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    await page.goto("/");

    await expect
      .poll(() => page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth))
      .toBe(true);

    const overflow = await page.locator("h1, h2, h3, p, a, button").evaluateAll((elements) =>
      elements
        .map((element) => {
          const rect = element.getBoundingClientRect();
          const style = window.getComputedStyle(element);
          return {
            label: element.textContent?.trim(),
            clipped: style.overflow === "hidden" && element.scrollWidth > element.clientWidth,
            outside: rect.left < -1 || rect.right > window.innerWidth + 1
          };
        })
        .filter((result) => result.clipped || result.outside)
    );

    expect(overflow).toEqual([]);
  });
}
