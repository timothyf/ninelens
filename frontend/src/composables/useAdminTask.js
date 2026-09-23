import { computed, ref } from 'vue'

import { adminRequestHeaders } from './apiAuth'
import { useBackgroundTaskRun } from './useBackgroundTaskRun'
import { API_BASE_URL } from '../config'
const GENERIC_ADMIN_TASKS = [
  'mlb_schedule_sync',
  'mlb_player_profiles_sync',
  'mlb_player_team_histories_sync',
  'mlb_player_contracts_download',
  'mlb_roster_snapshots_sync',
  'player_positions_backfill',
  'daily_analytics_refresh',
  'contextual_benchmarks_refresh',
]

export function useAdminTask() {
  const backgroundTask = useBackgroundTaskRun(GENERIC_ADMIN_TASKS)
  const overviewLoading = ref(false)
  const overviewError = ref('')
  const dataHealth = ref(null)
  const dataHealthLoading = ref(false)
  const dataHealthError = ref('')
  const scheduleImportRange = ref({ earliestImportDate: null, latestImportDate: null })
  const scheduleDateRange = ref({ earliestGameDate: null, latestGameDate: null })
  const rosterCoverage = ref({ earliestDate: null, latestDate: null })
  const mlbTeams = ref([])
  const databaseMetrics = ref({
    environment: '',
    adapter: '',
    databaseName: '',
    serverVersion: '',
    sizeBytes: null,
    userTableSizeBytes: null,
    tableCount: 0,
    estimatedRowCount: 0,
    estimatedDeadRowCount: 0,
    statisticsCollectedSince: null,
    largestTables: [],
    mostReadTables: [],
    measuredAt: null,
  })
  const playerSeasonStatsMetrics = ref({ earliestSeason: null, latestSeason: null, approximateRowCount: 0 })
  const pitchDataMetrics = ref({ earliestGameDate: null, latestGameDate: null, approximateRowCount: 0 })
  const gameDetailsMetrics = ref({
    synchronizedGameCount: 0,
    earliestGameDate: null,
    latestGameDate: null,
    battingLineCount: 0,
    pitchingLineCount: 0,
    plateAppearanceCount: 0,
    linkedPitchCount: 0,
  })
  const contextualBenchmarkMetrics = ref({
    calculationVersion: '',
    benchmarkCount: 0,
    percentileCount: 0,
    earliestSourceDate: null,
    latestSourceDate: null,
    lastCalculatedAt: null,
  })

  async function loadOverview() {
    overviewLoading.value = true
    overviewError.value = ''

    try {
      const response = await fetch(`${API_BASE_URL}/api/admin/tasks`, {
        headers: adminRequestHeaders({ Accept: 'application/json' }),
      })
      const payload = await response.json()

      if (!response.ok) {
        throw new Error(payload?.message || `Admin overview failed with status ${response.status}.`)
      }

      const range = payload?.meta?.schedule_date_range || {}
      const importRange = payload?.meta?.schedule_import_range || {}
      const rosterRange = payload?.meta?.roster_coverage || {}
      scheduleImportRange.value = {
        earliestImportDate: importRange.earliest_import_date || null,
        latestImportDate: importRange.latest_import_date || null,
      }
      scheduleDateRange.value = {
        earliestGameDate: range.earliest_game_date || null,
        latestGameDate: range.latest_game_date || null,
      }
      rosterCoverage.value = {
        earliestDate: rosterRange.earliest_date || null,
        latestDate: rosterRange.latest_date || null,
      }
      mlbTeams.value = (payload?.meta?.mlb_teams || []).map((team) => ({
        id: team.id,
        mlbId: team.mlb_id,
        name: team.name,
        abbreviation: team.abbreviation,
        league: team.league,
      }))
      const database = payload?.meta?.database || {}
      databaseMetrics.value = {
        environment: database.environment || '',
        adapter: database.adapter || '',
        databaseName: database.database_name || '',
        serverVersion: database.server_version || '',
        sizeBytes:
          database.size_bytes !== null &&
          database.size_bytes !== undefined &&
          Number.isFinite(Number(database.size_bytes))
            ? Number(database.size_bytes)
            : null,
        userTableSizeBytes:
          database.user_table_size_bytes !== null && database.user_table_size_bytes !== undefined
            ? Number(database.user_table_size_bytes)
            : null,
        tableCount: Number(database.table_count || 0),
        estimatedRowCount: Number(database.estimated_row_count || 0),
        estimatedDeadRowCount: Number(database.estimated_dead_row_count || 0),
        statisticsCollectedSince: database.statistics_collected_since || null,
        largestTables: (database.largest_tables || []).map((table) => ({
          tableName: table.table_name,
          totalSizeBytes: Number(table.total_size_bytes || 0),
          dataSizeBytes: Number(table.data_size_bytes || 0),
          indexSizeBytes: Number(table.index_size_bytes || 0),
          estimatedRowCount: Number(table.estimated_row_count || 0),
          estimatedDeadRowCount: Number(table.estimated_dead_row_count || 0),
          databasePercentage: Number(table.database_percentage || 0),
        })),
        mostReadTables: (database.most_read_tables || []).map((table) => ({
          tableName: table.table_name,
          totalScans: Number(table.total_scans || 0),
          sequentialScans: Number(table.sequential_scans || 0),
          indexScans: Number(table.index_scans || 0),
          rowsReadOrFetched: Number(table.rows_read_or_fetched || 0),
          lastSequentialScanAt: table.last_sequential_scan_at || null,
          lastIndexScanAt: table.last_index_scan_at || null,
        })),
        measuredAt: database.measured_at || null,
      }
      const playerSeasonStats = payload?.meta?.player_season_stats || {}
      playerSeasonStatsMetrics.value = {
        earliestSeason: playerSeasonStats.earliest_season ?? null,
        latestSeason: playerSeasonStats.latest_season ?? null,
        approximateRowCount: Number(playerSeasonStats.approximate_row_count || 0),
      }
      const pitchData = payload?.meta?.pitch_data || {}
      pitchDataMetrics.value = {
        earliestGameDate: pitchData.earliest_game_date || null,
        latestGameDate: pitchData.latest_game_date || null,
        approximateRowCount: Number(pitchData.approximate_row_count || 0),
      }
      const gameDetails = payload?.meta?.game_details || {}
      gameDetailsMetrics.value = {
        synchronizedGameCount: Number(gameDetails.synchronized_game_count || 0),
        earliestGameDate: gameDetails.earliest_game_date || null,
        latestGameDate: gameDetails.latest_game_date || null,
        battingLineCount: Number(gameDetails.batting_line_count || 0),
        pitchingLineCount: Number(gameDetails.pitching_line_count || 0),
        plateAppearanceCount: Number(gameDetails.plate_appearance_count || 0),
        linkedPitchCount: Number(gameDetails.linked_pitch_count || 0),
      }
      const contextualBenchmarks = payload?.meta?.contextual_benchmarks || {}
      contextualBenchmarkMetrics.value = {
        calculationVersion: contextualBenchmarks.calculation_version || '',
        benchmarkCount: Number(contextualBenchmarks.benchmark_count || 0),
        percentileCount: Number(contextualBenchmarks.percentile_count || 0),
        earliestSourceDate: contextualBenchmarks.earliest_source_date || null,
        latestSourceDate: contextualBenchmarks.latest_source_date || null,
        lastCalculatedAt: contextualBenchmarks.last_calculated_at || null,
      }
      return payload
    } catch (overviewLoadError) {
      overviewError.value = overviewLoadError.message || 'Unable to load the admin overview.'
      return null
    } finally {
      overviewLoading.value = false
    }
  }

  async function runTask(taskName, parameters = {}) {
    return backgroundTask.start('/api/admin/task_runs', {
        method: 'POST',
        headers: adminRequestHeaders({
          Accept: 'application/json',
          'Content-Type': 'application/json',
        }),
        body: JSON.stringify({ task_name: taskName, ...parameters }),
      })
  }

  async function loadDataHealth() {
    dataHealthLoading.value = true
    dataHealthError.value = ''

    try {
      const response = await fetch(`${API_BASE_URL}/api/admin/data_health`, {
        headers: adminRequestHeaders({ Accept: 'application/json' }),
      })
      const payload = await response.json()

      if (!response.ok) {
        throw new Error(payload?.message || `Data health check failed with status ${response.status}.`)
      }

      const report = payload?.data || {}
      const summary = report.summary || {}
      dataHealth.value = {
        status: report.status || 'healthy',
        checkedAt: report.checked_at || null,
        calculationVersion: report.calculation_version || '',
        summary: {
          checkCount: Number(summary.check_count || 0),
          healthyCount: Number(summary.healthy_count || 0),
          warningCount: Number(summary.warning_count || 0),
          criticalCount: Number(summary.critical_count || 0),
          affectedRecordCount: Number(summary.affected_record_count || 0),
        },
        checks: (report.checks || []).map((check) => ({
          id: check.id,
          category: check.category,
          name: check.name,
          status: check.status,
          affectedCount: Number(check.affected_count || 0),
          description: check.description,
          recommendation: check.recommendation,
          examples: check.examples || [],
        })),
      }
      return dataHealth.value
    } catch (healthError) {
      dataHealthError.value = healthError.message || 'Unable to run the data health check.'
      return null
    } finally {
      dataHealthLoading.value = false
    }
  }

  return {
    runningTask: computed(() => (backgroundTask.active.value ? backgroundTask.task.value?.taskName || '' : '')),
    error: backgroundTask.error,
    currentTask: backgroundTask.task,
    lastResult: computed(() => {
      const task = backgroundTask.task.value
      if (task?.status !== 'completed') return null
      const result = task.resultData || {}
      return {
        task: task.taskName,
        success: result.success,
        message: result.message || 'Background task completed',
        data: result.data || {},
        finishedAt: task.finishedAt,
      }
    }),
    overviewLoading: computed(() => overviewLoading.value),
    overviewError: computed(() => overviewError.value),
    dataHealth: computed(() => dataHealth.value),
    dataHealthLoading: computed(() => dataHealthLoading.value),
    dataHealthError: computed(() => dataHealthError.value),
    scheduleImportRange: computed(() => scheduleImportRange.value),
    scheduleDateRange: computed(() => scheduleDateRange.value),
    rosterCoverage: computed(() => rosterCoverage.value),
    mlbTeams: computed(() => mlbTeams.value),
    databaseMetrics: computed(() => databaseMetrics.value),
    playerSeasonStatsMetrics: computed(() => playerSeasonStatsMetrics.value),
    pitchDataMetrics: computed(() => pitchDataMetrics.value),
    gameDetailsMetrics: computed(() => gameDetailsMetrics.value),
    contextualBenchmarkMetrics: computed(() => contextualBenchmarkMetrics.value),
    loadOverview,
    loadLatestTask: backgroundTask.loadLatest,
    cancelCurrentTask: backgroundTask.cancel,
    loadDataHealth,
    runTask,
  }
}
