import { ref } from 'vue'

import { adminRequestHeaders } from './apiAuth'
import { API_BASE_URL } from '../config'

export function useGameDetailsAutomation() {
  const enabled = ref(null)
  const intervalMinutes = ref(null)
  const loading = ref(false)
  const saving = ref(false)
  const error = ref('')

  async function request(options = {}) {
    const response = await fetch(`${API_BASE_URL}/api/admin/automation_setting`, options)
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(payload?.message || `Automation setting request failed (${response.status}).`)
    return payload.data
  }

  async function load() {
    loading.value = true
    error.value = ''
    try {
      const data = await request({ headers: adminRequestHeaders({ Accept: 'application/json' }) })
      enabled.value = data.enabled
      intervalMinutes.value = data.interval_minutes
    } catch (caught) {
      error.value = caught.message || 'Unable to load automatic synchronization setting.'
    } finally {
      loading.value = false
    }
  }

  async function update(settings) {
    saving.value = true
    error.value = ''
    try {
      const data = await request({
        method: 'PATCH',
        headers: adminRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
        body: JSON.stringify(settings),
      })
      enabled.value = data.enabled
      intervalMinutes.value = data.interval_minutes
    } catch (caught) {
      error.value = caught.message || 'Unable to update automatic synchronization setting.'
    } finally {
      saving.value = false
    }
  }

  return {
    enabled,
    intervalMinutes,
    loading,
    saving,
    error,
    load,
    setEnabled: (value) => update({ enabled: value }),
    setIntervalMinutes: (value) => update({ interval_minutes: value }),
  }
}
