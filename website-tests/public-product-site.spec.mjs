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
  await page.route(githubReleasesApiUrl, (route) =>
    route.fulfill({ status, contentType: "application/json", body: JSON.stringify(body) })
  );
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
  await expect(page.getByRole("link", { name: "接着查看真实运行画面" })).toBeVisible();

  const sectionTitles = await page.getByRole("heading", { level: 2 }).allTextContents();
  expect(sectionTitles).toEqual([
    "为什么是 zongMacTools",
    "Dock Window Quick Look（Dock 窗口速览）",
    "Dock 窗口速览运行录屏",
    "Finder 右键新建文件",
    "获取公开测试版"
  ]);

  await expect(page.getByText("体验迁移工具", { exact: true })).toBeVisible();
  await expect(page.getByText("macOS 增益工具", { exact: true })).toBeVisible();
  await expect(page.locator(".status-implemented")).toHaveText("首个已实现工具");
  await expect(page.locator(".status-building")).toHaveText("正在构建");
  await expect(page.locator(".status-review")).toHaveText("素材预览 / 待审核");
  await expect(page.getByText("交互原理演示 · 抽象模型，不是产品界面截图", { exact: true })).toBeVisible();
});

test("顶栏仅提供品牌、工具、语言和 GitHub 源码入口", async ({ page }) => {
  await page.goto("/");

  const navigation = page.getByRole("navigation", { name: "主导航" });
  await expect(navigation.getByRole("link", { name: "zongMacTools 首页" })).toBeVisible();
  await expect(navigation.getByRole("link", { name: "工具案例" })).toBeVisible();
  await expect(navigation.getByRole("button", { name: "Switch to English" })).toBeVisible();
  await expect(navigation.getByRole("link", { name: /在 GitHub 查看 zongMacTools 源码/ })).toHaveAttribute("target", "_blank");
  await expect(navigation.getByRole("link", { name: /在 GitHub 查看 zongMacTools 源码/ })).toHaveAttribute("rel", "noopener noreferrer");
  await expect(navigation.getByRole("link", { name: /下载|获取|安装/ })).toHaveCount(0);
  await expect(navigation.locator("[data-theme]")).toHaveCount(0);
});

test("中文和英文在整个公开站中同步切换并保留本地选择", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: "Switch to English" }).click();

  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await expect(page).toHaveTitle("zongMacTools | Better desktop experiences, grown for the Mac");
  await expect(page.getByText("Better desktop experiences, grown for the Mac.")).toBeVisible();
  await expect(page.getByRole("link", { name: "See the first tool" })).toBeVisible();
  await expect(page.getByText("Under construction", { exact: true })).toBeVisible();
  await expect(page.getByText("FOOTAGE PREVIEW / REVIEW PENDING", { exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "Pause on the Dock", exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "切换为中文" })).toBeVisible();

  await page.reload();
  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await expect(page.getByText("Better desktop experiences, grown for the Mac.")).toBeVisible();
});

test("浏览器英文语言在首次访问时得到英文完整内容", async ({ browser }) => {
  const context = await browser.newContext({ locale: "en-US" });
  await context.route(githubReleasesApiUrl, (route) =>
    route.fulfill({ status: 200, contentType: "application/json", body: "[]" })
  );
  const page = await context.newPage();
  await page.goto("/");

  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await expect(page.getByText("Better desktop experiences, grown for the Mac.")).toBeVisible();
  await expect(page.getByRole("link", { name: /Explore the zongMacTools project on GitHub/ })).toBeVisible();
  await context.close();
});

test("匹配的公开 Release 显示准确版本、日期和 ZIP 下载", async ({ page }) => {
  await mockReleases(page, { body: [publicRelease] });
  await page.goto("/");

  const acquire = page.locator("#acquire");
  await expect(acquire.getByRole("status")).toContainText("v0.2.0");
  await expect(acquire.getByRole("status")).toContainText("2026年8月14日");
  await expect(acquire.getByRole("link", { name: "下载 v0.2.0 公开测试版（ZIP）" })).toHaveAttribute(
    "href",
    publicRelease.assets[0].browser_download_url
  );
  await expect(acquire.getByRole("link", { name: "下载 v0.2.0 公开测试版（ZIP）" })).toHaveAttribute("rel", "noopener noreferrer");
  await expect(acquire.getByRole("link", { name: /在 GitHub 查看 v0.2.0 发行详情/ })).toHaveAttribute("href", publicRelease.html_url);
  await expect(acquire.getByRole("link", { name: /在 GitHub 查看 zongMacTools 源码/ })).toHaveAttribute("href", githubRepositoryUrl);

  await expect(acquire.getByText("macOS 14 或更高版本", { exact: true })).toBeVisible();
  await expect(acquire.getByText("辅助功能与屏幕录制", { exact: true })).toBeVisible();
  await expect(acquire.getByText("未公证公开测试版", { exact: true })).toBeVisible();

  await page.getByRole("button", { name: "Switch to English" }).click();
  await expect(acquire.getByRole("link", { name: "Download the v0.2.0 public beta (ZIP)" })).toHaveAttribute(
    "href",
    publicRelease.assets[0].browser_download_url
  );
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
    await expect(acquire.getByRole("link", { name: /下载.*公开测试版/ })).toHaveCount(0);
    await expect(acquire.getByRole("link", { name: /在 GitHub 查看 zongMacTools 发行详情/ })).toHaveAttribute("href", githubReleasesUrl);
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
    await expect(acquire.getByRole("link", { name: /下载.*公开测试版/ })).toHaveCount(0);
    await expect(acquire.getByRole("link", { name: /在 GitHub 查看 zongMacTools 发行详情/ })).toHaveAttribute("href", githubReleasesUrl);
    await expect(acquire.getByText("v0.2.0", { exact: false })).toHaveCount(0);
  });
}

