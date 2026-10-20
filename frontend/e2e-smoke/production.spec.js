import { expect, test } from '@playwright/test'

const publicPages = [
  { path: '/', heading: /baseball intelligence/i },
  { path: '/schedule', heading: 'Games around the league' },
  { path: '/standings', heading: 'MLB standings' },
  { path: '/postseason' },
  { path: '/explore', heading: 'Stat Explorer' },
  { path: '/stat-board', heading: 'Stat Explorer' },
  { path: '/compare', heading: 'Side-by-side comparison' },
  { path: '/teams', heading: 'MLB teams' },
  { path: '/login', heading: 'Sign in to NineLens' },
  { path: '/players/545361' },
  { path: '/teams/108' },
  { path: '/games/775347' },
  { path: '/saved/1' },
]

test.beforeEach(async ({ page }) => {
  // Keep smoke-test browser traffic out of Umami, including pageviews and events.
  await page.route('https://cloud.umami.is/**', (route) => route.abort())
})

test('production readiness endpoint is healthy', async ({ request, baseURL }) => {
  const response = await request.get(new URL('/up', baseURL).toString())

  expect(response.ok()).toBeTruthy()
  expect(response.headers()['content-type']).toContain('application/json')
  await expect(response.json()).resolves.toMatchObject({
    status: 'ok',
    checks: { application: 'ok', database: 'ok' },
  })
})

for (const { path, heading } of publicPages) {
  test(`public page ${path} loads`, async ({ page }) => {
    const response = await page.goto(path)
    expect(response?.ok(), `${path} should return a successful document response`).toBeTruthy()
    await expect(page.locator('#app main')).toBeVisible()

    if (heading) await expect(page.getByRole('heading', { name: heading })).toBeVisible()
    if (path === '/postseason') {
      await expect(page.locator('.postseason-state--error')).toHaveCount(0)
      await expect(page.getByText('Loading postseason…')).toHaveCount(0)
      const bracketHeading = page.locator('.postseason-hero h1')
      if (await bracketHeading.count()) {
        await expect(bracketHeading).toBeVisible()
      } else {
        await expect(page.getByText('The postseason page will appear when the current season reaches the playoffs.')).toBeVisible()
      }
    }
    if (path === '/') {
      await expect(page.getByRole('heading', { name: 'Games around the league' })).toBeVisible()
      await expect(page.getByTestId('home-leaders')).toBeVisible()
      await expect(page.getByTestId('home-error')).toHaveCount(0)
    }
  })
}
