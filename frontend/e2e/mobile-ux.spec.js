import { expect, test } from '@playwright/test'

const accounts = {
  viewer: {
    email: 'e2e.viewer@ninelens.test',
    password: 'playwright-password-123',
  },
  administrator: {
    email: 'e2e.admin@ninelens.test',
    password: 'playwright-password-123',
  },
}

async function signIn(page, account, redirect = '/') {
  await page.goto(`/login?redirect=${encodeURIComponent(redirect)}`)
  await page.getByLabel('Email').fill(account.email)
  await page.getByLabel('Password').fill(account.password)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect.poll(() => new URL(page.url()).pathname).toBe(redirect)
}

async function expectNoDocumentOverflow(page) {
  await expect.poll(() => page.evaluate(() => (
    document.documentElement.scrollWidth - document.documentElement.clientWidth
  ))).toBeLessThanOrEqual(0)
}

async function expectTextControlsAvoidIOSZoom(page, scope = page.locator('body')) {
  const undersized = await scope.locator('input:not([type="checkbox"]):not([type="radio"]):not([type="range"]), select, textarea')
    .evaluateAll((controls) => controls
      .filter((control) => {
        const rect = control.getBoundingClientRect()
        const style = getComputedStyle(control)
        return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden'
      })
      .map((control) => ({
        control: control.getAttribute('aria-label') || control.getAttribute('placeholder') || control.name || control.type,
        fontSize: Number.parseFloat(getComputedStyle(control).fontSize),
      }))
      .filter(({ fontSize }) => fontSize < 16))

  expect(undersized, 'Visible form controls must use at least 16px text to prevent iOS focus zoom').toEqual([])
}

async function expectMinimumTouchTargets(locator) {
  const undersized = await locator.evaluateAll((elements) => elements
    .filter((element) => {
      const rect = element.getBoundingClientRect()
      const style = getComputedStyle(element)
      return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden'
    })
    .map((element) => {
      const rect = element.getBoundingClientRect()
      return {
        label: (element.textContent || element.getAttribute('aria-label') || '').trim().replace(/\s+/g, ' ').slice(0, 60),
        width: Math.round(rect.width),
        height: Math.round(rect.height),
      }
    })
    .filter(({ width, height }) => width < 44 || height < 44))

  expect(undersized, 'Mobile interaction targets must be at least 44 by 44 CSS pixels').toEqual([])
}

test.describe('mobile layout foundations', () => {
  test('keeps primary routes inside the document viewport', async ({ page }) => {
    for (const path of ['/', '/schedule', '/standings', '/explore', '/compare', '/teams', '/login']) {
      await page.goto(path)
      await expectNoDocumentOverflow(page)
    }
  })

  test('keeps navigation destinations reachable with touch-sized targets', async ({ page }) => {
    const destinations = [
      ['Home', '/'],
      ['Schedule', '/schedule'],
      ['Standings', '/standings'],
      ['Stat Explorer', '/explore'],
      ['Compare', '/compare'],
      ['Teams', '/teams'],
    ]

    await page.goto('/')
    for (const [name, path] of destinations) {
      await page.getByRole('button', { name: 'Open navigation' }).click()
      const link = page.getByRole('navigation', { name: 'Primary navigation' }).getByRole('link', { name, exact: true })
      await link.scrollIntoViewIfNeeded()
      await expect(link).toBeInViewport()
      await link.click()
      await expect(page).toHaveURL(new RegExp(`${path.replaceAll('/', '\\/')}$`))
    }

    await page.getByRole('button', { name: 'Open navigation' }).click()
    await expectMinimumTouchTargets(page.locator('.app-primary-nav a'))
  })

  test('prevents iOS form zoom on login and Stat Explorer', async ({ page }) => {
    await page.goto('/login')
    await expectTextControlsAvoidIOSZoom(page, page.locator('.login-card'))

    await page.goto('/explore')
    await expectTextControlsAvoidIOSZoom(page, page.locator('.control-deck'))
  })
})

