import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./website-tests",
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  reporter: "list",
  use: {
    baseURL: "http://127.0.0.1:4173",
    trace: "on-first-retry"
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] }
    }
  ],
  webServer: {
    command: "python3 -m http.server 4173 --directory website",
    url: "http://127.0.0.1:4173",
    reuseExistingServer: !process.env.CI
  }
});
