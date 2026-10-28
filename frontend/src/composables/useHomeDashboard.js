import { computed, onMounted, ref, watch } from 'vue'
import { API_BASE_URL } from '../config'

const CACHE_AGE_MS = 15 * 60 * 1000
const CACHE_PREFIX = 'ninelens-home-v1:'

function todayInDetroit() {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/Detroit', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(new Date())
  const values = Object.fromEntries(parts.map(({ type, value }) => [type, value]))
  return `${values.year}-${values.month}-${values.day}`
}

function cachedDashboard(league) {
  try {
    const cached = JSON.parse(sessionStorage.getItem(`${CACHE_PREFIX}${league}`))
    if (cached && Date.now() - cached.savedAt < CACHE_AGE_MS && cached.data?.as_of === todayInDetroit()) {
      return cached.data
    }
  } catch {
    // Storage may be disabled; loading from the API still works.
  }
  return null
}

function cacheDashboard(league, data) {
  try {
    sessionStorage.setItem(`${CACHE_PREFIX}${league}`, JSON.stringify({ savedAt: Date.now(), data }))
  } catch {
    // A full or disabled session store should not affect the briefing.
  }
}

const emptyDashboard = () => ({
  as_of: null,
  season: null,
  games: [],
  leaders: [],
  team_pulse: {
    best_records: [],
    run_differential: [],
    recent_form: [],
    last_30_form: [],
  },
  freshness: {},
})

export function useHomeDashboard(league = ref('all')) {
  const dashboard = ref(emptyDashboard())
  const loading = ref(true)
  const error = ref('')
  let requestId = 0

  async function load() {
    const currentRequest = ++requestId
    const requestedLeague = league.value
    const cached = cachedDashboard(requestedLeague)
    loading.value = !cached
    error.value = ''
    if (cached) dashboard.value = cached

    try {
      const params = requestedLeague !== 'all' ? `?league=${encodeURIComponent(requestedLeague)}` : ''
      const response = await fetch(`${API_BASE_URL}/api/home${params}`, { headers: { Accept: 'application/json' } })
      if (!response.ok) throw new Error(`Request failed with status ${response.status}`)

      const payload = await response.json()
      if (currentRequest !== requestId) return
      const data = payload.data || {}
      dashboard.value = {
        ...emptyDashboard(),
        ...data,
        team_pulse: { ...emptyDashboard().team_pulse, ...(data.team_pulse || {}) },
      }
      cacheDashboard(requestedLeague, dashboard.value)
    } catch (fetchError) {
      if (currentRequest !== requestId) return
      if (!cached) {
        dashboard.value = emptyDashboard()
        error.value = 'Unable to load today’s NineLens briefing. Confirm the Rails API is running and reachable.'
      }
      console.error(fetchError)
    } finally {
      if (currentRequest === requestId) loading.value = false
    }
  }

  onMounted(load)
  watch(league, load)

  return {
    dashboard: computed(() => dashboard.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    refresh: load,
  }
}
