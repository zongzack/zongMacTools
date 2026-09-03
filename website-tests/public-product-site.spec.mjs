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
  assets: [
    {
      name: "zongMacTools-0.2.0.zip",
      browser_download_url: `${githubReleasesUrl}/download/v0.2.0/zongMacTools-0.2.0.zip`
    }
  ]
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

test("首页完整呈现当前产品叙事", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/");

  await expect(page).toHaveTitle("zongMacTools | 把 Windows 的顺手，原样搬到 Mac");
  await expect(page.locator("html")).toHaveAttribute("lang", "zh-Hans");
  await expect(page.getByRole("heading", { level: 1, name: /把 Windows 的顺手.*原样搬到 Mac/ })).toBeVisible();
  await expect(page.getByText("开源免费 · macOS 14+ · Apple Silicon 原生")).toBeVisible();

  expect(await page.getByRole("heading", { level: 2 }).allTextContents()).toEqual([
    "两大核心功能",
    "从 Windows 到 Mac，无缝过渡",
    "更多细节，同样顺手",
    "常见问题",
    "开始体验"
  ]);

  await expect(page.locator(".feature-card")).toHaveCount(2);
  await expect(page.locator(".migration-row")).toHaveCount(2);
  await expect(page.locator(".cap-card")).toHaveCount(6);
  await expect(page.locator(".faq-item")).toHaveCount(4);
});

test("顶栏提供产品导航和 GitHub 源码入口", async ({ page }) => {
  await page.goto("/");

  const navigation = page.getByRole("navigation", { name: "主导航" });
  await expect(navigation.getByRole("link", { name: "zongMacTools 首页" })).toHaveAttribute("href", "#hero");
  await expect(navigation.getByRole("link", { name: "功能" })).toHaveAttribute("href", "#features");
  await expect(navigation.getByRole("link", { name: "迁移" })).toHaveAttribute("href", "#migration");
  await expect(navigation.getByRole("link", { name: "下载" })).toHaveAttribute("href", "#download");

  const github = navigation.getByRole("link", { name: /在 GitHub 查看 zongMacTools 源码/ });
  await expect(github).toHaveAttribute("href", githubRepositoryUrl);
  await expect(github).toHaveAttribute("target", "_blank");
  await expect(github).toHaveAttribute("rel", "noopener noreferrer");
});

test("Hero 展示两项产品能力示意图", async ({ page }) => {
  await page.goto("/");

  await expect(page.locator("#hero .hero-mock")).toHaveCount(2);
  await expect(page.getByRole("img", { name: /Dock 窗口速览界面示意/ })).toBeVisible();
  await expect(page.getByRole("img", { name: /右键新建文件界面示意/ })).toBeVisible();
  await expect(page.locator(".popover-card")).toHaveCount(3);
  await expect(page.locator(".rc-submenu-item")).toHaveCount(6);
  await expect(page.locator(".rc-submenu-active")).toContainText("JSON");
});

test("页面元数据使用产品 PNG 并指向公开站点", async ({ page }) => {
  await page.goto("/");

  const logoAsset = "assets/zong-mac-tools-logo.png";
  await expect(page.locator('link[rel="icon"]')).toHaveAttribute("href", logoAsset);
  await expect(page.locator('link[rel="icon"]')).toHaveAttribute("type", "image/png");
  await expect(page.locator('link[rel="apple-touch-icon"]')).toHaveAttribute("href", logoAsset);
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute("href", "https://zongmactools.pages.dev/");
  await expect(page.locator('meta[name="description"]')).toHaveAttribute("content", /Finder 右键直接新建文件/);
});

test("匹配的公开 Release 会更新全部下载按钮", async ({ page }) => {
  await mockReleases(page, { body: [publicRelease] });
  await page.goto("/");

  const downloads = page.locator("[data-download]");
  await expect(downloads).toHaveCount(2);
  await expect(downloads.first()).toHaveAttribute("href", publicRelease.assets[0].browser_download_url);
  await expect(downloads.last()).toHaveAttribute("href", publicRelease.assets[0].browser_download_url);

  for (const download of await downloads.all()) {
    await expect(download).toHaveAttribute("aria-label", "下载 zongMacTools v0.2.0（新标签页打开）");
    await expect(download).toHaveAttribute("target", "_blank");
    await expect(download).toHaveAttribute("rel", "noopener noreferrer");
  }
});

