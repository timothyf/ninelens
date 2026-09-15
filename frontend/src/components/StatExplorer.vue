<script setup>
import { computed, reactive, ref, watch } from 'vue'

import PitchDataTable from './PitchDataTable.vue'
import PlayerSeasonStatsTable from './PlayerSeasonStatsTable.vue'
import SavedAnalysisControls from './SavedAnalysisControls.vue'
import { usePlayerSuggestions } from '../composables/usePlayerSuggestions'
import { usePitchData } from '../composables/usePitchData'
import { usePlayerSeasonStats } from '../composables/usePlayerSeasonStats'
import { frontendConfig } from '../config'

const DEFAULT_SORT_BY_CATEGORY = {
  batting: '-homeRuns',
  pitching: '-strikeOuts',
  pitchStats: '-pitch_usage',
}
const DEFAULT_PITCH_DATA_PER_PAGE = frontendConfig.defaultPitchDataPerPage
const FILTER_URL_CATEGORIES = new Set(['batting', 'pitching', 'pitchData'])

const filters = reactive({
  playerName: '',
  teamId: '',
  positionId: '',
  league: '',
  seasonStart: '',
  seasonEnd: '',
  category: 'batting',
})

const pagination = reactive({
  page: 1,
  perPage: frontendConfig.defaultStatsPerPage,
})

const pitchDataOptions = reactive({
  page: 1,
  perPage: DEFAULT_PITCH_DATA_PER_PAGE,
})

const pitchDataFilters = reactive({
  gameDateStart: '',
  gameDateEnd: '',
  gamePk: '',
  pitcher: '',
  batter: '',
  pitchType: '',
  events: '',
})

const sort = reactive({
  value: DEFAULT_SORT_BY_CATEGORY.batting,
})

const savedAnalysisState = computed(() => ({
  category: filters.category,
  filters: { ...filters },
  pitchDataFilters: { ...pitchDataFilters },
  pagination: { ...pagination },
  pitchDataOptions: { ...pitchDataOptions },
  sort: sort.value,
}))
const savedAnalysisUrl = computed(() => {
  void savedAnalysisState.value
  if (typeof window === 'undefined') return '/explore'
  return `${window.location.pathname}${window.location.search}${window.location.hash}`
})

const playerInputFocused = ref(false)
const pitcherInputFocused = ref(false)
const batterInputFocused = ref(false)
const pitcherNameInput = ref('')
const batterNameInput = ref('')
let playerSuggestionBlurTimer = null
let pitcherSuggestionBlurTimer = null
let batterSuggestionBlurTimer = null

applyUrlState()

const query = computed(() => ({
  view: 'leaderboard',
  page: pagination.page,
  perPage: pagination.perPage,
  sort: sort.value,
  filters: {
    player_name: filters.playerName,
    team_id: filters.teamId,
    position_id: filters.positionId,
    league: filters.league,
    season_start: filters.seasonStart,
    season_end: filters.seasonEnd,
    category: filters.category,
  },
}))

const playerSuggestionQuery = computed(() => ({
  name: filters.playerName,
  teamId: filters.teamId,
  perPage: frontendConfig.playerSuggestionLimit,
}))

const pitcherSuggestionQuery = computed(() => ({
  name: pitcherNameInput.value,
  perPage: frontendConfig.playerSuggestionLimit,
}))

const batterSuggestionQuery = computed(() => ({
  name: batterNameInput.value,
  perPage: frontendConfig.playerSuggestionLimit,
}))

const pitchDataQuery = computed(() => ({
  page: pitchDataOptions.page,
  perPage: pitchDataOptions.perPage,
  gameDateStart: pitchDataFilters.gameDateStart,
  gameDateEnd: pitchDataFilters.gameDateEnd,
  gamePk: pitchDataFilters.gamePk,
  pitcher: pitchDataFilters.pitcher,
  batter: pitchDataFilters.batter,
  pitchType: pitchDataFilters.pitchType,
  events: pitchDataFilters.events,
}))
const pitchDataEnabled = computed(() => filters.category === 'pitchData')

