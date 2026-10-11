import { useAdminSyncTask } from './useAdminSyncTask'

const TASK_NAME = 'pitch_data_sync'

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
  startRequest: (status) => `Unable to start pitch synchronization (${status}).`,
  start: 'Unable to start pitch synchronization.',
  estimateRequest: (status) => `Unable to estimate pitch synchronization (${status}).`,
  estimate: 'Unable to estimate pitch synchronization.',
  pollRequest: (status) => `Unable to load pitch synchronization progress (${status}).`,
  poll: 'Unable to refresh pitch synchronization progress.',
  loadRequest: (status) => `Unable to recover pitch synchronization progress (${status}).`,
  load: 'Unable to recover pitch synchronization progress.',
  cancelRequest: (status) => `Unable to cancel pitch synchronization (${status}).`,
  cancel: 'Unable to request pitch synchronization cancellation.',
}

export function usePitchDataSync() {
  return useAdminSyncTask({ taskName: TASK_NAME, normalizeEstimate, messages })
}
