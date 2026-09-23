import { computed, ref } from 'vue'
import { flushPromises, mount } from '@vue/test-utils'
import { beforeEach, vi } from 'vitest'

import AdminView from '../AdminView.vue'

const runTask = vi.fn()
const downloadStats = vi.fn()
const importStatsFile = vi.fn()
const importPitchFile = vi.fn()
const loadOverview = vi.fn()
const loadDataHealth = vi.fn()
const loadSnapshots = vi.fn()
const startGameDetailsSync = vi.fn()
const cancelGameDetailsSync = vi.fn()
const loadActiveGameDetailsSync = vi.fn()
const estimateGameDetailsSync = vi.fn()
const gameDetailsTask = ref(null)
const startPitchDataSync = vi.fn()
const cancelPitchDataSync = vi.fn()
const loadActivePitchDataSync = vi.fn()
const estimatePitchDataSync = vi.fn()
const pitchDataTask = ref(null)
const startRosterSync = vi.fn()
const cancelRosterSync = vi.fn()
const loadActiveRosterSync = vi.fn()
const estimateRosterSync = vi.fn()
const rosterTask = ref(null)
const rosterSnapshots = ref([])

vi.mock('../../composables/useAdminTask', () => ({
  useAdminTask: () => ({
    runningTask: computed(() => ''),
    error: computed(() => ''),
    lastResult: ref(null),
    overviewLoading: computed(() => false),
    overviewError: computed(() => ''),
    dataHealth: computed(() => ({
      status: 'critical',
      checkedAt: '2026-07-17T18:00:00Z',
      calculationVersion: '1.0.0',
      summary: {
        checkCount: 11,
        healthyCount: 8,
        warningCount: 2,
        criticalCount: 1,
        affectedRecordCount: 14,
      },
      checks: [
        {
          id: 'final_games_missing_details',
          category: 'Games',
          name: 'Final games have detailed data',
          status: 'critical',
          affectedCount: 2,
          description: 'Final games need detailed synchronization before analytics are complete.',
          recommendation: 'Run Synchronize game details for the affected dates.',
          examples: ['MLB game 700001 · 2026-07-16'],
        },
        {
          id: 'final_games_missing_scores',
          category: 'Games',
          name: 'Final games have scores',
          status: 'healthy',
          affectedCount: 0,
          description: 'Final games should contain both home and away scores.',
          recommendation: 'Synchronize the affected schedule dates from MLB.',
          examples: [],
        },
      ],
    })),
    dataHealthLoading: computed(() => false),
    dataHealthError: computed(() => ''),
    scheduleImportRange: computed(() => ({
      earliestImportDate: '2026-03-26',
      latestImportDate: '2026-05-31',
    })),
    scheduleDateRange: computed(() => ({
      earliestGameDate: '2026-03-26',
      latestGameDate: '2026-09-22',
    })),
    rosterCoverage: computed(() => ({
      earliestDate: '2024-12-31',
      latestDate: '2026-07-17',
    })),
    mlbTeams: computed(() => [
      { id: 1, mlbId: 116, name: 'Detroit Tigers', abbreviation: 'DET', league: 'american' },
      { id: 2, mlbId: 119, name: 'Los Angeles Dodgers', abbreviation: 'LAD', league: 'national' },
    ]),
    databaseMetrics: computed(() => ({
      environment: 'development',
      adapter: 'PostgreSQL',
      databaseName: 'diamond_iq_development',
      serverVersion: '16.3',
      sizeBytes: 536870912,
      userTableSizeBytes: 402653184,
      tableCount: 20,
      estimatedRowCount: 4779000,
      estimatedDeadRowCount: 1250,
      statisticsCollectedSince: '2026-07-01T12:00:00Z',
      measuredAt: '2026-07-15T22:00:00Z',
      largestTables: [
        {
          tableName: 'pitch_data',
          totalSizeBytes: 314572800,
          dataSizeBytes: 251658240,
          indexSizeBytes: 62914560,
          estimatedRowCount: 4649481,
          estimatedDeadRowCount: 1200,
          databasePercentage: 58.59,
        },
        {
          tableName: 'player_season_stats',
          totalSizeBytes: 67108864,
          dataSizeBytes: 41943040,
          indexSizeBytes: 25165824,
          estimatedRowCount: 125000,
          estimatedDeadRowCount: 50,
          databasePercentage: 12.5,
        },
      ],
      mostReadTables: [
        {
          tableName: 'games',
          totalScans: 19000,
          sequentialScans: 4000,
          indexScans: 15000,
          rowsReadOrFetched: 250000,
          lastSequentialScanAt: '2026-07-15T20:00:00Z',
          lastIndexScanAt: '2026-07-15T21:59:00Z',
        },
        {
          tableName: 'teams',
          totalScans: 5000,
          sequentialScans: 5000,
          indexScans: 0,
          rowsReadOrFetched: 150000,
          lastSequentialScanAt: '2026-07-15T19:00:00Z',
          lastIndexScanAt: null,
        },
      ],
    })),
    playerSeasonStatsMetrics: computed(() => ({
      earliestSeason: 1876,
      latestSeason: 2026,
      approximateRowCount: 4649481,
    })),
    pitchDataMetrics: computed(() => ({
      earliestGameDate: '2026-04-01',
      latestGameDate: '2026-05-31',
      approximateRowCount: 125000,
    })),
    gameDetailsMetrics: computed(() => ({
      synchronizedGameCount: 72,
      earliestGameDate: '2026-03-26',
      latestGameDate: '2026-05-31',
      battingLineCount: 2100,
      pitchingLineCount: 720,
      plateAppearanceCount: 5400,
      linkedPitchCount: 18000,
    })),
    contextualBenchmarkMetrics: computed(() => ({
      calculationVersion: '1.0.0',
      benchmarkCount: 1240,
      percentileCount: 12800,
      earliestSourceDate: '2026-04-01',
      latestSourceDate: '2026-05-31',
      lastCalculatedAt: '2026-07-15T22:00:00Z',
    })),
    loadOverview,
    loadDataHealth,
    runTask,
  }),
}))

