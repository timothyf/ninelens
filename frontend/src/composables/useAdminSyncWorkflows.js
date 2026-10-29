import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import { useGameDetailsSync } from './useGameDetailsSync'
import { usePitchDataSync } from './usePitchDataSync'
import { useRosterSync } from './useRosterSync'
import {
  formatCount,
  formatDate,
  formatDurationRangeSeconds,
  formatDurationSeconds,
  inclusiveDayCount,
} from '../utils/adminFormatting'
import { gameDetailsRefreshParameters } from '../utils/gameDetailsTaskPresentation'

const FINISHED_STATUSES = ['completed', 'failed', 'cancelled']
const ACTIVE_STATUSES = ['queued', 'running']
const LATEST_GAME_DETAILS_REFRESH_MS = 30_000

export function useAdminSyncWorkflows({
  gameDetailsOptions,
  pitchOptions,
  rosterOptions,
  loadOverview,
  runTask,
  gameDetailsSync = useGameDetailsSync(),
  pitchDataSync = usePitchDataSync(),
  rosterSync = useRosterSync(),
}) {
  const gameDetailsConfirmationOpen = ref(false)
  const gameDetailsSyncCard = ref(null)
  const pendingGameDetailsParameters = ref(null)
  const pendingGameDetailsEstimate = ref(null)
  const pitchDataConfirmationOpen = ref(false)
  const pitchDataSyncCard = ref(null)
  const pendingPitchDataParameters = ref(null)
  const pendingPitchDataEstimate = ref(null)
  const rosterConfirmationOpen = ref(false)
  const rosterSyncCard = ref(null)
  const pendingRosterParameters = ref(null)
  const pendingRosterEstimate = ref(null)

  const gameDetailsEstimate = computed(() => {
    const parameters = pendingGameDetailsParameters.value
    const estimate = pendingGameDetailsEstimate.value
    if (!parameters) return null

    const spanDays = parameters.mlb_game_id ? null : inclusiveDayCount(parameters.start_date, parameters.end_date)
    const historicalTiming = estimate?.estimateSource === 'historical'
    return {
      scope: parameters.mlb_game_id
        ? `MLB game ${parameters.mlb_game_id}`
        : `${spanDays} calendar ${spanDays === 1 ? 'day' : 'days'} · ${formatDate(parameters.start_date)}–${formatDate(parameters.end_date)}`,
      estimatedGames: estimate?.gameCount ?? 0,
      duration: `about ${formatDurationSeconds(estimate?.estimatedSeconds ?? 0)}`,
      range: formatDurationRangeSeconds(estimate?.lowEstimatedSeconds ?? 0, estimate?.highEstimatedSeconds ?? 0),
      assumption: historicalTiming
        ? historicalTimingAssumption(estimate)
        : `Conservative starting estimate: ${formatDurationSeconds(estimate?.secondsPerGame ?? 50)} per stored game. It will improve as completed sync timings are recorded.`,
    }
  })

  const pitchDataEstimate = computed(() => {
    const parameters = pendingPitchDataParameters.value
    const estimate = pendingPitchDataEstimate.value
    if (!parameters) return null

    const spanDays = inclusiveDayCount(parameters.start_date, parameters.end_date)
    const historicalTiming = estimate?.estimateSource === 'historical'
    return {
      scope: `${spanDays} calendar ${spanDays === 1 ? 'day' : 'days'} · ${formatDate(parameters.start_date)}–${formatDate(parameters.end_date)}`,
      estimatedGames: estimate?.gameCount ?? 0,
      duration: `about ${formatDurationSeconds(estimate?.estimatedSeconds ?? 0)}`,
      range: formatDurationRangeSeconds(estimate?.lowEstimatedSeconds ?? 0, estimate?.highEstimatedSeconds ?? 0),
      assumption: historicalTiming
        ? historicalTimingAssumption(estimate)
        : `Conservative starting estimate: ${formatDurationSeconds(estimate?.secondsPerGame ?? 45)} per stored game. It will improve as completed sync timings are recorded.`,
    }
  })

  const rosterEstimate = computed(() => {
    const parameters = pendingRosterParameters.value
    const estimate = pendingRosterEstimate.value
    if (!parameters) return null
    const historical = estimate?.estimateSource === 'historical'
    const scope = parameters.team_scope === 'team' ? `MLB team ${parameters.team_mlb_id}` : parameters.team_scope === 'all' ? 'all MLB teams' : `the ${parameters.team_scope} league`
    return {
      scope: `${scope} for ${parameters.season}`,
      estimatedGames: estimate?.teamCount ?? 0,
      workloadSingular: 'team',
      workloadPlural: 'teams',
      duration: `about ${formatDurationSeconds(estimate?.estimatedSeconds ?? 0)}`,
      range: formatDurationRangeSeconds(estimate?.lowEstimatedSeconds ?? 0, estimate?.highEstimatedSeconds ?? 0),
      assumption: historical
        ? `Based on ${formatCount(estimate.timingSampleTeamCount)} completed teams across ${estimate.timingSampleRunCount} prior roster sync ${estimate.timingSampleRunCount === 1 ? 'run' : 'runs'} (${formatDurationSeconds(estimate.secondsPerTeam)} per team).`
        : `Conservative starting estimate: ${formatDurationSeconds(estimate?.secondsPerTeam ?? 8)} per team. It will improve as completed roster sync timings are recorded.`,
    }
  })

  let latestGameDetailsTimer = null
  onMounted(() => {
    Promise.all([gameDetailsSync.loadLatestTask(), pitchDataSync.loadActiveTask(), rosterSync.loadActiveTask()])
    latestGameDetailsTimer = window.setInterval(() => {
      if (!gameDetailsSync.active.value && !gameDetailsSync.starting.value) gameDetailsSync.loadLatestTask()
    }, LATEST_GAME_DETAILS_REFRESH_MS)
  })
  onBeforeUnmount(() => window.clearInterval(latestGameDetailsTimer))

  watch(
    () => gameDetailsSync.task.value?.status,
    (status, previousStatus) => refreshOverviewAfterCompletion(status, previousStatus, loadOverview),
  )

  watch(
    () => rosterSync.task.value?.status,
    (status, previousStatus) => refreshOverviewAfterCompletion(status, previousStatus, loadOverview),
  )

  watch(
    () => pitchDataSync.task.value?.status,
    (status, previousStatus) => refreshOverviewAfterCompletion(status, previousStatus, loadOverview),
  )

  async function requestPitchDataSync() {
    normalizeDateRange(pitchOptions)
    const parameters = {
      start_date: pitchOptions.startDate,
      end_date: pitchOptions.endDate,
      game_types: pitchOptions.gameTypes,
      chunk_days: pitchOptions.chunkDays,
      replace_existing: pitchOptions.replaceExisting,
    }
    const estimate = await pitchDataSync.estimate(parameters)
    if (!estimate) return

    pendingPitchDataParameters.value = parameters
    pendingPitchDataEstimate.value = estimate
    pitchDataConfirmationOpen.value = true
  }

  async function cancelPitchDataSync() {
    pitchDataConfirmationOpen.value = false
    pendingPitchDataParameters.value = null
    pendingPitchDataEstimate.value = null
    await nextTick()
    pitchDataSyncCard.value?.focusSyncButton()
  }

  async function confirmPitchDataSync() {
    const parameters = pendingPitchDataParameters.value
    if (!parameters) return

    pitchDataConfirmationOpen.value = false
    pendingPitchDataParameters.value = null
    pendingPitchDataEstimate.value = null
    await pitchDataSync.start(parameters)
  }

  async function requestGameDetailsSync() {
    normalizeDateRange(gameDetailsOptions)
    const parameters = {
      start_date: gameDetailsOptions.mlbGameId ? null : gameDetailsOptions.startDate,
      end_date: gameDetailsOptions.mlbGameId ? null : gameDetailsOptions.endDate,
      mlb_game_id: gameDetailsOptions.mlbGameId || null,
    }
    const estimate = await gameDetailsSync.estimate(parameters)
    if (!estimate) return

    pendingGameDetailsParameters.value = parameters
    pendingGameDetailsEstimate.value = estimate
    gameDetailsConfirmationOpen.value = true
  }

  async function cancelGameDetailsSync() {
    gameDetailsConfirmationOpen.value = false
    pendingGameDetailsParameters.value = null
    pendingGameDetailsEstimate.value = null
    await nextTick()
    gameDetailsSyncCard.value?.focusSyncButton()
  }

  async function confirmGameDetailsSync() {
    const parameters = pendingGameDetailsParameters.value
    if (!parameters) return

    gameDetailsConfirmationOpen.value = false
    pendingGameDetailsParameters.value = null
    pendingGameDetailsEstimate.value = null
    await gameDetailsSync.start(parameters)
  }

  async function refreshGameDetailsAnalytics() {
    const parameters = gameDetailsRefreshParameters(gameDetailsSync.task.value)
    if (!parameters) return

    const result = await runTask('daily_analytics_refresh', parameters)
    if (result) {
      await loadOverview()
      await gameDetailsSync.loadLatestTask()
    }
  }

  async function requestRosterSync() {
    const parameters = { team_scope: rosterOptions.teamScope, team_mlb_id: rosterOptions.teamScope === 'team' ? rosterOptions.teamMlbId : null, season: rosterOptions.season }
    const estimate = await rosterSync.estimate(parameters)
    if (!estimate) return
    pendingRosterParameters.value = parameters
    pendingRosterEstimate.value = estimate
    rosterConfirmationOpen.value = true
  }

  async function cancelRosterSync() {
    rosterConfirmationOpen.value = false
    pendingRosterParameters.value = null
    pendingRosterEstimate.value = null
    await nextTick()
    rosterSyncCard.value?.focusSyncButton()
  }

  async function confirmRosterSync() {
    const parameters = pendingRosterParameters.value
    if (!parameters) return
    rosterConfirmationOpen.value = false
    pendingRosterParameters.value = null
    pendingRosterEstimate.value = null
    await rosterSync.start(parameters)
  }

  return {
    gameDetailsConfirmationOpen,
    gameDetailsSyncCard,
    gameDetailsEstimate,
    gameDetailsTask: gameDetailsSync.task,
    gameDetailsSyncActive: gameDetailsSync.active,
    gameDetailsSyncStarting: gameDetailsSync.starting,
    gameDetailsSyncEstimating: gameDetailsSync.estimating,
    gameDetailsSyncError: gameDetailsSync.error,
    cancelActiveGameDetailsSync: gameDetailsSync.cancel,
    requestGameDetailsSync,
    cancelGameDetailsSync,
    confirmGameDetailsSync,
    refreshGameDetailsAnalytics,
    pitchDataConfirmationOpen,
    pitchDataSyncCard,
    pitchDataEstimate,
    pitchDataTask: pitchDataSync.task,
    pitchDataSyncActive: pitchDataSync.active,
    pitchDataSyncStarting: pitchDataSync.starting,
    pitchDataSyncEstimating: pitchDataSync.estimating,
    pitchDataSyncError: pitchDataSync.error,
    cancelActivePitchDataSync: pitchDataSync.cancel,
    requestPitchDataSync,
    cancelPitchDataSync,
    confirmPitchDataSync,
    rosterConfirmationOpen,
    rosterSyncCard,
    rosterEstimate,
    rosterTask: rosterSync.task,
    rosterSyncActive: rosterSync.active,
    rosterSyncStarting: rosterSync.starting,
    rosterSyncEstimating: rosterSync.estimating,
    rosterSyncError: rosterSync.error,
    cancelActiveRosterSync: rosterSync.cancel,
    requestRosterSync,
    cancelRosterSync,
    confirmRosterSync,
  }
}

function refreshOverviewAfterCompletion(status, previousStatus, loadOverview) {
  if (FINISHED_STATUSES.includes(status) && ACTIVE_STATUSES.includes(previousStatus)) loadOverview()
}

function normalizeDateRange(options) {
  if (options.startDate && options.endDate && options.startDate > options.endDate) options.endDate = options.startDate
}

function historicalTimingAssumption(estimate) {
  return `Based on ${formatCount(estimate.timingSampleGameCount)} completed game${estimate.timingSampleGameCount === 1 ? '' : 's'} across ${estimate.timingSampleRunCount} prior sync ${estimate.timingSampleRunCount === 1 ? 'run' : 'runs'} (${formatDurationSeconds(estimate.secondsPerGame)} per game).`
}
