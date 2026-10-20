import { defineConfig, devices } from '@playwright/test'

const baseURL = process.env.SMOKE_BASE_URL || 'https://www.ninelens.com'

if (!baseURL.startsWith('https://')) {
  throw new Error('Production smoke tests require an HTTPS SMOKE_BASE_URL.')
}

export default defineConfig({
  testDir: './e2e-smoke',
  timeout: 30_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  forbidOnly: true,
  retries: 1,
  reporter: process.env.CI ? 'github' : 'list',
  use: {
    ...devices['Desktop Chrome'],
    baseURL,
    testIdAttribute: 'data-test',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    serviceWorkers: 'block',
  },
})