test("网络失败时获取区降级至 GitHub", async ({ page }) => {
  await page.unroute(githubReleasesApiUrl);
  await page.route(githubReleasesApiUrl, (route) => route.abort("failed"));
  await page.goto("/");

  const acquire = page.locator("#acquire");
  await expect(acquire.getByText("暂时无法确认版本或下载资产", { exact: false })).toBeVisible();
  await expect(acquire.getByRole("link", { name: /下载.*公开测试版/ })).toHaveCount(0);
});

test("键盘用户可跳过导航，减少动态效果时全部叙事保持直接可读", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");

  const skipLink = page.getByRole("link", { name: "跳至主要内容" });
  await skipLink.press("Enter");
  await expect(page.locator("main")).toBeFocused();
  await expect(page.getByText("交互原理演示 · 抽象模型，不是产品界面截图", { exact: true })).toBeVisible();
  await expect(page.getByText("素材预览 / 待审核", { exact: true })).toBeVisible();
  await expect(page.getByText("正在构建", { exact: true })).toBeVisible();
  await expect(page.getByRole("link", { name: /在 GitHub 查看 zongMacTools 发行详情/ })).toBeVisible();
});

test("媒体区提供本地录屏预览与关键帧，全部保持原始宽高比", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/");

  const media = page.locator("#media");
  const video = media.locator("video");
  await expect(video).toBeVisible();
  await expect(video).toHaveAttribute("poster", "assets/quick-look-poster.jpg");
  await expect(video.locator("source")).toHaveAttribute("src", "assets/quick-look-recording.mp4");
  await expect(video).toHaveJSProperty("muted", true);
  await expect(media.getByText("素材预览 / 待审核", { exact: true })).toBeVisible();
  await expect(media.locator(".media-frame figcaption")).toContainText("待审核");

  await expect(media.locator(".media-still img")).toHaveCount(3);
  await media.scrollIntoViewIfNeeded();
  await expect
    .poll(() =>
      media
        .locator(".media-still img")
        .evaluateAll((images) => images.every((image) => image.complete && image.naturalWidth === 2704 && image.naturalHeight === 1434))
    )
    .toBe(true);

  // 视频容器保持 2704:1434 原始比例，不裁切画面。
  await expect
    .poll(() =>
      video.evaluate((element) => {
        const { width, height } = element.getBoundingClientRect();
        return width > 0 && Math.abs(width / height - 2704 / 1434) < 0.01;
      })
    )
    .toBe(true);
});

test("窄屏与减少动态效果下媒体降级为海报图", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");

  const media = page.locator("#media");
  const video = media.locator("video");
  const poster = media.locator(".media-poster");
  await expect(video).toBeHidden();
  await media.scrollIntoViewIfNeeded();
  await expect(poster).toBeVisible();
  await expect
    .poll(() => poster.evaluate((image) => image.complete && image.naturalWidth === 2704 && image.naturalHeight === 1434))
    .toBe(true);

  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.setViewportSize({ width: 1440, height: 900 });
  await expect(video).toBeHidden();
  await expect(poster).toBeVisible();
});