vi.mock('../../composables/usePlayerSeasonStatsDownload', () => ({
  usePlayerSeasonStatsDownload: () => ({
    downloading: computed(() => false),
    error: computed(() => ''),
    summary: computed(() => ''),
    downloadStats,
  }),
}))

vi.mock('../../composables/useGameDetailsSync', () => ({
  useGameDetailsSync: () => ({
    task: computed(() => gameDetailsTask.value),
    active: computed(() => ['queued', 'running'].includes(gameDetailsTask.value?.status)),
    starting: computed(() => false),
    estimating: computed(() => false),
    error: computed(() => ''),
    start: startGameDetailsSync,
    estimate: estimateGameDetailsSync,
    cancel: cancelGameDetailsSync,
    loadActiveTask: loadActiveGameDetailsSync,
  }),
}))

vi.mock('../../composables/usePitchDataSync', () => ({
  usePitchDataSync: () => ({
    task: computed(() => pitchDataTask.value),
    active: computed(() => ['queued', 'running'].includes(pitchDataTask.value?.status)),
    starting: computed(() => false),
    estimating: computed(() => false),
    error: computed(() => ''),
    start: startPitchDataSync,
    estimate: estimatePitchDataSync,
    cancel: cancelPitchDataSync,
    loadActiveTask: loadActivePitchDataSync,
  }),
}))

vi.mock('../../composables/useRosterSync', () => ({
  useRosterSync: () => ({
    task: computed(() => rosterTask.value),
    active: computed(() => ['queued', 'running'].includes(rosterTask.value?.status)),
    starting: computed(() => false),
    estimating: computed(() => false),
    error: computed(() => ''),
    start: startRosterSync,
    estimate: estimateRosterSync,
    cancel: cancelRosterSync,
    loadActiveTask: loadActiveRosterSync,
  }),
}))

vi.mock('../../composables/usePlayerSeasonStatsImport', () => ({
  usePlayerSeasonStatsImport: () => ({
    uploading: computed(() => false),
    error: computed(() => ''),
    summary: computed(() => ''),
    importFile: importStatsFile,
  }),
}))

vi.mock('../../composables/usePitchDataImport', () => ({
  usePitchDataImport: () => ({
    uploading: computed(() => false),
    error: computed(() => ''),
    summary: computed(() => ''),
    importFile: importPitchFile,
  }),
}))

vi.mock('../../composables/useRosterSnapshots', () => ({
  useRosterSnapshots: () => ({
    snapshots: computed(() => rosterSnapshots.value),
    loading: computed(() => false),
    error: computed(() => ''),
    loadSnapshots,
  }),
}))