test.describe('mobile workflows', () => {
  test('signs in using touch-sized authentication controls', async ({ page }) => {
    await page.goto('/login')
    await expectMinimumTouchTargets(page.locator('.login-card input, .login-card button[type="submit"]'))
    await expectTextControlsAvoidIOSZoom(page, page.locator('.login-card'))

    await page.getByLabel('Email').fill(accounts.viewer.email)
    await page.getByLabel('Password').fill(accounts.viewer.password)
    await page.getByRole('button', { name: 'Sign in' }).click()

    await expect(page).toHaveURL(/\/$/)
    await page.getByRole('button', { name: 'Open navigation' }).click()
    await expect(page.getByRole('button', { name: /E2E Viewer/ })).toBeVisible()
  })

  test('searches for a player and keeps profile tabs clear of the app header', async ({ page }) => {
    await page.goto('/')
    await page.getByRole('button', { name: 'Search', exact: true }).click()
    const search = page.getByRole('combobox', { name: 'Find a player or team' })
    await search.fill('E2E Slugger')
    await page.locator('#player-search-results').getByRole('button').filter({ hasText: 'E2E Slugger' }).click()

    await expect(page).toHaveURL(/\/players\/\d+$/)
    await expect(page.getByRole('heading', { name: 'E2E Slugger', exact: true })).toBeVisible()
    await expectNoDocumentOverflow(page)

    const profileTabs = page.locator('.profile-tabs')
    await profileTabs.scrollIntoViewIfNeeded()
    await expect.poll(() => page.evaluate(() => {
      const header = document.querySelector('.app-bar')?.getBoundingClientRect()
      const tabs = document.querySelector('.profile-tabs')?.getBoundingClientRect()
      return !header || !tabs || tabs.top >= header.bottom
    })).toBe(true)
    await expectMinimumTouchTargets(profileTabs.getByRole('tab'))
  })

  test('completes player comparison and contains table scrolling', async ({ page }) => {
    await page.goto('/compare')
    const left = page.getByTestId('comparison-picker-player a')
    await left.getByPlaceholder('Search player a…').fill('E2E Slugger')
    await left.getByRole('button', { name: /E2E Slugger/ }).click()

    const right = page.getByTestId('comparison-picker-player b')
    await right.getByPlaceholder('Search player b…').fill('E2E Rival')
    await right.getByRole('button', { name: /E2E Rival/ }).click()

    const tablePanel = page.getByTestId('season-comparison')
    await expect(tablePanel).toBeVisible()
    await expect(tablePanel).toContainText('E2E Slugger')
    await expect(tablePanel).toContainText('E2E Rival')
    await expectNoDocumentOverflow(page)

    const scrollState = await tablePanel.evaluate((panel) => ({
      clientWidth: panel.clientWidth,
      scrollWidth: panel.scrollWidth,
    }))
    if (scrollState.scrollWidth > scrollState.clientWidth) {
      await tablePanel.evaluate((panel) => { panel.scrollLeft = panel.scrollWidth })
      await expect.poll(() => tablePanel.evaluate((panel) => panel.scrollLeft)).toBeGreaterThan(0)
    }
  })

  test('keeps Stat Explorer table scrolling inside its container', async ({ page }) => {
    await page.goto('/explore')
    const dataGrid = page.locator('.data-grid')
    await expect(dataGrid).toBeVisible()
    await expect.poll(() => dataGrid.evaluate((grid) => grid.scrollWidth > grid.clientWidth)).toBe(true)

    await dataGrid.evaluate((grid) => { grid.scrollLeft = grid.scrollWidth })
    await expect.poll(() => dataGrid.evaluate((grid) => grid.scrollLeft)).toBeGreaterThan(0)
    await expectNoDocumentOverflow(page)
  })

  test('creates a watchlist with mobile-safe controls', async ({ page }, testInfo) => {
    await signIn(page, accounts.viewer, '/watchlists')
    await expect(page.getByRole('heading', { name: 'Watchlists & acquisition evaluations' })).toBeVisible()

    const form = page.locator('.watchlist-sidebar form')
    await expectTextControlsAvoidIOSZoom(page, form)
    await expectMinimumTouchTargets(form.locator('input, button'))

    const name = `Mobile ${testInfo.project.name} ${Date.now()}`
    await form.getByPlaceholder('New watchlist name').fill(name)
    await form.getByPlaceholder('Optional description').fill('Created by the mobile Playwright regression suite')
    await form.getByRole('button', { name: 'Create watchlist' }).click()

    await expect(page.getByRole('heading', { name, exact: true })).toBeVisible()
    await expectNoDocumentOverflow(page)
  })

  test('uses Admin tabs and controls without escaping the viewport', async ({ page }) => {
    await signIn(page, accounts.administrator, '/admin')
    await expect(page.getByRole('heading', { name: 'Data administration' })).toBeVisible()
    await expectNoDocumentOverflow(page)

    const tabs = page.getByRole('tablist', { name: 'Administration tools' })
    await expectMinimumTouchTargets(tabs.getByRole('tab'))
    await expectTextControlsAvoidIOSZoom(page, page.getByTestId('admin-panel-operations'))

    const importsTab = tabs.getByRole('tab', { name: 'Local File Imports' })
    await importsTab.scrollIntoViewIfNeeded()
    await importsTab.click()
    await expect(page.getByTestId('admin-panel-local-imports')).toBeVisible()

    const usersTab = tabs.getByRole('tab', { name: 'User Access' })
    await usersTab.scrollIntoViewIfNeeded()
    await usersTab.click()
    await expect(page.getByRole('heading', { name: 'User access' })).toBeVisible()
    await expectNoDocumentOverflow(page)
  })
})