const { rows, meta, loading, error, refresh } = usePlayerSeasonStats(query)
const {
  rows: pitchRows,
  meta: pitchMeta,
  loading: pitchLoading,
  error: pitchError,
  refresh: refreshPitchData,
} = usePitchData(pitchDataQuery, pitchDataEnabled)
const { suggestions: playerSuggestions, loading: playerSuggestionsLoading } = usePlayerSuggestions(playerSuggestionQuery)
const { suggestions: pitcherSuggestions, loading: pitcherSuggestionsLoading } = usePlayerSuggestions(pitcherSuggestionQuery)
const { suggestions: batterSuggestions, loading: batterSuggestionsLoading } = usePlayerSuggestions(batterSuggestionQuery)
watch(
  () => [
    filters.category,
    filters.playerName,
    filters.teamId,
    filters.positionId,
    filters.league,
    filters.seasonStart,
    filters.seasonEnd,
    pagination.page,
    pagination.perPage,
    sort.value,
    pitchDataOptions.page,
    pitchDataOptions.perPage,
    pitchDataFilters.gameDateStart,
    pitchDataFilters.gameDateEnd,
    pitchDataFilters.gamePk,
    pitchDataFilters.pitcher,
    pitchDataFilters.batter,
    pitcherNameInput.value,
    batterNameInput.value,
    pitchDataFilters.pitchType,
    pitchDataFilters.events,
  ],
  () => {
    syncUrlState()
  },
  { immediate: true },
)

watch(
  () => [filters.playerName, filters.teamId, filters.positionId, filters.league, filters.seasonStart, filters.seasonEnd, filters.category, pagination.perPage, sort.value],
  () => {
    pagination.page = 1
  },
)

watch(
  () => [filters.seasonStart, filters.seasonEnd],
  ([seasonStart, seasonEnd]) => {
    const startYear = Number(seasonStart)
    const endYear = Number(seasonEnd)
    if (startYear && endYear && startYear > endYear) {
      filters.seasonEnd = filters.seasonStart
    }
  },
)

watch(
  () => [pitchDataFilters.gameDateStart, pitchDataFilters.gameDateEnd],
  ([gameDateStart, gameDateEnd]) => {
    if (gameDateStart && gameDateEnd && gameDateStart > gameDateEnd) {
      pitchDataFilters.gameDateEnd = pitchDataFilters.gameDateStart
    }
  },
)

watch(
  () => [
    pitchDataFilters.gameDateStart,
    pitchDataFilters.gameDateEnd,
    pitchDataFilters.gamePk,
    pitchDataFilters.pitcher,
    pitchDataFilters.batter,
    pitchDataFilters.pitchType,
    pitchDataFilters.events,
    pitchDataOptions.perPage,
  ],
  () => {
    pitchDataOptions.page = 1
  },
)

watch(
  () => filters.category,
  (category) => {
    sort.value = DEFAULT_SORT_BY_CATEGORY[category] || DEFAULT_SORT_BY_CATEGORY.batting
    filters.seasonStart = ''
    filters.seasonEnd = ''
    pagination.page = 1
    if (category === 'pitchData') {
      pitchDataOptions.page = 1
    }
  },
)

watch(
  () => meta.value.availableTeams,
  (availableTeams) => {
    if (!filters.teamId) return

    const teamStillAvailable = availableTeams.some((team) => String(team.id) === String(filters.teamId))
    if (!teamStillAvailable) {
      filters.teamId = ''
    }
  },
  { deep: true },
)

watch(
  () => meta.value.availablePositions,
  (availablePositions) => {
    if (!filters.positionId) return

    if (!(availablePositions || []).some((position) => String(position.id) === String(filters.positionId))) {
      filters.positionId = ''
    }
  },
  { deep: true },
)

