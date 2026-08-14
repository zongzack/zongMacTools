import { expect, test } from "@playwright/test";

test.use({ locale: "zh-CN" });

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
    "真实运行画面",
    "Finder 右键新建文件",
    "获取公开测试版"
  ]);

  await expect(page.getByText("体验迁移工具", { exact: true })).toBeVisible();
  await expect(page.getByText("macOS 增益工具", { exact: true })).toBeVisible();
  await expect(page.locator(".status-cyan")).toHaveText("首个已实现工具");
  await expect(page.getByText("正在构建", { exact: true })).toBeVisible();
  await expect(page.getByText("真实演示素材尚待干净测试环境采集与人工审核。", { exact: true })).toBeVisible();
  await expect(page.getByText("本地素材 / 待审核", { exact: true })).toBeVisible();
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
  await expect(page.getByText("LOCAL MEDIA / PENDING REVIEW", { exact: true })).toBeVisible();
  await expect(page.getByText("Z / DESKTOP INPUT", { exact: true })).toBeVisible();
  await expect(page.getByText("NEW / FILE", { exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "切换为中文" })).toBeVisible();

  await page.reload();
  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await expect(page.getByText("Better desktop experiences, grown for the Mac.")).toBeVisible();
});

test("浏览器英文语言在首次访问时得到英文完整内容", async ({ browser }) => {
  const context = await browser.newContext({ locale: "en-US" });
  const page = await context.newPage();
  await page.goto("/");

  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await expect(page.getByText("Better desktop experiences, grown for the Mac.")).toBeVisible();
  await expect(page.getByRole("link", { name: "Explore the project on GitHub" })).toBeVisible();
  await context.close();
});

test("键盘用户可跳过导航，减少动态效果时全部叙事保持直接可读", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");

  const skipLink = page.getByRole("link", { name: "跳至主要内容" });
  await skipLink.press("Enter");
  await expect(page.locator("main")).toBeFocused();
  await expect(page.getByText("交互原理演示", { exact: true })).toBeVisible();
  await expect(page.getByText("真实运行画面", { exact: true }).first()).toBeVisible();
  await expect(page.getByText("正在构建", { exact: true })).toBeVisible();
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
  const scrollBefore = await page.evaluate(() => window.scrollY);
  await page.mouse.wheel(0, 520);
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
  expect(requests.filter((url) => !url.startsWith("http://127.0.0.1:4173"))).toEqual([]);
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
