import { computed, ref, watch } from 'vue'
import { API_BASE_URL } from '../config'

export function useStandings(season) {
  const standings = ref({ season: null, available_seasons: [], as_of: null, season_status: null, leagues: [] })
  const loading = ref(false)
  const error = ref('')
  let requestSequence = 0

  async function load() {
    const requestId = ++requestSequence
    loading.value = true
    error.value = ''
    try {
      const query = season.value ? `?season=${encodeURIComponent(season.value)}` : ''
      const response = await fetch(`${API_BASE_URL}/api/standings${query}`, { headers: { Accept: 'application/json' } })
      if (!response.ok) throw new Error(`Request failed with status ${response.status}`)
      const payload = await response.json()
      if (requestId === requestSequence) standings.value = payload.data || standings.value
    } catch (fetchError) {
      if (requestId !== requestSequence) return
      error.value = 'Unable to load MLB standings. Confirm the Rails API is running and reachable.'
      console.error(fetchError)
    } finally {
      if (requestId === requestSequence) loading.value = false
    }
  }

  watch(season, load, { immediate: true })

  return {
    standings: computed(() => standings.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    refresh: load,
  }
}