const selectedTeam = computed(() =>
  meta.value.availableTeams.find((team) => String(team.id) === String(filters.teamId)) || null,
)
const selectedPosition = computed(() =>
  (meta.value.availablePositions || []).find((position) => String(position.id) === String(filters.positionId)) || null,
)

const pitchTypeOptions = computed(() => {
  const values = new Set(
    (pitchMeta.value.availablePitchTypes || [])
      .concat(
        pitchRows.value
          .map((row) => String(row.pitchType || '').trim())
          .filter(Boolean),
      ),
  )

  if (pitchDataFilters.pitchType) values.add(pitchDataFilters.pitchType)

  return Array.from(values).sort((left, right) => left.localeCompare(right))
})

const pitchEventOptions = computed(() => {
  const values = new Set(
    (pitchMeta.value.availableEvents || [])
      .concat(
        pitchRows.value
          .map((row) => String(row.events || '').trim())
          .filter(Boolean),
      ),
  )

  if (pitchDataFilters.events) values.add(pitchDataFilters.events)

  return Array.from(values).sort((left, right) => left.localeCompare(right))
})

const showPlayerSuggestions = computed(
  () =>
    playerInputFocused.value &&
    filters.playerName.trim().length >= 2 &&
    (playerSuggestionsLoading.value || playerSuggestions.value.length > 0),
)

const showPitcherSuggestions = computed(
  () =>
    pitcherInputFocused.value &&
    pitcherNameInput.value.trim().length >= 2 &&
    (pitcherSuggestionsLoading.value || pitcherSuggestions.value.length > 0),
)

const showBatterSuggestions = computed(
  () =>
    batterInputFocused.value &&
    batterNameInput.value.trim().length >= 2 &&
    (batterSuggestionsLoading.value || batterSuggestions.value.length > 0),
)

const tableTitle = computed(() => {
  if (filters.category === 'pitchData') {
    return 'Pitch Data Feed'
  }

  if (filters.category === 'pitching' || filters.category === 'pitchStats') {
    return 'Pitching Leaderboard'
  }

  return 'Batting Leaderboard'
})

const filterSummary = computed(() => {
  if (filters.category === 'pitchData') {
    const gameDateRangeLabel =
      pitchDataFilters.gameDateStart && pitchDataFilters.gameDateEnd
        ? `Game Dates: ${pitchDataFilters.gameDateStart} to ${pitchDataFilters.gameDateEnd}`
        : pitchDataFilters.gameDateStart
          ? `Game Date from: ${pitchDataFilters.gameDateStart}`
          : pitchDataFilters.gameDateEnd
            ? `Game Date through: ${pitchDataFilters.gameDateEnd}`
            : null

    const pitchFilters = [
      gameDateRangeLabel,
      pitchDataFilters.gamePk && `Game PK: ${pitchDataFilters.gamePk}`,
      (pitcherNameInput.value || pitchDataFilters.pitcher) && `Pitcher: ${pitcherNameInput.value || pitchDataFilters.pitcher}`,
      (batterNameInput.value || pitchDataFilters.batter) && `Batter: ${batterNameInput.value || pitchDataFilters.batter}`,
      pitchDataFilters.pitchType && `Pitch Type: ${pitchDataFilters.pitchType}`,
      pitchDataFilters.events && `Events: ${pitchDataFilters.events}`,
    ].filter(Boolean)

    return pitchFilters.length
      ? `${pitchFilters.join(' · ')} · Showing latest imported pitch rows (${pitchDataOptions.perPage} per page).`
      : `Showing latest imported pitch rows (${pitchDataOptions.perPage} per page).`
  }

  const seasonRangeLabel =
    filters.seasonStart && filters.seasonEnd
      ? `Seasons: ${filters.seasonStart}-${filters.seasonEnd}`
      : filters.seasonStart
        ? `Season from: ${filters.seasonStart}`
        : filters.seasonEnd
          ? `Season through: ${filters.seasonEnd}`
          : null

  const activeFilters = [
    filters.playerName && `Player: ${filters.playerName}`,
    selectedTeam.value &&
      `Team: ${selectedTeam.value.abbreviation || selectedTeam.value.short_name || selectedTeam.value.team_name || selectedTeam.value.name}`,
    filters.league === 'american' && 'League: American League',
    filters.league === 'national' && 'League: National League',
    selectedPosition.value && `Position: ${selectedPosition.value.abbreviation || selectedPosition.value.name}`,
    seasonRangeLabel,
    filters.category && `Category: ${filters.category}`,
  ].filter(Boolean)

  return activeFilters.length ? activeFilters.join(' · ') : 'Showing the full player season leaderboard.'
})