for (const [name, options] of [
  ["没有公开资产", { body: [] }],
  ["只有 Draft Release", { body: [{ ...publicRelease, draft: true }] }],
  ["缺失匹配 ZIP 资产", { body: [{ ...publicRelease, assets: [] }] }],
  ["畸形 Release 数据", { body: [{ draft: false, assets: [] }] }],
  ["不匹配的下载地址", { body: [{ ...publicRelease, assets: [{ name: "zongMacTools-0.2.0.zip", browser_download_url: "https://example.com/file.zip" }] }] }],
  ["GitHub API 限流", { status: 429, body: { message: "rate limited" } }]
]) {
  test(`${name}时下载按钮降级到 Releases 列表`, async ({ page }) => {
    await mockReleases(page, options);
    await page.goto("/");

    const downloads = page.locator("[data-download]");
    await expect(downloads).toHaveCount(2);
    await expect(downloads.first()).toHaveAttribute("href", githubReleasesUrl);
    await expect(downloads.last()).toHaveAttribute("href", githubReleasesUrl);
    await expect(downloads.first()).not.toHaveAttribute("aria-label", /v0\.2\.0/);
  });
}

test("网络失败时下载按钮降级到 Releases 列表", async ({ page }) => {
  await page.unroute(githubReleasesApiUrl);
  await page.route(githubReleasesApiUrl, (route) => route.abort("failed"));
  await page.goto("/");

  await expect(page.locator("[data-download]").first()).toHaveAttribute("href", githubReleasesUrl);
  await expect(page.locator("[data-download]").last()).toHaveAttribute("href", githubReleasesUrl);
});

test("键盘用户可跳至主要内容并操作 FAQ", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");

  const skipLink = page.getByRole("link", { name: "跳至主要内容" });
  await skipLink.press("Enter");
  await expect(page.locator("main")).toBeFocused();

  const item = page.locator("#faq details").filter({ hasText: "需要哪些系统权限？" });
  const question = item.locator("summary");
  await expect(item).toHaveAttribute("open", "");
  await question.press("Enter");
  await expect(item).not.toHaveAttribute("open", "");
  await question.press("Enter");
  await expect(item).toHaveAttribute("open", "");
});

test("外部链接均采用安全的新标签页属性", async ({ page }) => {
  await page.goto("/");

  const unsafeLinks = await page.locator('a[href^="https://"]').evaluateAll((links) =>
    links
      .filter((link) => link.target !== "_blank" || link.rel !== "noopener noreferrer")
      .map((link) => link.getAttribute("href"))
  );
  expect(unsafeLinks).toEqual([]);
});

test("站点不加载追踪器、CDN 或第三方媒体", async ({ page }) => {
  const requests = [];
  page.on("request", (request) => requests.push(request.url()));
  await page.goto("/");

  await expect(page.locator('script[src*="analytics"], script[src*="gtag"], [data-theme]')).toHaveCount(0);
  expect(
    requests.filter(
      (url) => !url.startsWith("http://127.0.0.1:4173") && url !== githubReleasesApiUrl
    )
  ).toEqual([]);

  const robots = await page.request.get("/robots.txt");
  const sitemap = await page.request.get("/sitemap.xml");
  expect(await robots.text()).toContain("Allow: /");
  expect(await sitemap.text()).toContain("https://zongmactools.pages.dev/");
});

for (const width of [1440, 1024, 390]) {
  test(`站点在 ${width}px 视口不产生横向溢出或文字裁切`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    await page.goto("/");

    await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);

    const overflow = await page.locator("h1, h2, h3, p, a:not(.skip-link), summary").evaluateAll((elements) =>
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
    await expect(page.getByRole("img", { name: /Dock 窗口速览界面示意/ })).toBeVisible();
    await expect(page.getByRole("img", { name: /右键新建文件界面示意/ })).toBeVisible();
  });
}
