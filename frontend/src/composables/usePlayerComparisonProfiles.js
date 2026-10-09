import { computed, ref, watch } from 'vue'
import { API_BASE_URL } from '../config'
import { normalizeProfile } from './usePlayerProfile'

export function usePlayerComparisonProfiles(playerIdsRef, { requestParams = {} } = {}) {
  const players = ref([])
  const loading = ref(false)
  const error = ref('')
  let requestCounter = 0
  let lastRequestedKey = ''

  async function load() {
    const playerIds = playerIdsRef.value.filter(Boolean).map(String)
    const requestKey = playerIds.join(',')
    if (requestKey === lastRequestedKey) return
    lastRequestedKey = requestKey
    const requestId = requestCounter + 1
    requestCounter = requestId

    if (playerIds.length < 2) {
      players.value = []
      loading.value = false
      error.value = ''
      return
    }

    loading.value = true
    error.value = ''
    const params = new URLSearchParams({ ids: playerIds.join(','), sections: 'core,advanced_stats,defensive_stats', ...requestParams })

    try {
      const response = await fetch(`${API_BASE_URL}/api/players/compare?${params}`, {
        headers: { Accept: 'application/json' },
      })
      if (!response.ok) {
        const payload = typeof response.json === 'function' ? await response.json().catch(() => ({})) : {}
        throw new Error(payload?.message || `Request failed with status ${response.status}`)
      }

      const payload = await response.json()
      if (requestId !== requestCounter) return
      players.value = (payload.data || []).map(normalizeProfile)
    } catch (fetchError) {
      if (requestId !== requestCounter) return
      players.value = []
      error.value = fetchError.message || 'Unable to load comparison data.'
    } finally {
      if (requestId === requestCounter) loading.value = false
    }
  }

  watch(playerIdsRef, load, { immediate: true, deep: true })

  return {
    players: computed(() => players.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    refresh: load,
  }
}
