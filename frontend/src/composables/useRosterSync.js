import { useAdminSyncTask } from './useAdminSyncTask'

const TASK_NAME = 'mlb_roster_sync'

function normalizeEstimate(data) {
  if (!data) return null
  return {
    taskParameters: data.task_parameters || {},
    teamCount: Number(data.team_count || 0),
    estimatedSeconds: Number(data.estimated_seconds || 0),
    lowEstimatedSeconds: Number(data.low_estimated_seconds || 0),
    highEstimatedSeconds: Number(data.high_estimated_seconds || 0),
    secondsPerTeam: Number(data.seconds_per_team || 0),
    timingSampleTeamCount: Number(data.timing_sample_team_count || 0),
    timingSampleRunCount: Number(data.timing_sample_run_count || 0),
    estimateSource: data.estimate_source,
  }
}

const messages = {
  startRequest: (status) => `Roster synchronization request failed (${status}).`,
  start: 'Unable to start roster synchronization.',
  estimateRequest: (status) => `Roster synchronization request failed (${status}).`,
  estimate: 'Unable to estimate roster synchronization.',
  pollRequest: (status) => `Roster synchronization request failed (${status}).`,
  poll: 'Unable to refresh roster synchronization progress.',
  loadRequest: (status) => `Roster synchronization request failed (${status}).`,
  load: 'Unable to recover roster synchronization progress.',
  cancelRequest: (status) => `Roster synchronization request failed (${status}).`,
  cancel: 'Unable to request roster synchronization cancellation.',
}

export function useRosterSync() {
  return useAdminSyncTask({ taskName: TASK_NAME, normalizeEstimate, messages })
}
