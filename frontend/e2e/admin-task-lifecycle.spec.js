import { expect, test } from '@playwright/test'

const administrator = {
  email: 'e2e.task-admin@ninelens.test',
  password: 'playwright-password-123',
}

function taskRun(attributes = {}) {
  return {
    id: 9_001,
    task_name: 'player_positions_backfill',
    status: 'queued',
    task_parameters: {},
    initiated_by: { id: 1, name: 'E2E Task Administrator', email: administrator.email, role: 'administrator' },
    total_items: 2,
    completed_items: 0,
    failed_items: 0,
    processed_items: 0,
    progress_percentage: 0,
    current_item_label: 'Waiting for a worker',
    cancel_requested: false,
    error_message: '',
    result_data: {},
    elapsed_seconds: 0,
    estimated_remaining_seconds: null,
    started_at: null,
    finished_at: null,
    created_at: '2026-08-31T12:00:00.000Z',
    updated_at: '2026-08-31T12:00:00.000Z',
    ...attributes,
  }
}

async function signIn(page) {
  await page.goto('/login?redirect=/admin')
  await page.getByLabel('Email').fill(administrator.email)
  await page.getByLabel('Password').fill(administrator.password)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page).toHaveURL(/\/admin$/)
}

async function fulfillTaskRun(route, data, status = 200) {
  await route.fulfill({
    status,
    contentType: 'application/json',
    body: JSON.stringify({ data }),
  })
}

test.describe('Admin task lifecycle', () => {
  test('shows task start, progress, and completion', async ({ page }) => {
    let pollCount = 0

    await page.route('**/api/admin/task_runs**', async (route) => {
      const request = route.request()
      const url = new URL(request.url())

      if (request.method() === 'POST' && url.pathname === '/api/admin/task_runs') {
        await fulfillTaskRun(route, taskRun(), 202)
        return
      }

      if (request.method() === 'GET' && url.pathname === '/api/admin/task_runs') {
        await fulfillTaskRun(route, [])
        return
      }

      if (request.method() === 'GET' && url.pathname === '/api/admin/task_runs/9001') {
        pollCount += 1
        if (pollCount === 1) {
          await fulfillTaskRun(route, taskRun({
            status: 'running',
            completed_items: 1,
            processed_items: 1,
            progress_percentage: 50,
            current_item_label: 'Reconciling active player positions',
            started_at: '2026-08-31T12:00:01.000Z',
          }))
        } else {
          await fulfillTaskRun(route, taskRun({
            status: 'completed',
            completed_items: 2,
            processed_items: 2,
            progress_percentage: 100,
            current_item_label: null,
            started_at: '2026-08-31T12:00:01.000Z',
            finished_at: '2026-08-31T12:00:04.000Z',
            result_data: {
              success: true,
              message: 'E2E position rebuild completed',
              data: { positions_rebuilt: 2 },
            },
          }))
        }
        return
      }

      await route.fallback()
    })

    await signIn(page)
    await expect(page.getByRole('heading', { name: 'Data administration' })).toBeVisible()

    await page.getByRole('button', { name: 'Rebuild player positions' }).click()

    const progress = page.getByTestId('task-progress')
    await expect(progress).toContainText('Queued for processing')
    await expect(progress.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '0')
    await expect(progress).toContainText('Task in progress')
    await expect(progress).toContainText('Reconciling active player positions')
    await expect(progress.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '50')

    const result = page.getByTestId('task-result')
    await expect(result).toContainText('E2E position rebuild completed')
    await expect(result).toContainText('Positions Rebuilt')
    await expect(result).toContainText('2')
  })

  test('shows the latest failed task', async ({ page }) => {
    await page.route('**/api/admin/task_runs**', async (route) => {
      const request = route.request()
      const url = new URL(request.url())

      if (request.method() === 'GET' && url.pathname === '/api/admin/task_runs') {
        await fulfillTaskRun(route, [taskRun({
          id: 9_002,
          status: 'failed',
          failed_items: 1,
          processed_items: 1,
          progress_percentage: 50,
          current_item_label: null,
          error_message: 'E2E task failure: position source is unavailable',
          started_at: '2026-08-31T12:00:01.000Z',
          finished_at: '2026-08-31T12:00:02.000Z',
        })])
        return
      }

      await route.fallback()
    })

    await signIn(page)

    const failure = page.getByTestId('task-result')
    await expect(failure).toHaveAttribute('role', 'alert')
    await expect(failure).toContainText('Task could not be completed')
    await expect(failure).toContainText('E2E task failure: position source is unavailable')
  })
})