function applyUrlState() {
  if (typeof window === 'undefined') return

  const searchParams = new URLSearchParams(window.location.search)
  const category = searchParams.get('category')

  if (FILTER_URL_CATEGORIES.has(category)) {
    filters.category = category
  }

  const sortParam = searchParams.get('sort')
  sort.value = sortParam || DEFAULT_SORT_BY_CATEGORY[filters.category] || DEFAULT_SORT_BY_CATEGORY.batting

  pagination.page = positiveInteger(searchParams.get('page'), pagination.page)
  pagination.perPage = positiveInteger(searchParams.get('per_page'), pagination.perPage)
  pitchDataOptions.page = positiveInteger(searchParams.get('pitch_page'), pitchDataOptions.page)
  pitchDataOptions.perPage = positiveInteger(searchParams.get('pitch_per_page'), pitchDataOptions.perPage)

  filters.playerName = searchParams.get('player') || filters.playerName
  filters.teamId = searchParams.get('team') || filters.teamId
  filters.positionId = searchParams.get('position') || filters.positionId
  filters.league = ['american', 'national'].includes(searchParams.get('league')) ? searchParams.get('league') : filters.league
  filters.seasonStart = searchParams.get('season_start') || filters.seasonStart
  filters.seasonEnd = searchParams.get('season_end') || filters.seasonEnd

  pitchDataFilters.gameDateStart = searchParams.get('game_date_start') || pitchDataFilters.gameDateStart
  pitchDataFilters.gameDateEnd = searchParams.get('game_date_end') || pitchDataFilters.gameDateEnd
  pitchDataFilters.gamePk = searchParams.get('game_pk') || pitchDataFilters.gamePk
  pitchDataFilters.pitcher = searchParams.get('pitcher') || pitchDataFilters.pitcher
  pitchDataFilters.batter = searchParams.get('batter') || pitchDataFilters.batter
  pitcherNameInput.value = searchParams.get('pitcher_name') || pitcherNameInput.value
  batterNameInput.value = searchParams.get('batter_name') || batterNameInput.value
  pitchDataFilters.pitchType = searchParams.get('pitch_type') || pitchDataFilters.pitchType
  pitchDataFilters.events = searchParams.get('events') || pitchDataFilters.events
}