describe('AdminView', () => {
  beforeEach(() => {
    runTask.mockReset().mockResolvedValue({ success: true })
    downloadStats.mockReset().mockResolvedValue({ success: true })
    importStatsFile.mockReset().mockResolvedValue({ success: true })
    importPitchFile.mockReset().mockResolvedValue({ success: true })
    loadOverview.mockReset().mockResolvedValue({ success: true })
    loadDataHealth.mockReset().mockResolvedValue({ success: true })
    loadSnapshots.mockReset().mockResolvedValue({ data: [] })
    startGameDetailsSync.mockReset().mockResolvedValue({ id: 11, status: 'queued' })
    cancelGameDetailsSync.mockReset().mockResolvedValue({ id: 11, status: 'running', cancelRequested: true })
    loadActiveGameDetailsSync.mockReset().mockResolvedValue(null)
    estimateGameDetailsSync.mockReset().mockResolvedValue({
      gameCount: 25,
      estimatedSeconds: 1326,
      lowEstimatedSeconds: 1061,
      highEstimatedSeconds: 1724,
      secondsPerGame: 53.04,
      timingSampleGameCount: 25,
      timingSampleRunCount: 1,
      estimateSource: 'historical',
    })
    startPitchDataSync.mockReset().mockResolvedValue({ id: 12, status: 'queued' })
    cancelPitchDataSync.mockReset().mockResolvedValue({ id: 12, status: 'running', cancelRequested: true })
    loadActivePitchDataSync.mockReset().mockResolvedValue(null)
    estimatePitchDataSync.mockReset().mockResolvedValue({
      gameCount: 18,
      estimatedSeconds: 312,
      lowEstimatedSeconds: 250,
      highEstimatedSeconds: 420,
      secondsPerGame: 17.3,
      timingSampleGameCount: 12,
      timingSampleRunCount: 4,
      estimateSource: 'historical',
    })
    startRosterSync.mockReset().mockResolvedValue({ id: 13, status: 'queued' })
    cancelRosterSync.mockReset().mockResolvedValue({ id: 13, status: 'running', cancelRequested: true })
    loadActiveRosterSync.mockReset().mockResolvedValue(null)
    estimateRosterSync.mockReset().mockResolvedValue({
      teamCount: 15,
      estimatedSeconds: 120,
      lowEstimatedSeconds: 90,
      highEstimatedSeconds: 180,
      secondsPerTeam: 8,
      timingSampleTeamCount: 0,
      timingSampleRunCount: 0,
      estimateSource: 'conservative_default',
    })
    gameDetailsTask.value = null
    pitchDataTask.value = null
    rosterTask.value = null
    rosterSnapshots.value = []
  })

  it('centralizes imports, downloads, and Rake-backed synchronization features', async () => {
    const wrapper = mount(AdminView)

    expect(wrapper.text()).toContain('Data administration')
    const dailyRunbook = wrapper.get('[data-test="daily-task-runbook"]')
    expect(dailyRunbook.text()).toContain('Daily in-season sequence')
    expect(dailyRunbook.text()).toContain('Synchronize schedules')
    expect(dailyRunbook.text()).toContain('Synchronize game details')
    expect(dailyRunbook.text()).toContain('Retrieve Statcast and season stats')
    expect(dailyRunbook.text()).toContain('Refresh rosters and player identity')
    expect(dailyRunbook.text()).toContain('Refresh contextual benchmarks')
    expect(dailyRunbook.text()).toContain('Not daily:')
    expect(wrapper.get('[data-test="database-size"]').text()).toContain('Development database')
    expect(wrapper.get('[data-test="database-size"]').text()).toContain('512 MB')
    expect(wrapper.get('[data-test="database-size"]').text()).toContain('PostgreSQL footprint')
    expect(wrapper.get('[data-test="data-health-summary"]').text()).toContain('Critical')
    expect(wrapper.get('[data-test="data-health-summary"]').text()).toContain('1 critical · 2 warnings')
    await wrapper.get('[data-test="data-health-button"]').trigger('click')
    await flushPromises()
    expect(loadDataHealth).not.toHaveBeenCalled()
    const healthDetails = wrapper.get('[data-test="data-health-details"]')
    expect(healthDetails.attributes('role')).toBe('dialog')
    expect(healthDetails.text()).toContain('11 checks')
    expect(healthDetails.text()).toContain('14 total findings')
    expect(healthDetails.text()).toContain('Final games have detailed data')
    expect(healthDetails.text()).toContain('MLB game 700001')
    expect(healthDetails.text()).toContain('Suggested action')
    await wrapper.get('[data-test="data-health-refresh"]').trigger('click')
    expect(loadDataHealth).toHaveBeenCalledTimes(1)
    await wrapper.get('[data-test="data-health-close"]').trigger('click')
    expect(wrapper.find('[data-test="data-health-details"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="database-details"]').exists()).toBe(false)
    await wrapper.get('[data-test="database-details-button"]').trigger('click')
    const databaseDetails = wrapper.get('[data-test="database-details"]')
    expect(databaseDetails.attributes('role')).toBe('dialog')
    expect(databaseDetails.attributes('aria-modal')).toBe('true')
    expect(databaseDetails.text()).toContain('diamond_iq_development')
    expect(databaseDetails.text()).toContain('PostgreSQL 16.3')
    expect(databaseDetails.text()).toContain('384 MB')
    expect(databaseDetails.text()).toContain('20')
    expect(databaseDetails.text()).toContain('4,779,000')
    expect(databaseDetails.text()).toContain('pitch_data')
    expect(databaseDetails.text()).toContain('300 MB')
    expect(databaseDetails.text()).toContain('60.0 MB')
    expect(databaseDetails.text()).toContain('58.59%')
    await wrapper.get('[data-test="database-view-usage-tab"]').trigger('click')
    const usageView = wrapper.get('[data-test="database-view-usage"]')
    expect(usageView.text()).toContain('Statistics collected since')
    expect(usageView.text()).toContain('games')
    expect(usageView.text()).toContain('19,000')
    expect(usageView.text()).toContain('4,000')
    expect(usageView.text()).toContain('15,000')
    expect(usageView.text()).toContain('250,000')
    expect(usageView.text()).toContain('Never recorded')
    await wrapper.get('[data-test="database-details-close"]').trigger('click')
    expect(wrapper.find('[data-test="database-details"]').exists()).toBe(false)
    expect(wrapper.text()).toContain('Player season statistics')
    expect(wrapper.text()).toContain('Statcast pitch data')
    expect(wrapper.get('[data-test="player-season-stats-coverage"]').text()).toContain('1876')
    expect(wrapper.get('[data-test="player-season-stats-coverage"]').text()).toContain('2026')
    expect(wrapper.get('[data-test="player-season-stats-coverage"]').text()).toContain('4,649,481 stat rows')
    expect(wrapper.get('[data-test="pitch-data-coverage"]').text()).toContain('Apr 1, 2026')
    expect(wrapper.get('[data-test="pitch-data-coverage"]').text()).toContain('May 31, 2026')
    expect(wrapper.get('[data-test="pitch-data-coverage"]').text()).toContain('125,000 pitch rows')
    expect(wrapper.get('[data-test="stats-download-form"]').text()).toContain('season-level batting or pitching statistics')
    expect(wrapper.get('[data-test="contracts-download-form"]').text()).toContain('player contract details')
    expect(wrapper.get('[data-test="pitch-download-form"]').text()).toContain('pitch-by-pitch Statcast data')
    expect(wrapper.text()).toContain('Local file imports')
    expect(wrapper.text()).toContain('MLB schedule synchronization')
    expect(wrapper.get('[data-test="schedule-sync-form"]').text()).toContain('games, teams, venues, statuses, and probable pitchers')
    expect(wrapper.get('[data-test="game-details-sync-form"]').text()).toContain('player game lines, batting orders, substitutions, plate appearances')
    expect(wrapper.get('[data-test="game-details-coverage"]').text()).toContain('72')
    expect(wrapper.get('[data-test="game-details-coverage"]').text()).toContain('5,400 plate appearances')
    expect(wrapper.get('[data-test="game-details-coverage"]').text()).toContain('18,000 linked pitches')
    expect(wrapper.text()).toContain('MLB profile synchronization')
    expect(wrapper.get('[data-test="profile-sync-form"]').text()).toContain('biographical, handedness, position, and headshot information')
    expect(wrapper.get('[data-test="team-history-sync-form"]').text()).toContain('official MLB transactions')
    expect(wrapper.text()).toContain('MLB 40-man roster synchronization')
    expect(wrapper.get('[data-test="roster-sync-form"]').text()).toContain('player profiles, roster status, and dated team memberships')
    expect(wrapper.get('[data-test="roster-database-coverage"]').text()).toContain('Dec 31, 2024–Jul 17, 2026')
    expect(wrapper.get('[data-test="roster-team-scope"]').text()).toContain('All MLB teams')
    expect(wrapper.get('[data-test="roster-team-scope"]').text()).toContain('American League')
    expect(wrapper.get('[data-test="roster-team-scope"]').text()).toContain('National League')
    expect(wrapper.get('[data-test="roster-team"]').text()).toContain('DET · Detroit Tigers (AL)')
    expect(wrapper.text()).not.toContain('As of')
    expect(wrapper.text()).not.toContain('Roster type')
    expect(wrapper.text()).not.toContain('Full season')
    expect(wrapper.get('[data-test="roster-coverage-policy"]').text()).toContain('Completed seasons')
    expect(wrapper.get('[data-test="roster-coverage-policy"]').text()).toContain("40-man roster only")
    expect(wrapper.get('[data-test="roster-coverage-policy"]').text()).toContain('transaction-based workflow')
    expect(wrapper.get('[data-test="roster-snapshot-workspace"]').text()).toContain('Active and 40-man roster snapshots')
    expect(wrapper.get('[data-test="roster-snapshot-workspace"]').text()).toContain('without changing historical team memberships')
    expect(wrapper.text()).toContain('Rebuild current player positions')
    expect(wrapper.get('[data-test="contextual-benchmarks-refresh-form"]').text()).toContain('Refresh contextual benchmarks')
    expect(wrapper.get('[data-test="contextual-benchmarks-refresh-form"]').text()).toContain('position, and player-percentile benchmark context')
    expect(wrapper.get('[data-test="contextual-benchmark-coverage"]').text()).toContain('Apr 1, 2026')
    expect(wrapper.get('[data-test="contextual-benchmark-coverage"]').text()).toContain('May 31, 2026')
    expect(wrapper.get('[data-test="contextual-benchmark-coverage"]').text()).toContain('1,240 benchmarks')
    expect(wrapper.get('[data-test="contextual-benchmark-coverage"]').text()).toContain('12,800 player percentiles')
    const operationalCardTitles = wrapper
      .get('[data-test="admin-panel-operations"]')
      .findAll('.admin-card h3')
      .map((heading) => heading.text())
    expect(operationalCardTitles).toEqual([
      'MLB schedule synchronization',
      'MLB game detail synchronization',
      'Statcast pitch data',
      'Player season statistics',
      'Player salaries and contracts',
      'MLB 40-man roster synchronization',
      'MLB profile synchronization',
      'MLB transaction history synchronization',
      'Refresh contextual benchmarks',
      'Rebuild current player positions',
    ])
    expect(wrapper.get('[data-test="schedule-date-range"]').text()).toContain('Imported schedule coverage')
    expect(wrapper.get('[data-test="schedule-date-range"]').text()).toContain('May 31, 2026')
    expect(wrapper.get('[data-test="schedule-date-range"]').text()).toContain('Stored game-date span')
    expect(wrapper.get('[data-test="schedule-date-range"]').text()).toContain('Sep 22, 2026')
  })

  it('organizes administration tools into accessible tab panels', async () => {
    const wrapper = mount(AdminView)
    const operationsTab = wrapper.get('[data-test="admin-tab-operations"]')
    const localImportsTab = wrapper.get('[data-test="admin-tab-local-imports"]')

    expect(operationsTab.attributes('role')).toBe('tab')
    expect(operationsTab.attributes('aria-selected')).toBe('true')
    expect(wrapper.get('[data-test="admin-panel-operations"]').attributes('style') || '').not.toContain('display: none')
    expect(wrapper.get('[data-test="admin-panel-local-imports"]').attributes('style')).toContain('display: none')

    await operationsTab.trigger('keydown', { key: 'ArrowRight' })
    expect(localImportsTab.attributes('aria-selected')).toBe('true')
    expect(wrapper.get('[data-test="admin-panel-operations"]').attributes('style')).toContain('display: none')
    expect(wrapper.get('[data-test="admin-panel-local-imports"]').attributes('style') || '').not.toContain('display: none')
  })

  it('submits download and synchronization forms through their existing services', async () => {
    const wrapper = mount(AdminView)

    await wrapper.get('[data-test="stats-download-form"]').trigger('submit')
    expect(downloadStats).toHaveBeenCalledWith(
      expect.objectContaining({ category: 'batting', replaceSeason: true }),
    )

    await wrapper.get('[data-test="contracts-download-form"]').trigger('submit')
    expect(runTask).toHaveBeenCalledWith(
      'mlb_player_contracts_download',
      expect.objectContaining({ season: expect.any(Number) }),
    )

    await wrapper.get('[data-test="schedule-sync-form"]').trigger('submit')
    expect(runTask).toHaveBeenCalledWith(
      'mlb_schedule_sync',
      expect.objectContaining({ game_types: 'R', sport_id: 1 }),
    )
    expect(loadOverview).toHaveBeenCalledTimes(4)

    await wrapper.get('[data-test="game-details-sync-form"]').trigger('submit')
    await flushPromises()
    expect(wrapper.get('[data-test="game-details-confirmation"]').attributes('role')).toBe('dialog')
    expect(startGameDetailsSync).not.toHaveBeenCalled()
    await wrapper.get('[data-test="game-details-continue"]').trigger('click')
    await flushPromises()
    expect(startGameDetailsSync).toHaveBeenCalledWith(
      expect.objectContaining({ start_date: expect.any(String), end_date: expect.any(String), mlb_game_id: null }),
    )
    expect(loadOverview).toHaveBeenCalledTimes(4)

    await wrapper.get('[data-test="pitch-download-form"]').trigger('submit')
    await flushPromises()
    expect(wrapper.get('[data-test="pitch-data-confirmation"]').attributes('role')).toBe('dialog')
    expect(startPitchDataSync).not.toHaveBeenCalled()
    await wrapper.get('[data-test="pitch-data-continue"]').trigger('click')
    await flushPromises()
    expect(startPitchDataSync).toHaveBeenCalledWith(
      expect.objectContaining({ start_date: expect.any(String), end_date: expect.any(String), game_types: 'R', chunk_days: 7 }),
    )

    await wrapper.get('[data-test="profile-sync-form"]').trigger('submit')
    expect(runTask).toHaveBeenCalledWith(
      'mlb_player_profiles_sync',
      expect.objectContaining({ only_missing: true, batch_size: 50 }),
    )

    await wrapper.get('[data-test="team-history-sync-form"]').trigger('submit')
    expect(runTask).toHaveBeenCalledWith(
      'mlb_player_team_histories_sync',
      expect.objectContaining({ limit: null, mlb_ids: null }),
    )

    await wrapper.get('[data-test="roster-team-scope"]').setValue('national')
    await wrapper.get('[data-test="roster-sync-form"]').trigger('submit')
    await flushPromises()
    expect(wrapper.get('[data-test="roster-confirmation"]').attributes('role')).toBe('dialog')
    expect(startRosterSync).not.toHaveBeenCalled()
    await wrapper.get('[data-test="roster-continue"]').trigger('click')
    await flushPromises()
    expect(startRosterSync).toHaveBeenCalledWith(
      expect.objectContaining({ team_scope: 'national', team_mlb_id: null }),
    )
    expect(startRosterSync.mock.calls.at(-1)[0]).not.toHaveProperty('as_of')
    expect(startRosterSync.mock.calls.at(-1)[0]).not.toHaveProperty('roster_type')

    await wrapper.get('[data-test="snapshot-team"]').setValue('116')
    await wrapper.get('[data-test="roster-snapshot-form"]').trigger('submit')
    await flushPromises()
    expect(runTask).toHaveBeenLastCalledWith(
      'mlb_roster_snapshots_sync',
      expect.objectContaining({ team_mlb_id: '116', snapshot_on: expect.any(String) }),
    )
    expect(loadSnapshots).toHaveBeenCalledWith(
      expect.objectContaining({ teamMlbId: '116', on: expect.any(String) }),
    )

    const benchmarksForm = wrapper.get('[data-test="contextual-benchmarks-refresh-form"]')
    const benchmarkDateInputs = benchmarksForm.findAll('input[type="date"]')
    await benchmarkDateInputs[0].setValue('2026-05-01')
    await benchmarkDateInputs[1].setValue('2026-05-02')
    await benchmarksForm.trigger('submit')
    expect(runTask).toHaveBeenCalledWith(
      'contextual_benchmarks_refresh',
      expect.objectContaining({ start_date: '2026-05-01', end_date: '2026-05-02' }),
    )
  })

  it('warns with a date-span estimate and allows cancellation before synchronizing game details', async () => {
    const wrapper = mount(AdminView)
    const form = wrapper.get('[data-test="game-details-sync-form"]')
    const dateInputs = form.findAll('input[type="date"]')
    await dateInputs[0].setValue('2026-07-01')
    await dateInputs[1].setValue('2026-07-07')

    await form.trigger('submit')
    await flushPromises()

    const confirmation = wrapper.get('[data-test="game-details-confirmation"]')
    expect(confirmation.attributes('aria-modal')).toBe('true')
    expect(confirmation.text()).toContain('7 calendar days')
    expect(confirmation.text()).toContain('Jul 1, 2026–Jul 7, 2026')
    expect(confirmation.text()).toContain('about 22 minutes')
    expect(confirmation.text()).toContain('typically 18–29 minutes')
    expect(confirmation.text()).toContain('25 stored games')
    expect(confirmation.text()).toContain('Keep the Rails server running')
    expect(startGameDetailsSync).not.toHaveBeenCalled()

    await wrapper.get('[data-test="game-details-cancel"]').trigger('click')
    expect(wrapper.find('[data-test="game-details-confirmation"]').exists()).toBe(false)
    expect(startGameDetailsSync).not.toHaveBeenCalled()

    await form.trigger('submit')
    await flushPromises()
    await wrapper.get('[data-test="game-details-continue"]').trigger('click')
    await flushPromises()
    expect(startGameDetailsSync).toHaveBeenCalledWith(
      { start_date: '2026-07-01', end_date: '2026-07-07', mlb_game_id: null },
    )
  })

  it('warns with a chunk estimate and allows cancellation before synchronizing pitch data', async () => {
    const wrapper = mount(AdminView)
    const form = wrapper.get('[data-test="pitch-download-form"]')
    const dateInputs = form.findAll('input[type="date"]')
    await dateInputs[0].setValue('2026-07-01')
    await dateInputs[1].setValue('2026-07-07')

    await form.trigger('submit')
    await flushPromises()

    const confirmation = wrapper.get('[data-test="pitch-data-confirmation"]')
    expect(confirmation.attributes('aria-modal')).toBe('true')
    expect(confirmation.text()).toContain('7 calendar days')
    expect(confirmation.text()).toContain('Jul 1, 2026–Jul 7, 2026')
    expect(confirmation.text()).toContain('about 5 minutes')
    expect(confirmation.text()).toContain('typically 4–7 minutes')
    expect(confirmation.text()).toContain('18 stored games')
    expect(startPitchDataSync).not.toHaveBeenCalled()

    await wrapper.get('[data-test="pitch-data-cancel"]').trigger('click')
    expect(wrapper.find('[data-test="pitch-data-confirmation"]').exists()).toBe(false)
    expect(startPitchDataSync).not.toHaveBeenCalled()

    await form.trigger('submit')
    await flushPromises()
    await wrapper.get('[data-test="pitch-data-continue"]').trigger('click')
    await flushPromises()
    expect(startPitchDataSync).toHaveBeenCalledWith(
      { start_date: '2026-07-01', end_date: '2026-07-07', game_types: 'R', chunk_days: 7, replace_existing: false },
    )
  })

  it('shows persisted game synchronization progress and requests safe cancellation', async () => {
    gameDetailsTask.value = {
      id: 11,
      status: 'running',
      totalItems: 105,
      completedItems: 45,
      failedItems: 2,
      processedItems: 47,
      progressPercentage: 44.8,
      currentItemLabel: 'DET at CLE — July 4, 2026',
      cancelRequested: false,
      elapsedSeconds: 252,
      estimatedRemainingSeconds: 311,
      errorMessage: null,
    }
    const wrapper = mount(AdminView)

    const progress = wrapper.get('[data-test="game-details-progress"]')
    expect(progress.text()).toContain('47 of 105 games')
    expect(progress.text()).toContain('45')
    expect(progress.text()).toContain('DET at CLE — July 4, 2026')
    expect(progress.text()).toContain('4m 12s')
    expect(progress.text()).toContain('5m 11s')
    expect(progress.get('[role="progressbar"]').attributes('aria-valuenow')).toBe('44.8')

    await wrapper.get('[data-test="game-details-cancel-active"]').trigger('click')
    expect(cancelGameDetailsSync).toHaveBeenCalledOnce()
  })

  it('shows batch analytics refresh outcome for game detail synchronization', async () => {
    gameDetailsTask.value = {
      id: 11,
      status: 'completed',
      totalItems: 12,
      completedItems: 12,
      failedItems: 0,
      processedItems: 12,
      progressPercentage: 100,
      currentItemLabel: null,
      cancelRequested: false,
      elapsedSeconds: 321,
      estimatedRemainingSeconds: null,
      errorMessage: null,
      resultData: {
        analytics_refresh: {
          success: true,
          message: 'Refreshed daily analytics for 4 dates',
        },
        worker_pool_summary: {
          configured_workers: 4,
          active_workers: 4,
          games_enqueued: 70,
          games_dequeued: 70,
          games_finalized: 70,
          worker_error_count: 0,
        },
      },
    }

    const wrapper = mount(AdminView)

    expect(wrapper.get('[data-test="game-details-analytics-refresh"]').text()).toContain('Refreshed daily analytics for 4 dates')
    expect(wrapper.get('[data-test="game-details-worker-pool-summary"]').text()).toContain('Worker pool: 4/4 · dequeued 70 · finalized 70 · errors 0')
  })

  it('shows game detail failure diagnostics with game ids and worker error messages', async () => {
    gameDetailsTask.value = {
      id: 11,
      status: 'completed',
      totalItems: 53,
      completedItems: 51,
      failedItems: 2,
      processedItems: 53,
      progressPercentage: 100,
      currentItemLabel: null,
      cancelRequested: false,
      elapsedSeconds: 76,
      estimatedRemainingSeconds: null,
      errorMessage: null,
      resultData: {
        errors: [
          { mlb_id: 823441, message: 'Lock wait timeout exceeded', errors: ['ActiveRecord::LockWaitTimeout'] },
          { mlb_id: 823442, message: 'PG::UniqueViolation duplicate key value', errors: ['PG::UniqueViolation'] },
        ],
        worker_pool_summary: {
          configured_workers: 4,
          active_workers: 4,
          games_enqueued: 53,
          games_dequeued: 53,
          games_finalized: 55,
          worker_error_count: 2,
          worker_errors: ['deadlock detected while locking tuple', 'failed to obtain advisory lock'],
        },
      },
    }

    const wrapper = mount(AdminView)

    const failureDetails = wrapper.get('[data-test="game-details-failure-details"]').text()
    expect(failureDetails).toContain('Failure details')
    expect(failureDetails).toContain('Game 823441: Lock wait timeout exceeded (ActiveRecord::LockWaitTimeout)')
    expect(failureDetails).toContain('Game 823442: PG::UniqueViolation duplicate key value (PG::UniqueViolation)')

    const workerErrors = wrapper.get('[data-test="game-details-worker-errors"]').text()
    expect(workerErrors).toContain('Worker errors')
    expect(workerErrors).toContain('deadlock detected while locking tuple')
    expect(workerErrors).toContain('failed to obtain advisory lock')
  })

  it('shows analytics refresh processing note after game synchronization completes', async () => {
    gameDetailsTask.value = {
      id: 11,
      status: 'running',
      totalItems: 12,
      completedItems: 12,
      failedItems: 0,
      processedItems: 12,
      progressPercentage: 100,
      currentItemLabel: null,
      cancelRequested: false,
      elapsedSeconds: 321,
      estimatedRemainingSeconds: 42,
      errorMessage: null,
      resultData: {},
    }

    const wrapper = mount(AdminView)

    expect(wrapper.get('[data-test="game-details-analytics-refresh-processing"]').text())
      .toContain('Daily analytics refresh is now processing')
  })

  it('runs daily analytics refresh for deferred game-details runs using the same date range', async () => {
    gameDetailsTask.value = {
      id: 20,
      status: 'completed',
      totalItems: 26,
      completedItems: 26,
      failedItems: 0,
      processedItems: 26,
      progressPercentage: 100,
      currentItemLabel: null,
      cancelRequested: false,
      elapsedSeconds: 420,
      estimatedRemainingSeconds: null,
      errorMessage: null,
      taskParameters: {
        start_date: '2026-05-12',
        end_date: '2026-05-15',
      },
      resultData: {
        analytics_refresh: {
          success: false,
          deferred: true,
          message: 'Game details synchronized, but analytics refresh was interrupted by a worker restart.',
        },
      },
    }

    const wrapper = mount(AdminView)
    await wrapper.get('[data-test="game-details-run-deferred-analytics-refresh"]').trigger('click')
    await flushPromises()

    expect(runTask).toHaveBeenCalledWith('daily_analytics_refresh', {
      start_date: '2026-05-12',
      end_date: '2026-05-15',
    })
  })

  it('shows persisted pitch synchronization progress and requests safe cancellation', async () => {
    pitchDataTask.value = {
      id: 12,
      status: 'running',
      totalItems: 18,
      completedItems: 8,
      failedItems: 2,
      processedItems: 10,
      progressPercentage: 40.0,
      currentItemLabel: 'DET at CLE — July 10, 2026',
      cancelRequested: false,
      elapsedSeconds: 180,
      estimatedRemainingSeconds: 180,
      errorMessage: null,
    }
    const wrapper = mount(AdminView)

    const progress = wrapper.get('[data-test="pitch-data-progress"]')
  expect(progress.text()).toContain('10 of 18 games')
  expect(progress.text()).toContain('8')
    expect(progress.text()).toContain('Current game')
    expect(progress.text()).toContain('DET at CLE — July 10, 2026')
    expect(progress.text()).toContain('Cancel after current game')
    expect(progress.text()).toContain('3m')
    expect(progress.get('[role="progressbar"]').attributes('aria-valuenow')).toBe('40')

    await wrapper.get('[data-test="pitch-data-cancel-active"]').trigger('click')
    expect(cancelPitchDataSync).toHaveBeenCalledOnce()
  })

  it('holds pitch synchronization progress at the analytics phase after all games finish', () => {
    pitchDataTask.value = {
      id: 14,
      status: 'running',
      totalItems: 18,
      completedItems: 18,
      failedItems: 0,
      processedItems: 18,
      progressPercentage: 80.0,
      currentItemLabel: 'Refreshing daily analytics',
      cancelRequested: false,
      elapsedSeconds: 240,
      estimatedRemainingSeconds: null,
      errorMessage: null,
      resultData: { progress_phase: 'analytics' },
    }

    const wrapper = mount(AdminView)
    const progress = wrapper.get('[data-test="pitch-data-progress"]')

    expect(progress.text()).toContain('Finalizing analytics')
    expect(progress.text()).toContain('Finalizing imported pitch data')
    expect(progress.get('[data-test="pitch-data-analytics-refresh-processing"]').text())
      .toContain('Daily analytics are now being refreshed')
    expect(progress.get('[role="progressbar"]').attributes('aria-valuenow')).toBe('80')
  })

  it('shows a roster estimate and persisted team progress with safe cancellation', async () => {
    const wrapper = mount(AdminView)
    await wrapper.get('[data-test="roster-team-scope"]').setValue('national')
    await wrapper.get('[data-test="roster-sync-form"]').trigger('submit')
    await flushPromises()

    const confirmation = wrapper.get('[data-test="roster-confirmation"]')
    expect(confirmation.text()).toContain('15 teams')
    expect(confirmation.text()).toContain('the national league for')
    expect(confirmation.text()).toContain('about 2 minutes')

    await wrapper.get('[data-test="roster-cancel"]').trigger('click')
    expect(startRosterSync).not.toHaveBeenCalled()
    wrapper.unmount()

    rosterTask.value = {
      id: 13,
      status: 'running',
      totalItems: 15,
      completedItems: 6,
      failedItems: 1,
      processedItems: 7,
      progressPercentage: 46.7,
      currentItemLabel: 'DET · Detroit Tigers',
      cancelRequested: false,
      elapsedSeconds: 56,
      estimatedRemainingSeconds: 64,
      errorMessage: null,
    }
    const progressWrapper = mount(AdminView)
    const progress = progressWrapper.get('[data-test="roster-sync-progress"]')
    expect(progress.text()).toContain('7 of 15 teams')
    expect(progress.text()).toContain('Current team')
    expect(progress.text()).toContain('DET · Detroit Tigers')
    expect(progress.text()).toContain('Cancel after current team')

    await progressWrapper.get('[data-test="roster-sync-cancel-active"]').trigger('click')
    expect(cancelRosterSync).toHaveBeenCalledOnce()
  })

  it('displays stored Active and 40-man snapshot players', async () => {
    rosterSnapshots.value = [
      {
        id: 1,
        roster_type: 'active',
        snapshot_on: '2026-07-15',
        source_name: 'MLB Stats API',
        last_synced_at: '2026-07-15T12:00:00Z',
        players: [{ mlb_id: 592450, player_id: 9, full_name: 'Aaron Judge', jersey_number: '99', position_code: 'RF', status_description: 'Active' }],
      },
      {
        id: 2,
        roster_type: '40Man',
        snapshot_on: '2026-07-15',
        source_name: 'MLB Stats API',
        last_synced_at: '2026-07-15T12:00:00Z',
        players: [{ mlb_id: 605280, player_id: null, full_name: 'Test Pitcher', jersey_number: '50', position_code: 'P', status_description: 'Minors' }],
      },
    ]

    const wrapper = mount(AdminView)
    await wrapper.vm.$nextTick()

    const workspace = wrapper.get('[data-test="roster-snapshot-workspace"]')
    expect(workspace.text()).toContain('Active roster')
    expect(workspace.text()).toContain('40-man roster')
    expect(workspace.text()).toContain('Aaron Judge')
    expect(workspace.text()).toContain('Test Pitcher')
  })
})
