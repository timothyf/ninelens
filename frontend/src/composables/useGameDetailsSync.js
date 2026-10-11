import { useAdminSyncTask } from './useAdminSyncTask'

const TASK_NAME = 'mlb_game_details_sync'

function normalizeEstimate(data) {
  if (!data) return null
  return {
    taskParameters: data.task_parameters || {},
    gameCount: Number(data.game_count || 0),
    estimatedSeconds: Number(data.estimated_seconds || 0),
    lowEstimatedSeconds: Number(data.low_estimated_seconds || 0),
    highEstimatedSeconds: Number(data.high_estimated_seconds || 0),
    secondsPerGame: Number(data.seconds_per_game || 0),
    timingSampleGameCount: Number(data.timing_sample_game_count || 0),
    timingSampleRunCount: Number(data.timing_sample_run_count || 0),
    estimateSource: data.estimate_source,
  }
}

const messages = {
  startRequest: (status) => `Unable to start game synchronization (${status}).`,
  start: 'Unable to start game synchronization.',
  estimateRequest: (status) => `Unable to estimate game synchronization (${status}).`,
  estimate: 'Unable to estimate game synchronization.',
  pollRequest: (status) => `Unable to load synchronization progress (${status}).`,
  poll: 'Unable to refresh synchronization progress.',
  loadRequest: (status) => `Unable to recover synchronization progress (${status}).`,
  load: 'Unable to recover synchronization progress.',
  cancelRequest: (status) => `Unable to cancel synchronization (${status}).`,
  cancel: 'Unable to request cancellation.',
}

export function useGameDetailsSync() {
  return useAdminSyncTask({ taskName: TASK_NAME, normalizeEstimate, messages })
}
