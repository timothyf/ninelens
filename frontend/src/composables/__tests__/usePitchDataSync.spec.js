import { mount } from '@vue/test-utils'
import { defineComponent, h } from 'vue'
import { afterEach, beforeEach, vi } from 'vitest'

import { usePitchDataSync } from '../usePitchDataSync'

function mountComposable() {
  let api
  const wrapper = mount(defineComponent({
    setup() {
      api = usePitchDataSync()
      return () => h('div')
    },
  }))
  return { api, wrapper }
}

describe('usePitchDataSync', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
  })

  it('uses the shared lifecycle while retaining pitch-specific estimate fields', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          data: {
            task_parameters: { start_date: '2026-07-01', end_date: '2026-07-02' },
            game_count: 12,
            estimated_seconds: 540,
            low_estimated_seconds: 432,
            high_estimated_seconds: 702,
            seconds_per_game: 45,
            timing_sample_game_count: 24,
            timing_sample_run_count: 2,
            estimate_source: 'historical',
          },
        }),
      })
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          data: {
            id: 21,
            task_name: 'pitch_data_sync',
            status: 'running',
            total_items: 10,
            completed_items: 10,
            failed_items: 2,
            processed_items: 12,
            progress_percentage: 120,
            current_item_mlb_id: 800021,
            current_item_label: 'DET at CLE',
            elapsed_seconds: 90,
            estimated_remaining_seconds: 0,
            started_at: '2026-07-02T12:00:00Z',
            last_heartbeat_at: '2026-07-02T12:01:30Z',
          },
        }),
      })
    vi.stubGlobal('fetch', fetchMock)
    const { api, wrapper } = mountComposable()
    const parameters = { start_date: '2026-07-01', end_date: '2026-07-02', game_types: 'R' }

    const estimate = await api.estimate(parameters)
    expect(estimate).toMatchObject({ gameCount: 12, secondsPerGame: 45, estimateSource: 'historical' })
    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      '/api/admin/task_runs/estimate?task_name=pitch_data_sync&start_date=2026-07-01&end_date=2026-07-02&game_types=R',
      expect.any(Object),
    )

    await api.start(parameters)
    expect(api.task.value).toMatchObject({
      taskName: 'pitch_data_sync',
      processedItems: 10,
      progressPercentage: 100,
      currentItemMlbId: 800021,
      startedAt: '2026-07-02T12:00:00Z',
      lastHeartbeatAt: '2026-07-02T12:01:30Z',
    })
    wrapper.unmount()
  })
})
