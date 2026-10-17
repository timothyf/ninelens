import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'

import AdminScheduleSyncCard from '../admin/AdminScheduleSyncCard.vue'

function mountCard(props = {}) {
  return mount(AdminScheduleSyncCard, {
    props: {
      options: {
        startDate: '2026-10-17',
        endDate: '2026-10-19',
        gameTypes: 'R,W,D,L,F',
        sportId: 1,
      },
      importRange: {
        earliestImportDate: '2026-03-25',
        latestImportDate: '2026-10-19',
      },
      dateRange: {
        earliestGameDate: '2026-03-25',
        latestGameDate: '2026-10-19',
      },
      ...props,
    },
  })
}

describe('AdminScheduleSyncCard', () => {
  it('keeps a failed schedule sync and its HTTP error visible in the schedule card', () => {
    const wrapper = mountCard({
      task: {
        taskName: 'mlb_schedule_sync',
        status: 'failed',
        progressPercentage: 0,
      },
      error: 'Failed to download MLB schedule: HTTP 406: Not Acceptable',
    })

    const alert = wrapper.get('[role="alert"]')
    expect(alert.text()).toContain('Task could not be completed')
    expect(alert.text()).toContain('HTTP 406: Not Acceptable')
    expect(wrapper.get('[data-test="schedule-sync-form"]').element.contains(alert.element)).toBe(true)
  })

  it('shows schedule progress next to the synchronization controls', () => {
    const wrapper = mountCard({
      task: {
        taskName: 'mlb_schedule_sync',
        status: 'running',
        progressPercentage: 25,
        currentItemLabel: 'Downloading MLB schedule',
      },
      runningTask: 'mlb_schedule_sync',
      anyActionRunning: true,
    })

    expect(wrapper.get('[data-test="task-progress"]').text()).toContain('Downloading MLB schedule')
    expect(wrapper.get('button[type="submit"]').text()).toBe('Synchronizing schedule…')
  })
})