function syncUrlState() {
  if (typeof window === 'undefined') return

  const searchParams = new URLSearchParams()
  const defaultSort = DEFAULT_SORT_BY_CATEGORY[filters.category] || DEFAULT_SORT_BY_CATEGORY.batting

  setSearchParam(searchParams, 'category', filters.category === 'batting' ? '' : filters.category)

  if (filters.category === 'pitchData') {
    setSearchParam(searchParams, 'pitch_page', pitchDataOptions.page === 1 ? '' : pitchDataOptions.page)
    setSearchParam(searchParams, 'pitch_per_page', pitchDataOptions.perPage === DEFAULT_PITCH_DATA_PER_PAGE ? '' : pitchDataOptions.perPage)
    setSearchParam(searchParams, 'game_date_start', pitchDataFilters.gameDateStart)
    setSearchParam(searchParams, 'game_date_end', pitchDataFilters.gameDateEnd)
    setSearchParam(searchParams, 'game_pk', pitchDataFilters.gamePk)
    setSearchParam(searchParams, 'pitcher', pitchDataFilters.pitcher)
    setSearchParam(searchParams, 'pitcher_name', pitcherNameInput.value)
    setSearchParam(searchParams, 'batter', pitchDataFilters.batter)
    setSearchParam(searchParams, 'batter_name', batterNameInput.value)
    setSearchParam(searchParams, 'pitch_type', pitchDataFilters.pitchType)
    setSearchParam(searchParams, 'events', pitchDataFilters.events)
  } else {
    setSearchParam(searchParams, 'player', filters.playerName)
    setSearchParam(searchParams, 'team', filters.teamId)
    setSearchParam(searchParams, 'position', filters.positionId)
    setSearchParam(searchParams, 'league', filters.league)
    setSearchParam(searchParams, 'season_start', filters.seasonStart)
    setSearchParam(searchParams, 'season_end', filters.seasonEnd)
    setSearchParam(searchParams, 'page', pagination.page === 1 ? '' : pagination.page)
    setSearchParam(searchParams, 'per_page', pagination.perPage === frontendConfig.defaultStatsPerPage ? '' : pagination.perPage)
    setSearchParam(searchParams, 'sort', sort.value === defaultSort ? '' : sort.value)
  }

  const nextQuery = searchParams.toString()
  const nextUrl = `${window.location.pathname}${nextQuery ? `?${nextQuery}` : ''}${window.location.hash}`
  const currentUrl = `${window.location.pathname}${window.location.search}${window.location.hash}`

  if (nextUrl !== currentUrl) {
    window.history.replaceState(window.history.state, '', nextUrl)
  }
}

function setSearchParam(searchParams, key, value) {
  if (value === '' || value === null || value === undefined) return

  searchParams.set(key, String(value))
}

function positiveInteger(value, fallback) {
  const integer = Number(value)
  return Number.isInteger(integer) && integer > 0 ? integer : fallback
}

function updateSort(nextSort) {
  sort.value = nextSort
}

function openSavedAnalysis(item) {
  if (typeof window !== 'undefined') window.location.assign(item.reproducibleUrl)
}

function updatePage(nextPage) {
  pagination.page = nextPage
}

function updatePerPage(event) {
  pagination.perPage = Number(event.target.value)
}

function updatePitchPerPage(event) {
  pitchDataOptions.perPage = Number(event.target.value)
}

function updatePitchPage(nextPage) {
  pitchDataOptions.page = nextPage
}

function handlePlayerInputFocus() {
  if (playerSuggestionBlurTimer) {
    window.clearTimeout(playerSuggestionBlurTimer)
    playerSuggestionBlurTimer = null
  }

  playerInputFocused.value = true
}

function handlePlayerInputBlur() {
  playerSuggestionBlurTimer = window.setTimeout(() => {
    playerInputFocused.value = false
    playerSuggestionBlurTimer = null
  }, 120)
}

function applyPlayerSuggestion(player) {
  if (playerSuggestionBlurTimer) {
    window.clearTimeout(playerSuggestionBlurTimer)
    playerSuggestionBlurTimer = null
  }

  filters.playerName = player.fullName
  playerInputFocused.value = false
}

function handlePitcherInputFocus() {
  if (pitcherSuggestionBlurTimer) {
    window.clearTimeout(pitcherSuggestionBlurTimer)
    pitcherSuggestionBlurTimer = null
  }

  // Start a fresh search when users return to this field after a prior selection.
  if (pitchDataFilters.pitcher) {
    pitchDataFilters.pitcher = ''
    pitcherNameInput.value = ''
  }

  pitcherInputFocused.value = true
}

function handlePitcherInputBlur() {
  pitcherSuggestionBlurTimer = window.setTimeout(() => {
    pitcherInputFocused.value = false
    pitcherSuggestionBlurTimer = null
  }, 120)
}

function applyPitcherSuggestion(player) {
  if (pitcherSuggestionBlurTimer) {
    window.clearTimeout(pitcherSuggestionBlurTimer)
    pitcherSuggestionBlurTimer = null
  }
  pitcherNameInput.value = player.fullName
  pitchDataFilters.pitcher = String(player.mlbId || player.id)
  pitcherInputFocused.value = false
}

