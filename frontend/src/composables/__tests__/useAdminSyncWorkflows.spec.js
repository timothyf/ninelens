import { flushPromises, mount } from '@vue/test-utils'
import { computed, defineComponent, h, nextTick, reactive, ref } from 'vue'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useAdminSyncWorkflows } from '../useAdminSyncWorkflows'

function syncService(task = ref(null)) {
  return {
    task,
    active: computed(() => ['queued', 'running'].includes(task.value?.status)),
    starting: ref(false),
    estimating: ref(false),
    error: ref(''),
    start: vi.fn().mockResolvedValue({ status: 'queued' }),
    estimate: vi.fn(),
    cancel: vi.fn().mockResolvedValue({ cancelRequested: true }),
    loadActiveTask: vi.fn().mockResolvedValue(null),
    loadLatestTask: vi.fn().mockResolvedValue(null),
  }
}

function mountComposable({
  gameDetailsOptions = {},
  pitchOptions = {},
  rosterOptions = {},
  gameDetailsSync = syncService(),
  pitchDataSync = syncService(),
  rosterSync = syncService(),
} = {}) {
  const loadOverview = vi.fn().mockResolvedValue({ success: true })
  const runTask = vi.fn().mockResolvedValue({ success: true })
  let api
  const wrapper = mount(defineComponent({
    setup() {
      api = useAdminSyncWorkflows({
        gameDetailsOptions: reactive({
          startDate: '2026-07-01',
          endDate: '2026-07-07',
          mlbGameId: '',
          ...gameDetailsOptions,
        }),
        pitchOptions: reactive({
          startDate: '2026-07-01',
          endDate: '2026-07-07',
          gameTypes: 'R',
          chunkDays: 7,
          replaceExisting: false,
          ...pitchOptions,
        }),
        rosterOptions: reactive({
          teamScope: 'team',
          teamMlbId: '116',
          season: 2026,
          ...rosterOptions,
        }),
        loadOverview,
        runTask,
        gameDetailsSync,
        pitchDataSync,
        rosterSync,
      })
      return () => h('div')
    },
  }))

  return { api, wrapper, loadOverview, runTask }
}

