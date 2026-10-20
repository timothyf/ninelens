import { defineConfig, devices } from '@playwright/test'

const baseURL = process.env.E2E_BASE_URL || 'http://127.0.0.1:4173'
const useManagedServers = !process.env.E2E_BASE_URL
const rubyBinPath = '/Users/timothyfisher/.rvm/gems/ruby-3.4.11/bin:/Users/timothyfisher/.rvm/gems/ruby-3.4.11@global/bin:/Users/timothyfisher/.rvm/rubies/ruby-3.4.11/bin'
const railsEnvironment = {
  ...process.env,
  PATH: `${rubyBinPath}:${process.env.PATH}`,
  RAILS_ENV: 'test',
}

function chromiumIPhone(deviceName) {
  const { defaultBrowserType: _defaultBrowserType, ...device } = devices[deviceName]
  return { ...device, browserName: 'chromium' }
}

export default defineConfig({
  testDir: './e2e',
  globalSetup: './e2e/global-setup.js',
  globalTeardown: './e2e/global-teardown.js',
  timeout: 30_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 2 : 0,
  reporter: process.env.CI ? 'github' : 'list',
  use: {
    baseURL,
    testIdAttribute: 'data-test',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'desktop-chromium',
      testIgnore: /mobile-ux\.spec\.js/,
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'iphone-se-portrait',
      testMatch: /mobile-ux\.spec\.js/,
      use: chromiumIPhone('iPhone SE (3rd gen)'),
    },
    {
      name: 'iphone-current-portrait',
      testMatch: /mobile-ux\.spec\.js/,
      use: chromiumIPhone('iPhone 17'),
    },
    {
      name: 'iphone-current-landscape',
      testMatch: /mobile-ux\.spec\.js/,
      use: chromiumIPhone('iPhone 17 landscape'),
    },
  ],
  webServer: useManagedServers ? [
    {
      command: 'bundle exec rails server -e test -p 3001 -P tmp/pids/playwright-test-server.pid',
      cwd: '../backend',
      url: 'http://127.0.0.1:3001/up',
      timeout: 120_000,
      reuseExistingServer: false,
      env: railsEnvironment,
    },
    {
      command: 'npm run dev -- --host 127.0.0.1 --port 4173',
      url: baseURL,
      timeout: 120_000,
      reuseExistingServer: false,
      env: { VITE_DEV_API_TARGET: 'http://127.0.0.1:3001' },
    },
  ] : undefined,
})
