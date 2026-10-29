import { computed, onBeforeUnmount, ref } from 'vue'

import { adminRequestHeaders } from './apiAuth'
import { normalizeAdminTaskRun } from './useBackgroundTaskRun'
import { API_BASE_URL, frontendConfig } from '../config'

const ACTIVE_STATUSES = ['queued', 'running']
const POLL_INTERVAL_MS = frontendConfig.pollingIntervalMs

export function useAdminSyncTask({ taskName, normalizeEstimate, messages }) {
  const task = ref(null)
  const starting = ref(false)
  const estimating = ref(false)
  const requestError = ref('')
  let pollTimer = null

  const active = computed(() => ACTIVE_STATUSES.includes(task.value?.status))
  const error = computed(() => requestError.value || task.value?.errorMessage || '')

  function stopPolling() {
    if (pollTimer) window.clearTimeout(pollTimer)
    pollTimer = null
  }

  function schedulePoll() {
    stopPolling()
    if (!active.value || !task.value?.id) return
    pollTimer = window.setTimeout(poll, POLL_INTERVAL_MS)
  }

  function replaceTask(data) {
    task.value = normalizeAdminTaskRun(data)
    schedulePoll()
    return task.value
  }

  async function request(path, options, fallbackMessage) {
    const response = await fetch(`${API_BASE_URL}${path}`, options)
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) {
      const fallback = typeof fallbackMessage === 'function' ? fallbackMessage(response.status) : fallbackMessage
      throw new Error(payload?.message || fallback)
    }
    return payload
  }

  async function start(parameters) {
    starting.value = true
    requestError.value = ''
    stopPolling()
    try {
      const payload = await request(
        '/api/admin/task_runs',
        {
          method: 'POST',
          headers: adminRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
          body: JSON.stringify({ task_name: taskName, ...parameters }),
        },
        messages.startRequest,
      )
      return replaceTask(payload.data)
    } catch (caught) {
      requestError.value = caught.message || messages.start
      return null
    } finally {
      starting.value = false
    }
  }

  async function estimate(parameters) {
    estimating.value = true
    requestError.value = ''
    try {
      const query = new URLSearchParams(
        Object.entries({ task_name: taskName, ...parameters })
          .filter(([, value]) => value !== null && value !== undefined && value !== ''),
      )
      const payload = await request(
        `/api/admin/task_runs/estimate?${query}`,
        { headers: adminRequestHeaders({ Accept: 'application/json' }) },
        messages.estimateRequest,
      )
      return normalizeEstimate(payload.data)
    } catch (caught) {
      requestError.value = caught.message || messages.estimate
      return null
    } finally {
      estimating.value = false
    }
  }

  async function poll() {
    if (!task.value?.id) return null
    try {
      const payload = await request(
        `/api/admin/task_runs/${encodeURIComponent(task.value.id)}`,
        { headers: adminRequestHeaders({ Accept: 'application/json' }) },
        messages.pollRequest,
      )
      requestError.value = ''
      return replaceTask(payload.data)
    } catch (caught) {
      requestError.value = caught.message || messages.poll
      schedulePoll()
      return null
    }
  }

  async function loadActiveTask() {
    requestError.value = ''
    try {
      const query = new URLSearchParams({ task_name: taskName, active: 'true' })
      const payload = await request(
        `/api/admin/task_runs?${query}`,
        { headers: adminRequestHeaders({ Accept: 'application/json' }) },
        messages.loadRequest,
      )
      const activeTask = payload?.data?.[0]
      return activeTask ? replaceTask(activeTask) : null
    } catch (caught) {
      requestError.value = caught.message || messages.load
      return null
    }
  }

  async function loadLatestTask() {
    requestError.value = ''
    try {
      const query = new URLSearchParams({ task_name: taskName })
      const payload = await request(
        `/api/admin/task_runs?${query}`,
        { headers: adminRequestHeaders({ Accept: 'application/json' }) },
        messages.loadRequest,
      )
      const latestTask = payload?.data?.[0]
      return latestTask ? replaceTask(latestTask) : null
    } catch (caught) {
      requestError.value = caught.message || messages.load
      return null
    }
  }

  async function cancel() {
    if (!task.value?.id || !active.value) return null
    requestError.value = ''
    try {
      const payload = await request(
        `/api/admin/task_runs/${encodeURIComponent(task.value.id)}/cancel`,
        { method: 'POST', headers: adminRequestHeaders({ Accept: 'application/json' }) },
        messages.cancelRequest,
      )
      return replaceTask(payload.data)
    } catch (caught) {
      requestError.value = caught.message || messages.cancel
      schedulePoll()
      return null
    }
  }

  onBeforeUnmount(stopPolling)

  return {
    task: computed(() => task.value),
    active,
    starting: computed(() => starting.value),
    estimating: computed(() => estimating.value),
    error,
    start,
    estimate,
    cancel,
    poll,
    loadActiveTask,
    loadLatestTask,
  }
}
