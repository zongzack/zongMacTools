import { expect, test } from "@playwright/test";

const releasesEndpoint = "https://api.github.com/repos/zongzack/zongMacTools/releases?per_page=10";

async function showNoPublicRelease(page) {
  await page.route(releasesEndpoint, (route) =>
    route.fulfill({ contentType: "application/json", body: "[]" })
  );
}

async function showPublicRelease(page) {
  await page.route(releasesEndpoint, (route) =>
    route.fulfill({
      contentType: "application/json",
      body: JSON.stringify([
        {
          draft: false,
          tag_name: "v0.2.0",
          published_at: "2026-08-13T00:00:00Z",
          assets: [
            {
              name: "zongMacTools-0.2.0-4.zip",
              browser_download_url: "https://github.com/zongzack/zongMacTools/releases/download/v0.2.0/zongMacTools-0.2.0-4.zip"
            }
          ]
        }
      ])
    })
  );
}

test("访客能浏览静态产品体验并切换外观", async ({ page }) => {
  await showNoPublicRelease(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");

  await expect(page.getByRole("heading", { level: 1, name: "zongMacTools" })).toBeVisible();
  await expect(page.getByText("Dock Window Quick Look", { exact: true }).first()).toBeVisible();
  await expect(page.getByRole("link", { name: "GitHub 源码" }).first()).toBeVisible();
  await expect(page.getByText("公开测试版即将发布")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Dock 悬停预览" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "预览卡片激活" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "右键窗口操作" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "设置" })).toBeVisible();
  await expect(page.locator('img[src="assets/zong-mac-tools-logo.png"]').first()).toBeVisible();

  const darkAppearance = page.getByRole("button", { name: "深色外观" });
  await darkAppearance.click();
  await expect(darkAppearance).toHaveAttribute("aria-pressed", "true");

  await expect
    .poll(() => page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth))
    .toBe(true);
});

test("键盘用户可跳过导航并在减少动态效果下直接取得内容", async ({ page }) => {
  await showNoPublicRelease(page);
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");

  await page.keyboard.press("Tab");
  await expect(page.getByRole("link", { name: "跳至主要内容" })).toBeFocused();
  await page.keyboard.press("Enter");
  const mainContent = page.locator("main");
  await expect(mainContent).toBeFocused();
  await expect(mainContent).toHaveCSS("outline-style", "solid");
  await expect(page.getByRole("heading", { level: 1, name: "zongMacTools" })).toBeVisible();
});

test("跟随系统时采用系统深色外观", async ({ page }) => {
  await showNoPublicRelease(page);
  await page.emulateMedia({ colorScheme: "dark" });
  await page.goto("/");

  await expect(page.locator("html")).not.toHaveAttribute("data-theme");
  await expect(page.locator("body")).toHaveCSS("background-color", "rgb(17, 23, 24)");
  await expect(page.getByRole("button", { name: "跟随系统" })).toHaveAttribute("aria-pressed", "true");
});

test("外观切换按钮满足触控高度", async ({ page }) => {
  await showNoPublicRelease(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");

  const buttonHeights = await page.locator(".appearance-control button").evaluateAll((buttons) =>
    buttons.map((button) => button.getBoundingClientRect().height)
  );

  expect(buttonHeights).toHaveLength(3);
  expect(buttonHeights.every((height) => height >= 44)).toBe(true);
});

test("页面中的可见操作目标满足触控尺寸", async ({ page }) => {
  await showNoPublicRelease(page);
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
});

test("产品效果展位在窄屏保持固定比例", async ({ page }) => {
  await showNoPublicRelease(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");

  const aspectRatios = await page.locator(".effect-slot").evaluateAll((slots) =>
    slots.map((slot) => {
      const rect = slot.getBoundingClientRect();
      return rect.width / rect.height;
    })
  );

  expect(aspectRatios).toHaveLength(4);
  expect(aspectRatios.every((ratio) => Math.abs(ratio - 16 / 9) < 0.01)).toBe(true);
});

test("公开测试版只在发布 ZIP 存在时打开安装引导并进入精确下载地址", async ({ page }) => {
  await showPublicRelease(page);
  await page.goto("/");

  await expect(page.getByText("v0.2.0 已发布于 2026年8月13日")).toBeVisible();
  await page.getByRole("link", { name: "下载公开测试版" }).click();

  const installationGuide = page.getByRole("dialog", { name: "安装 zongMacTools" });
  await expect(installationGuide).toBeVisible();
  await expect(page.getByRole("button", { name: "继续下载" })).toBeFocused();

  const downloadNavigation = page.waitForEvent("framenavigated");
  await page.getByRole("button", { name: "继续下载" }).click();
  await downloadNavigation;
  await expect(page).toHaveURL(/zongMacTools-0\.2\.0-4\.zip$/);
});

test("安装引导可由 Escape 关闭并将焦点返回到获取动作", async ({ page }) => {
  await showPublicRelease(page);
  await page.goto("/");

  const acquireAction = page.getByRole("link", { name: "下载公开测试版" });
  await acquireAction.click();
  await expect(page.getByRole("dialog", { name: "安装 zongMacTools" })).toBeVisible();

  await page.keyboard.press("Escape");
  await expect(page.getByRole("dialog", { name: "安装 zongMacTools" })).not.toBeVisible();
  await expect(acquireAction).toBeFocused();
});

test("Draft、缺失资产与请求失败都不会显示下载动作", async ({ page }) => {
  await page.route(releasesEndpoint, (route) =>
    route.fulfill({
      contentType: "application/json",
      body: JSON.stringify([
        { draft: true, tag_name: "v0.1.0", published_at: "2026-07-14T00:00:00Z", assets: [] },
        { draft: false, tag_name: "v0.2.0", published_at: "2026-08-13T00:00:00Z", assets: [] }
      ])
    })
  );
  await page.goto("/");
  await expect(page.getByText("公开测试版即将发布")).toBeVisible();
  await expect(page.getByRole("link", { name: "下载公开测试版" })).toHaveCount(0);

  await page.unroute(releasesEndpoint);
  await page.route(releasesEndpoint, (route) => route.fulfill({ status: 429, body: "rate limited" }));
  await page.reload();
  await expect(page.getByText("暂时无法获取版本信息，可在 GitHub 查看最新状态")).toBeVisible();
  await expect(page.getByRole("link", { name: "在 GitHub 查看版本" })).toBeVisible();
});

test("畸形发布数据不会伪造公开测试版", async ({ page }) => {
  await page.route(releasesEndpoint, (route) =>
    route.fulfill({
      contentType: "application/json",
      body: JSON.stringify([
        {
          draft: false,
          tag_name: "v9.9.9",
          published_at: "not-a-date",
          assets: [{ name: "zongMacTools-9.9.9-1.zip", browser_download_url: "javascript:alert('bad')" }]
        }
      ])
    })
  );
  await page.goto("/");
  await expect(page.getByText("暂时无法获取版本信息，可在 GitHub 查看最新状态")).toBeVisible();
  await expect(page.getByRole("link", { name: "下载公开测试版" })).toHaveCount(0);
  await expect(page.getByRole("link", { name: "在 GitHub 查看版本" })).toBeVisible();
});

test("标签或资产路径不匹配的发布数据不会提供下载", async ({ page }) => {
  await page.route(releasesEndpoint, (route) =>
    route.fulfill({
      contentType: "application/json",
      body: JSON.stringify([
        {
          draft: false,
          tag_name: "v0.2.0",
          published_at: "2026-08-13T00:00:00Z",
          assets: [
            {
              name: "zongMacTools-0.2.0-4.zip",
              browser_download_url:
                "https://github.com/zongzack/zongMacTools/releases/download/v9.9.9/zongMacTools-9.9.9-1.zip"
            }
          ]
        }
      ])
    })
  );
  await page.goto("/");

  await expect(page.getByText("暂时无法获取版本信息，可在 GitHub 查看最新状态")).toBeVisible();
  await expect(page.getByRole("link", { name: "下载公开测试版" })).toHaveCount(0);
  await expect(page.getByRole("link", { name: "在 GitHub 查看版本" })).toBeVisible();
});

test("站点交付中文检索基础信息，且不请求追踪资源", async ({ page }) => {
  await showNoPublicRelease(page);
  const requests = [];
  page.on("request", (request) => requests.push(request.url()));
  await page.goto("/");

  await expect(page).toHaveTitle("zongMacTools | macOS 日常效率工具");
  await expect(page.locator('html[lang="zh-Hans"]')).toHaveCount(1);
  await expect(page.locator('meta[name="description"]')).toHaveAttribute("content", /Dock Window Quick Look/);
  await expect(page.locator('meta[property="og:title"]')).toHaveAttribute("content", /zongMacTools/);
  await expect(page.locator("link[rel=canonical]")).toHaveCount(0);

  const robots = await page.request.get("/robots.txt");
  const sitemap = await page.request.get("/sitemap.xml");
  expect(await robots.text()).toContain("Allow: /");
  expect(await robots.text()).not.toContain("pages.dev");
  expect(await sitemap.text()).not.toContain("pages.dev");
  expect(requests.filter((url) => !url.startsWith("http://127.0.0.1:4173") && !url.startsWith(releasesEndpoint))).toEqual([]);
});

for (const width of [1440, 1024, 390]) {
  test(`站点在 ${width}px 视口不产生横向溢出`, async ({ page }) => {
    await showNoPublicRelease(page);
    await page.setViewportSize({ width, height: 900 });
    await page.goto("/");
    await expect
      .poll(() => page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth))
      .toBe(true);
  });
}
