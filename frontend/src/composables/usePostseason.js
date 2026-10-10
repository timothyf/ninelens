import { computed, ref } from 'vue'
import { API_BASE_URL } from '../config'

const emptySnapshot = () => ({ active: false, season: null, available_seasons: [], playoff_teams: [], game_results: [], upcoming_games: [], rounds: [], leaders: { batting: [], pitching: [] } })

export function usePostseason() {
  const postseason = ref(emptySnapshot())
  const loading = ref(false)
  const error = ref('')

  async function load() {
    loading.value = true
    error.value = ''
    try {
      const response = await fetch(`${API_BASE_URL}/api/postseason`, { headers: { Accept: 'application/json' } })
      if (!response.ok) throw new Error(`Request failed with status ${response.status}`)
      const payload = await response.json()
      postseason.value = payload.data || emptySnapshot()
    } catch (fetchError) {
      error.value = 'Unable to load postseason data.'
      console.error(fetchError)
    } finally {
      loading.value = false
    }
  }

  return { postseason: computed(() => postseason.value), loading: computed(() => loading.value), error: computed(() => error.value), load }
}