describe('useAdminSyncWorkflows', () => {
  let gameDetailsSync
  let pitchDataSync
  let rosterSync

  beforeEach(() => {
    gameDetailsSync = syncService()
    pitchDataSync = syncService()
    rosterSync = syncService()
  })

  it('estimates, confirms, and cancels game-detail synchronization', async () => {
    gameDetailsSync.estimate.mockResolvedValue({
      gameCount: 25,
      estimatedSeconds: 1326,
      lowEstimatedSeconds: 1061,
      highEstimatedSeconds: 1724,
      secondsPerGame: 53.04,
      timingSampleGameCount: 25,
      timingSampleRunCount: 1,
      estimateSource: 'historical',
    })
    const { api, wrapper } = mountComposable({
      gameDetailsOptions: { startDate: '2026-07-07', endDate: '2026-07-01' },
      gameDetailsSync,
      pitchDataSync,
      rosterSync,
    })
    await flushPromises()

    await api.requestGameDetailsSync()
    expect(gameDetailsSync.estimate).toHaveBeenCalledWith({
      start_date: '2026-07-07',
      end_date: '2026-07-07',
      mlb_game_id: null,
    })
    expect(api.gameDetailsConfirmationOpen.value).toBe(true)
    expect(api.gameDetailsEstimate.value).toMatchObject({
      scope: '1 calendar day · Jul 7, 2026–Jul 7, 2026',
      estimatedGames: 25,
      duration: 'about 22 minutes',
      range: '18–29 minutes',
    })

    const focusSyncButton = vi.fn()
    api.gameDetailsSyncCard.value = { focusSyncButton }
    await api.cancelGameDetailsSync()
    expect(api.gameDetailsConfirmationOpen.value).toBe(false)
    expect(focusSyncButton).toHaveBeenCalledOnce()

    await api.requestGameDetailsSync()
    await api.confirmGameDetailsSync()
    expect(gameDetailsSync.start).toHaveBeenCalledWith({
      start_date: '2026-07-07',
      end_date: '2026-07-07',
      mlb_game_id: null,
    })
    expect(api.gameDetailsConfirmationOpen.value).toBe(false)
    wrapper.unmount()
  })

  it('estimates and starts pitch-data synchronization', async () => {
    pitchDataSync.estimate.mockResolvedValue({
      gameCount: 18,
      estimatedSeconds: 312,
      lowEstimatedSeconds: 250,
      highEstimatedSeconds: 420,
      secondsPerGame: 17.3,
      timingSampleGameCount: 12,
      timingSampleRunCount: 4,
      estimateSource: 'historical',
    })
    const { api, wrapper } = mountComposable({ gameDetailsSync, pitchDataSync, rosterSync })
    await flushPromises()

    await api.requestPitchDataSync()
    expect(pitchDataSync.estimate).toHaveBeenCalledWith({
      start_date: '2026-07-01',
      end_date: '2026-07-07',
      game_types: 'R',
      chunk_days: 7,
      replace_existing: false,
    })
    expect(api.pitchDataEstimate.value).toMatchObject({
      scope: '7 calendar days · Jul 1, 2026–Jul 7, 2026',
      estimatedGames: 18,
      duration: 'about 5 minutes',
      range: '4–7 minutes',
    })

    await api.confirmPitchDataSync()
    expect(pitchDataSync.start).toHaveBeenCalledWith({
      start_date: '2026-07-01',
      end_date: '2026-07-07',
      game_types: 'R',
      chunk_days: 7,
      replace_existing: false,
    })
    wrapper.unmount()
  })

  it('estimates, starts, and cancels roster synchronization', async () => {
    rosterSync.estimate.mockResolvedValue({
      teamCount: 15,
      estimatedSeconds: 120,
      lowEstimatedSeconds: 90,
      highEstimatedSeconds: 180,
      secondsPerTeam: 8,
      timingSampleTeamCount: 0,
      timingSampleRunCount: 0,
      estimateSource: 'conservative_default',
    })
    const { api, wrapper } = mountComposable({
      gameDetailsSync,
      pitchDataSync,
      rosterSync,
      rosterOptions: { teamScope: 'national', teamMlbId: '', season: 2026 },
    })
    await flushPromises()

    await api.requestRosterSync()
    expect(rosterSync.estimate).toHaveBeenCalledWith({
      team_scope: 'national',
      team_mlb_id: null,
      season: 2026,
    })
    expect(api.rosterEstimate.value).toMatchObject({
      scope: 'the national league for 2026',
      estimatedGames: 15,
      workloadSingular: 'team',
      workloadPlural: 'teams',
      duration: 'about 2 minutes',
      range: '2–3 minutes',
    })

    await api.confirmRosterSync()
    expect(rosterSync.start).toHaveBeenCalledWith({
      team_scope: 'national',
      team_mlb_id: null,
      season: 2026,
    })

    rosterSync.task.value = { id: 14, status: 'running' }
    await api.cancelActiveRosterSync()
    expect(rosterSync.cancel).toHaveBeenCalledOnce()
    wrapper.unmount()
  })

  it('recovers active tasks and refreshes overview when either workflow finishes', async () => {
    const { wrapper, loadOverview } = mountComposable({ gameDetailsSync, pitchDataSync, rosterSync })
    await flushPromises()
    expect(gameDetailsSync.loadLatestTask).toHaveBeenCalledOnce()
    expect(pitchDataSync.loadActiveTask).toHaveBeenCalledOnce()
    expect(rosterSync.loadActiveTask).toHaveBeenCalledOnce()

    gameDetailsSync.task.value = { status: 'running' }
    await nextTick()
    gameDetailsSync.task.value = { status: 'completed' }
    await nextTick()
    expect(loadOverview).toHaveBeenCalledOnce()

    pitchDataSync.task.value = { status: 'queued' }
    await nextTick()
    pitchDataSync.task.value = { status: 'cancelled' }
    await nextTick()
    expect(loadOverview).toHaveBeenCalledTimes(2)

    rosterSync.task.value = { status: 'running' }
    await nextTick()
    rosterSync.task.value = { status: 'completed' }
    await nextTick()
    expect(loadOverview).toHaveBeenCalledTimes(3)
    wrapper.unmount()
  })

  it('refreshes the latest game-detail task while the Admin page stays open', async () => {
    const interval = vi.spyOn(window, 'setInterval')
    const { wrapper } = mountComposable({ gameDetailsSync, pitchDataSync, rosterSync })
    await flushPromises()

    const refresh = interval.mock.calls.find(([, milliseconds]) => milliseconds === 30_000)?.[0]
    expect(refresh).toBeTypeOf('function')
    refresh()
    await flushPromises()

    expect(gameDetailsSync.loadLatestTask).toHaveBeenCalledTimes(2)
    wrapper.unmount()
    interval.mockRestore()
  })

  it('runs a deferred analytics refresh and reloads its task state', async () => {
    gameDetailsSync.task.value = {
      status: 'completed',
      taskParameters: { start_date: '2026-05-12', end_date: '2026-05-15' },
    }
    const { api, wrapper, loadOverview, runTask } = mountComposable({ gameDetailsSync, pitchDataSync, rosterSync })
    await flushPromises()

    await api.refreshGameDetailsAnalytics()
    expect(runTask).toHaveBeenCalledWith('daily_analytics_refresh', {
      start_date: '2026-05-12',
      end_date: '2026-05-15',
    })
    expect(loadOverview).toHaveBeenCalledOnce()
    expect(gameDetailsSync.loadLatestTask).toHaveBeenCalledTimes(2)
    wrapper.unmount()
  })
})