function handlePitcherNameInput() {
  pitchDataFilters.pitcher = ''
}

function handleBatterInputFocus() {
  if (batterSuggestionBlurTimer) {
    window.clearTimeout(batterSuggestionBlurTimer)
    batterSuggestionBlurTimer = null
  }

  // Start a fresh search when users return to this field after a prior selection.
  if (pitchDataFilters.batter) {
    pitchDataFilters.batter = ''
    batterNameInput.value = ''
  }

  batterInputFocused.value = true
}

function handleBatterInputBlur() {
  batterSuggestionBlurTimer = window.setTimeout(() => {
    batterInputFocused.value = false
    batterSuggestionBlurTimer = null
  }, 120)
}

function applyBatterSuggestion(player) {
  if (batterSuggestionBlurTimer) {
    window.clearTimeout(batterSuggestionBlurTimer)
    batterSuggestionBlurTimer = null
  }
  batterNameInput.value = player.fullName
  pitchDataFilters.batter = String(player.mlbId || player.id)
  batterInputFocused.value = false
}

function handleBatterNameInput() {
  pitchDataFilters.batter = ''
}

function resetFilters() {
  const activeCategory = filters.category

  filters.playerName = ''
  filters.teamId = ''
  filters.positionId = ''
  filters.league = ''
  filters.seasonStart = ''
  filters.seasonEnd = ''
  pagination.page = 1
  pitchDataOptions.page = 1
  pitchDataOptions.perPage = DEFAULT_PITCH_DATA_PER_PAGE
  pitchDataFilters.gameDateStart = ''
  pitchDataFilters.gameDateEnd = ''
  pitchDataFilters.gamePk = ''
  pitchDataFilters.pitcher = ''
  pitchDataFilters.batter = ''
  pitcherNameInput.value = ''
  batterNameInput.value = ''
  pitchDataFilters.pitchType = ''
  pitchDataFilters.events = ''
  sort.value = DEFAULT_SORT_BY_CATEGORY[activeCategory] || DEFAULT_SORT_BY_CATEGORY.batting
}

</script>

