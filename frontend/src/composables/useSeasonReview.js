import { computed, ref, watch } from 'vue'
import { API_BASE_URL } from '../config'

const empty = () => ({ season: null, available_seasons: [], games: 0, totals: {}, shutouts: 0, one_run_games: 0, complete_games: 0, fastest_pitches: [], leaders: [], postseason_teams: [], world_series: { teams: [], champion: null }, awards_available: false })

export function useSeasonReview(season) {
  const review = ref(empty())
  const loading = ref(false)
  const error = ref('')
  let requestId = 0

  async function load() {
    const currentRequest = ++requestId
    loading.value = true
    error.value = ''
    try {
      const query = season.value ? `?season=${encodeURIComponent(season.value)}` : ''
      const response = await fetch(`${API_BASE_URL}/api/season_review${query}`, { headers: { Accept: 'application/json' } })
      if (!response.ok) throw new Error(`Request failed with status ${response.status}`)
      const payload = await response.json()
      if (currentRequest === requestId) review.value = payload.data || empty()
    } catch (fetchError) {
      if (currentRequest !== requestId) return
      error.value = 'Unable to load the season review. Confirm the Rails API is running and reachable.'
      console.error(fetchError)
    } finally {
      if (currentRequest === requestId) loading.value = false
    }
  }

  watch(season, load, { immediate: true })
  return { review: computed(() => review.value), loading: computed(() => loading.value), error: computed(() => error.value), refresh: load }
}