test("Dock Window Quick Look 演示以四个具名阶段说明当前交互", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/");

  const demo = page.getByRole("group", { name: /交互原理演示/ });
  const status = demo.locator(".demo-status");
  await demo.scrollIntoViewIfNeeded();

  await demo.getByRole("button", { name: "停在 Dock", exact: true }).click();
  await expect(status).toContainText("步骤 1 / 4");
  await expect(status).toContainText("停在 Dock");
  await expect(status).toContainText("指针停在正在运行的 Dock 应用图标上。");
  await expect(demo.getByRole("button", { name: "停在 Dock", exact: true })).toHaveAttribute("aria-pressed", "true");

  // 桌面鼠标：悬停抽象 Dock 应用触发“查看窗口”。
  await demo.locator("[data-demo-hover]").hover();
  await expect(status).toContainText("查看窗口");
  await expect(status).toContainText("不是实时视频");

  // 桌面鼠标：点击抽象窗口卡片触发“切换窗口”。
  await demo.locator("[data-demo-scene-card]").first().click();
  await expect(status).toContainText("切换窗口");
  await expect(demo.getByRole("button", { name: "切换窗口", exact: true })).toHaveAttribute("aria-pressed", "true");

  // 桌面鼠标：右键抽象窗口卡片触发“窗口操作”。
  await demo.locator("[data-demo-scene-card]").first().click({ button: "right" });
  await expect(status).toContainText("窗口操作");
  await expect(status).toContainText("右键");
});

test("桌面滚动推进案例且浏览器滚轮不被劫持", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/");

  const demo = page.getByRole("group", { name: /交互原理演示/ });
  await demo.scrollIntoViewIfNeeded();
  await page.evaluate(() => window.scrollBy(0, -520));
  const scrollBefore = await page.evaluate(() => window.scrollY);
  await page.evaluate(() => window.scrollBy(0, 520));
  await expect.poll(() => page.evaluate((previous) => window.scrollY > previous, scrollBefore)).toBe(true);
  await expect(demo.locator(".demo-status")).toContainText("窗口操作");
});

test("键盘步骤控制器驱动同一四状态模型", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/");

  const demo = page.getByRole("group", { name: /交互原理演示/ });
  const dockStep = demo.getByRole("button", { name: "停在 Dock", exact: true });
  await dockStep.focus();
  await dockStep.press("Enter");
  await expect(demo.locator(".demo-status")).toContainText("指针停在正在运行的 Dock 应用图标上。");
  await expect(dockStep).toHaveAttribute("aria-pressed", "true");

  for (const [stage, description] of [
    ["查看窗口", "不是实时视频"],
    ["切换窗口", "目标窗口被激活"],
    ["窗口操作", "当前可用的窗口操作"]
  ]) {
    const step = demo.getByRole("button", { name: stage, exact: true });
    await step.press("Space");
    await expect(demo.locator(".demo-status")).toContainText(description);
    await expect(step).toHaveAttribute("aria-pressed", "true");
  }
});

test("触控窄屏与减少动态效果用户用文字步骤控制器获得等价体验", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");

  const demo = page.getByRole("group", { name: /交互原理演示/ });
  // 触控设备不模拟 hover/右键：抽象场景控件不进入可访问树。
  await expect(demo.locator("[data-demo-hover]")).toHaveAttribute("aria-hidden", "true");
  await expect(demo.locator(".demo-scene").getByRole("button")).toHaveCount(0);

  for (const [stage, description] of [
    ["停在 Dock", "指针停在正在运行的 Dock 应用图标上。"],
    ["查看窗口", "不是实时视频"],
    ["切换窗口", "目标窗口被激活"],
    ["窗口操作", "当前可用的窗口操作"]
  ]) {
    const step = demo.getByRole("button", { name: stage, exact: true });
    await step.click();
    await expect(demo.locator(".demo-status")).toContainText(description);
    await expect(step).toHaveAttribute("aria-pressed", "true");
  }
});

test("关键链接与行动控件具备触控尺寸和可见焦点", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");

  const undersizedTargets = await page.locator("a[href], button").evaluateAll((elements) =>
    elements
      .filter((element) => !element.closest("[aria-hidden='true']"))
      .map((element) => {
        const rect = element.getBoundingClientRect();
        return { label: element.textContent?.trim(), width: rect.width, height: rect.height };
      })
      .filter((target) => target.width > 0 && target.height > 0)
      .filter((target) => target.width < 44 || target.height < 44)
  );

  expect(undersizedTargets).toEqual([]);

  const toggle = page.getByRole("button", { name: "Switch to English" });
  await toggle.focus();
  await expect(toggle).toBeFocused();
  await toggle.press("Enter");
  await expect(page.getByText("Better desktop experiences, grown for the Mac.")).toBeVisible();
});

test("探索方向不展示下载、发布日期、等待名单或已完成能力", async ({ page }) => {
  await page.goto("/");

  const exploration = page.locator("#exploration");
  await expect(exploration.getByText("正在构建", { exact: true })).toBeVisible();
  await expect(exploration.getByRole("link", { name: /在 GitHub 探索 zongMacTools 项目/ })).toHaveAttribute("target", "_blank");
  await expect(exploration.getByRole("link", { name: /在 GitHub 探索 zongMacTools 项目/ })).toHaveAttribute("rel", "noopener noreferrer");
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

    await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);

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