<template>
  <main class="dashboard-shell">
    <section class="hero-panel">
      <div class="hero-copy">
        <p class="eyebrow">Front Office Dashboard</p>
        <h1>Stat Explorer</h1>
        <p class="lede">
          Search, sort, and compare player season statistics and pitch-level data.
        </p>
      </div>
    </section>

    <SavedAnalysisControls
      analysis-type="stat_explorer"
      :state="savedAnalysisState"
      :reproducible-url="savedAnalysisUrl"
      @apply="openSavedAnalysis"
    />

    <section class="control-deck">
      <div class="control-deck__header">
        <div>
          <h2>Filters</h2>
          <p>{{ filterSummary }}</p>
        </div>
        <button class="ghost-button" type="button" @click="resetFilters">Reset Filters</button>
      </div>

      <div class="filter-grid">
        <label class="field">
          <span>Category</span>
          <select v-model="filters.category">
            <option value="batting">Batting</option>
            <option value="pitching">Pitching</option>
            <option value="pitchData">Pitch Data</option>
          </select>
        </label>

        <label v-if="filters.category !== 'pitchData'" class="field">
          <span>Player</span>
          <div class="typeahead-field">
            <input
              v-model="filters.playerName"
              type="text"
              placeholder="Ohtani, Cabrera, Trout..."
              autocomplete="off"
              @focus="handlePlayerInputFocus"
              @blur="handlePlayerInputBlur"
            />

            <div v-if="showPlayerSuggestions" class="typeahead-menu" role="listbox" aria-label="Player suggestions">
              <p v-if="playerSuggestionsLoading" class="typeahead-status">
                Looking up players…
              </p>

              <button
                v-for="player in playerSuggestions"
                v-else
                :key="player.id"
                type="button"
                class="typeahead-option"
                @mousedown.prevent="applyPlayerSuggestion(player)"
              >
                <span class="typeahead-option__name">{{ player.fullName }}</span>
                <span class="typeahead-option__meta">
                  {{ player.team.abbreviation || player.team.team_name || player.team.name }}
                </span>
              </button>
            </div>
          </div>
        </label>

        <label v-if="filters.category !== 'pitchData'" class="field">
          <span>Team</span>
          <select v-model="filters.teamId" data-test="team-filter">
            <option value="">All teams</option>
            <option v-for="teamOption in meta.availableTeams" :key="teamOption.id" :value="String(teamOption.id)">
              {{ teamOption.abbreviation }} · {{ teamOption.short_name || teamOption.team_name || teamOption.name }}
            </option>
          </select>
        </label>

        <label v-if="filters.category !== 'pitchData'" class="field">
          <span>Position</span>
          <select v-model="filters.positionId" data-test="position-filter">
            <option value="">All positions</option>
            <option v-for="positionOption in meta.availablePositions" :key="positionOption.id" :value="String(positionOption.id)">
              {{ positionOption.abbreviation }} · {{ positionOption.name }}
            </option>
          </select>
        </label>

        <label v-if="filters.category !== 'pitchData'" class="field">
          <span>League</span>
          <select v-model="filters.league" data-test="league-filter">
            <option value="">All MLB</option>
            <option value="american">American League</option>
            <option value="national">National League</option>
          </select>
        </label>

        <label v-if="filters.category !== 'pitchData'" class="field">
          <span>Season Start</span>
          <select v-model="filters.seasonStart" data-test="season-start-filter">
            <option value="">Any</option>
            <option v-for="seasonOption in meta.availableSeasons" :key="`start-${seasonOption}`" :value="seasonOption">
              {{ seasonOption }}
            </option>
          </select>
        </label>

        <label v-if="filters.category !== 'pitchData'" class="field">
          <span>Season End</span>
          <select v-model="filters.seasonEnd" data-test="season-end-filter">
            <option value="">Any</option>
            <option v-for="seasonOption in meta.availableSeasons" :key="seasonOption" :value="seasonOption">
              {{ seasonOption }}
            </option>
          </select>
        </label>

        <label v-if="filters.category !== 'pitchData'" class="field">
          <span>Rows per page</span>
          <select :value="pagination.perPage" @change="updatePerPage">
            <option :value="10">10</option>
            <option :value="15">15</option>
            <option :value="30">30</option>
            <option :value="50">50</option>
            <option :value="100">100</option>
          </select>
        </label>

        <label v-else class="field">
          <span>Pitch rows per page</span>
          <select :value="pitchDataOptions.perPage" @change="updatePitchPerPage">
            <option :value="20">20</option>
            <option :value="25">25</option>
            <option :value="50">50</option>
            <option :value="100">100</option>
            <option :value="250">250</option>
            <option :value="500">500</option>
          </select>
        </label>

        <label v-if="filters.category === 'pitchData'" class="field">
          <span>Game Date Start</span>
          <input v-model="pitchDataFilters.gameDateStart" type="date" data-test="pitch-game-date-start-filter" />
        </label>

        <label v-if="filters.category === 'pitchData'" class="field">
          <span>Game Date End</span>
          <input v-model="pitchDataFilters.gameDateEnd" type="date" data-test="pitch-game-date-end-filter" />
        </label>

        <label v-if="filters.category === 'pitchData'" class="field">
          <span>Game PK</span>
          <input v-model="pitchDataFilters.gamePk" type="text" inputmode="numeric" data-test="pitch-game-pk-filter" />
        </label>

        <label v-if="filters.category === 'pitchData'" class="field">
          <span>Pitcher</span>
          <div class="typeahead-field">
            <input
              v-model="pitcherNameInput"
              type="text"
              placeholder="Boyd, Glasnow, Ohtani…"
              autocomplete="off"
              data-test="pitch-pitcher-filter"
              @input="handlePitcherNameInput"
              @focus="handlePitcherInputFocus"
              @blur="handlePitcherInputBlur"
            />

            <div v-if="showPitcherSuggestions" class="typeahead-menu" role="listbox" aria-label="Pitcher suggestions">
              <p v-if="pitcherSuggestionsLoading" class="typeahead-status">
                Looking up players…
              </p>

              <button
                v-for="player in pitcherSuggestions"
                v-else
                :key="player.id"
                type="button"
                class="typeahead-option"
                @mousedown.prevent="applyPitcherSuggestion(player)"
              >
                <span class="typeahead-option__name">{{ player.fullName }}</span>
                <span class="typeahead-option__meta">
                  {{ player.team.abbreviation || player.team.team_name || player.team.name }}
                </span>
              </button>
            </div>
          </div>
        </label>

        <label v-if="filters.category === 'pitchData'" class="field">
          <span>Batter</span>
          <div class="typeahead-field">
            <input
              v-model="batterNameInput"
              type="text"
              placeholder="Cabrera, Trout, Ohtani…"
              autocomplete="off"
              data-test="pitch-batter-filter"
              @input="handleBatterNameInput"
              @focus="handleBatterInputFocus"
              @blur="handleBatterInputBlur"
            />

            <div v-if="showBatterSuggestions" class="typeahead-menu" role="listbox" aria-label="Batter suggestions">
              <p v-if="batterSuggestionsLoading" class="typeahead-status">
                Looking up players…
              </p>

              <button
                v-for="player in batterSuggestions"
                v-else
                :key="player.id"
                type="button"
                class="typeahead-option"
                @mousedown.prevent="applyBatterSuggestion(player)"
              >
                <span class="typeahead-option__name">{{ player.fullName }}</span>
                <span class="typeahead-option__meta">
                  {{ player.team.abbreviation || player.team.team_name || player.team.name }}
                </span>
              </button>
            </div>
          </div>
        </label>

        <label v-if="filters.category === 'pitchData'" class="field">
          <span>Pitch Type</span>
          <select v-model="pitchDataFilters.pitchType" data-test="pitch-type-filter">
            <option value="">Any</option>
            <option v-for="pitchTypeOption in pitchTypeOptions" :key="pitchTypeOption" :value="pitchTypeOption">
              {{ pitchTypeOption }}
            </option>
          </select>
        </label>

        <label v-if="filters.category === 'pitchData'" class="field">
          <span>Events</span>
          <select v-model="pitchDataFilters.events" data-test="pitch-events-filter">
            <option value="">Any</option>
            <option v-for="pitchEventOption in pitchEventOptions" :key="pitchEventOption" :value="pitchEventOption">
              {{ pitchEventOption }}
            </option>
          </select>
        </label>
      </div>

    </section>

    <section class="table-stage">
      <header class="table-stage__header">
        <div>
          <h2>{{ tableTitle }}</h2>
          <p></p>
        </div>

        <div class="table-actions">
          <button class="ghost-button" type="button" :disabled="filters.category === 'pitchData' ? pitchLoading : loading" @click="filters.category === 'pitchData' ? refreshPitchData() : refresh()">
            {{ (filters.category === 'pitchData' ? pitchLoading : loading) ? 'Refreshing…' : 'Refresh Data' }}
          </button>
        </div>
      </header>

      <p v-if="filters.category === 'pitchData' ? pitchError : error" class="error-banner">
        {{ filters.category === 'pitchData' ? pitchError : error }}
      </p>

      <PitchDataTable
        v-if="filters.category === 'pitchData'"
        :rows="pitchRows"
        :meta="pitchMeta"
        :loading="pitchLoading"
        @page-change="updatePitchPage"
      />

      <PlayerSeasonStatsTable
        v-else
        :rows="rows"
        :meta="meta"
        :loading="loading"
        :sort="sort.value"
        @sort-change="updateSort"
        @page-change="updatePage"
      />
    </section>
  </main>
</template>
