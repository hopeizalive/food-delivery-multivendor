import { defineConfig, devices } from '@playwright/test';

// Playwright E2E config for multivendor-admin, run against the mock-api
// backend (mock-api/) for demo/manual-testing, not real production.
// Coexists with the app's existing Cypress setup (cypress.config.ts) -
// this is a separate, additive test harness, not a replacement.
export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  retries: 1,
  reporter: 'list',
  use: {
    baseURL: 'http://localhost:3001',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  // Assumes `npm run dev` (admin, port 3001) and mock-api's `node server.js`
  // (port 4000) are already running - see e2e/README.md. Not started here
  // since mock-api lives in a separate repo/directory outside this app.
});
