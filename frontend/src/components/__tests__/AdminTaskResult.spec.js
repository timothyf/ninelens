import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'

import AdminTaskResult from '../admin/AdminTaskResult.vue'

describe('AdminTaskResult', () => {
  it('renders an error instead of the latest result', () => {
    const wrapper = mount(AdminTaskResult, {
      props: {
        error: 'The synchronization failed.',
        result: { message: 'Older success' },
      },
    })

    expect(wrapper.get('[role="alert"]').text()).toContain('Task could not be completed')
    expect(wrapper.text()).toContain('The synchronization failed.')
    expect(wrapper.text()).not.toContain('Older success')
  })

  it('presents the latest result and its scalar details', () => {
    const wrapper = mount(AdminTaskResult, {
      props: {
        result: {
          message: 'Schedule synchronization completed.',
          task: 'mlb_schedule_sync',
          finishedAt: '2026-07-19T12:00:00Z',
          data: {
            downloaded_count: 42,
            replace_season: false,
            csv_data: 'source_season,player_name\n2026,Example Player',
            ignored_array: ['value'],
            ignored_object: { value: 1 },
            ignored_null: null,
          },
        },
      },
    })

    const result = wrapper.get('[data-test="task-result"]')
    expect(result.text()).toContain('Latest task result')
    expect(result.text()).toContain('Schedule synchronization completed.')
    expect(result.text()).toContain('Mlb Schedule Sync')
    expect(result.text()).toContain('Downloaded Count')
    expect(result.text()).toContain('42')
    expect(result.text()).toContain('Replace Season')
    expect(result.text()).not.toContain('Csv Data')
    expect(result.text()).not.toContain('Example Player')
    expect(result.text()).not.toContain('Ignored Array')
    expect(result.text()).not.toContain('Ignored Object')
    expect(result.text()).not.toContain('Ignored Null')
  })

  it('renders nothing without an error or result', () => {
    const wrapper = mount(AdminTaskResult)

    expect(wrapper.find('[role="alert"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="task-result"]').exists()).toBe(false)
  })
})
