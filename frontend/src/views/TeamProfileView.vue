<script setup>
import { computed, inject, onMounted, reactive, ref, watch } from 'vue'
import { routeLocationKey, routerKey } from 'vue-router'

import { useTeamProfile } from '../composables/useTeamProfile'
import { adminRequestHeaders } from '../composables/apiAuth'
import { formatTwoDecimalPitchingRate } from '../utils/baseballStatFormatting'
import SavedAnalysisControls from '../components/SavedAnalysisControls.vue'
import TeamLeadersCard from '../components/TeamLeadersCard.vue'
import { frontendConfig, teamLogoUrl } from '../config'
import { teamThemeStyle } from '../utils/teamThemes'

const props = defineProps({
  teamId: { type: [String, Number], required: true },
})

const route = inject(routeLocationKey, { query: {}, fullPath: `/teams/${props.teamId}` })
const router = inject(routerKey, { replace: () => { }, push: () => { } })
const teamId = computed(() => props.teamId)
const MLB_TEAM_SLUGS = Object.freeze({
  108: 'angels', 109: 'dbacks', 110: 'orioles', 111: 'redsox', 112: 'cubs',
  113: 'reds', 114: 'guardians', 115: 'rockies', 116: 'tigers', 117: 'astros',
  118: 'royals', 119: 'dodgers', 120: 'nationals', 121: 'mets', 133: 'athletics',
  134: 'pirates', 135: 'padres', 136: 'mariners', 137: 'giants', 138: 'cardinals',
  139: 'rays', 140: 'rangers', 141: 'bluejays', 142: 'twins', 143: 'phillies',
  144: 'braves', 145: 'whitesox', 146: 'marlins', 147: 'yankees', 158: 'brewers',
})
const BASEBALL_REFERENCE_TEAM_CODES = Object.freeze({
  118: 'KCR', 120: 'WSN', 133: 'ATH', 135: 'SDP', 137: 'SFG', 139: 'TBR', 145: 'CHW',
})

const profileTabs = [
  { id: 'overview', label: 'Overview' },
  { id: 'roster', label: 'Roster' },
  { id: 'schedule', label: 'Schedule' },
  { id: 'player-stats', label: 'Player Stats' },
  { id: 'team-stats', label: 'Team Stats' },
  { id: 'opponent', label: 'Opponent Preparation' },
  { id: 'lineup', label: 'Lineup Planner' },
]
const SCHEDULE_WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const selectedSeason = ref(Number(route.query.season) || null)
const selectedProfileTab = ref(profileTabs.some((tab) => tab.id === route.query.tab) ? route.query.tab : 'overview')
const requestedProfileSection = computed(() => ['schedule', 'player-stats', 'team-stats', 'opponent', 'lineup'].includes(selectedProfileTab.value) ? selectedProfileTab.value : 'overview')
const selectedRosterView = ref(['active', 'injured', 'fortyMan'].includes(route.query.roster) ? route.query.roster : 'active')
const selectedScheduleMonth = ref(null)
const playerStatsSort = reactive({ batting: 'player', pitching: 'player' })
const teamStatsCategory = ref('batting')
const teamStatsSort = ref('-ops')
const playerStatsCategory = ref('batting')
const savedAnalysisState = computed(() => ({
  teamId: teamId.value,
  season: selectedSeason.value,
  tab: selectedProfileTab.value,
  rosterView: selectedRosterView.value,
}))
const savedAnalysisUrl = computed(() => {
  const query = new URLSearchParams()
  if (selectedSeason.value) query.set('season', String(selectedSeason.value))
  if (selectedProfileTab.value !== 'overview') query.set('tab', selectedProfileTab.value)
  if (selectedRosterView.value !== 'active') query.set('roster', selectedRosterView.value)
  return `/teams/${encodeURIComponent(teamId.value)}${query.size ? `?${query}` : ''}`
})
const { team, loading, error, refresh } = useTeamProfile(teamId, selectedSeason, requestedProfileSection)
const teamHeaderStyle = computed(() => teamThemeStyle(team.value?.mlbId || team.value?.mlb_id))
const externalTeamLinks = computed(() => {
  if (!team.value?.mlbId) return []

  const mlbSlug = MLB_TEAM_SLUGS[team.value.mlbId]
  const fangraphsSlug = team.value.teamName
    ?.normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/d-backs/g, "diamondbacks")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
  const baseballReferenceCode = BASEBALL_REFERENCE_TEAM_CODES[team.value.mlbId] || team.value.abbreviation
  const season = team.value.season

  return [
    { key: "baseball-savant", label: "Baseball Savant", href: frontendConfig.externalUrls.baseballSavantTeamBaseUrl + "/" + team.value.mlbId },
    { key: "mlb", label: "MLB.com", href: mlbSlug ? frontendConfig.externalUrls.mlbTeamBaseUrl + "/" + mlbSlug : null },
    { key: "baseball-reference", label: "Baseball Reference", href: baseballReferenceCode && season ? frontendConfig.externalUrls.baseballReferenceTeamBaseUrl + "/" + baseballReferenceCode + "/" + season + ".shtml" : null },
    { key: "fangraphs", label: "FanGraphs", href: fangraphsSlug ? frontendConfig.externalUrls.fangraphsTeamBaseUrl + "/" + fangraphsSlug : null },
  ].filter((link) => link.href)
})
const savingReport = ref(false)
const reportSaveError = ref('')
const savingLineup = ref(false)
const lineupError = ref('')
const lineupName = ref('')
const lineupNotes = ref('')
const lineupEvaluation = reactive({
  opponent: '',
  opponentStrength: 50,
  parkFactor: 100,
  pitcherHand: 'R',
  recentPerformance: 50,
  reliability: 50,
})
const lineupDecision = reactive({
  excludedPlayerIds: [],
  requiredStarterIds: [],
  weights: { production: 45, platoon: 25, recent: 15, reliability: 15 },
  alternativeCount: 3,
})
const recommendingLineup = ref(false)
const availableTeams = ref([])
const lineupRows = ref(Array.from({ length: 9 }, (_, index) => ({ battingSlot: index + 1, playerId: '', defensivePosition: '' })))
const lineupPositions = ['C', '1B', '2B', '3B', 'SS', 'LF', 'CF', 'RF', 'DH']
const opponentTeamOptions = computed(() => availableTeams.value.filter((teamOption) => teamOption.id !== team.value?.id))

watch(
  () => team.value?.season,
  (season) => {
    if (season && selectedSeason.value === null) selectedSeason.value = season
  },
)

watch(teamId, () => {
  selectedSeason.value = null
  selectedProfileTab.value = 'overview'
  selectedRosterView.value = 'active'
  selectedScheduleMonth.value = null
  reportSaveError.value = ''
  lineupError.value = ''
})

watch(
  () => [route.query.season, route.query.tab, route.query.roster],
  ([season, tab, roster]) => {
    selectedSeason.value = Number(season) || selectedSeason.value
    selectedProfileTab.value = profileTabs.some((entry) => entry.id === tab) ? tab : 'overview'
    selectedRosterView.value = ['active', 'injured', 'fortyMan'].includes(roster) ? roster : 'active'
  },
)

watch(
  [selectedSeason, selectedProfileTab, selectedRosterView],
  ([season, tab, roster]) => {
    const query = { ...route.query }
    if (season) query.season = String(season)
    else delete query.season
    if (tab !== 'overview') query.tab = tab
    else delete query.tab
    if (roster !== 'active') query.roster = roster
    else delete query.roster
    router.replace({ name: 'team-profile', params: { id: teamId.value }, query })
  },
)

async function loadAvailableTeams() {
  try {
    const response = await fetch('/api/teams', { headers: { Accept: 'application/json' } })
    if (!response.ok) return
    const payload = await response.json()
    availableTeams.value = (payload.data || []).map((team) => ({
      id: team.id,
      name: team.name,
      abbreviation: team.abbreviation,
    }))
  } catch {
    availableTeams.value = []
  }
}

function openSavedAnalysis(item) {
  router.push(item.reproducibleUrl)
}

onMounted(loadAvailableTeams)

const injuredRoster = computed(() => team.value?.rosters?.fortyMan?.filter((membership) => membership.injured) || [])

const displayedRoster = computed(() => {
  if (selectedRosterView.value === 'injured') return injuredRoster.value
  return team.value?.rosters?.[selectedRosterView.value] || []
})

const DEPTH_CHART_GROUPS = Object.freeze([
  { key: 'rotation', label: 'Starters', role: 'Starting pitchers', positions: ['SP'], pitchingRole: 'starter' },
  { key: 'bullpen', label: 'Relievers', role: 'Relief pitchers', positions: ['RP', 'P'], pitchingRole: 'reliever' },
  { key: 'catcher', label: 'Catcher', role: 'Battery', positions: ['C'] },
  { key: 'infield', label: 'Infield', role: 'Position players', positions: ['1B', '2B', '3B', 'SS'] },
  { key: 'outfield', label: 'Outfield', role: 'Position players', positions: ['LF', 'CF', 'RF'] },
  { key: 'dh-utility', label: 'DH / utility', role: 'Flexible role', positions: ['DH', 'UT', 'UTIL'] },
])
const DEPTH_CHART_SECONDARY_POSITIONS = Object.freeze({
  '116:eduardo valencia': ['C'],
})

function depthChartPositions(membership) {
  const primaryPosition = String(membership.primaryPosition || '').toUpperCase()
  const configuredPositions = DEPTH_CHART_SECONDARY_POSITIONS[
    `${team.value?.mlbId}:${String(membership.player?.fullName || '').toLowerCase()}`
  ] || []
  const suppliedPositions = membership.positions || membership.secondaryPositions || []

  return [...new Set([primaryPosition, ...suppliedPositions, ...configuredPositions].filter(Boolean))]
    .map((position) => String(position).toUpperCase())
}

function depthChartGroupMatches(group, membership) {
  const positions = depthChartPositions(membership)
  if (!group.pitchingRole) return positions.includes(group.positions[0]) || group.positions.some((position) => positions.includes(position))
  if (positions.includes('SP')) return group.pitchingRole === 'starter'
  if (positions.includes('RP')) return group.pitchingRole !== 'starter'
  if (positions.includes('P')) return membership.pitchingRole === group.pitchingRole
  return false
}

const depthChartGroups = computed(() => {
  const roster = displayedRoster.value
  const assignedIds = new Set()

  const groups = DEPTH_CHART_GROUPS.map((group) => {
    const lanes = group.positions.map((position) => ({
      position,
      players: roster.filter((membership) => {
        const matchesGenericPitcherLane = group.pitchingRole === 'starter' && position === 'SP' &&
          depthChartPositions(membership).includes('P')
        const isMatch = depthChartGroupMatches(group, membership) &&
          (depthChartPositions(membership).includes(position) || matchesGenericPitcherLane)
        if (isMatch) assignedIds.add(membership.id)
        return isMatch
      }),
    })).filter((lane) => lane.players.length)

    return { ...group, lanes, playerCount: lanes.reduce((count, lane) => count + lane.players.length, 0) }
  }).filter((group) => group.playerCount)

  const otherPlayers = roster.filter((membership) => !assignedIds.has(membership.id))
  if (otherPlayers.length) {
    groups.push({
      key: 'other',
      label: 'Other roles',
      role: 'Roster depth',
      positions: [],
      lanes: [{ position: '—', players: otherPlayers }],
      playerCount: otherPlayers.length,
    })
  }

  return groups
})

const rosterViewLabel = computed(() => ({
  active: 'Active roster',
  injured: 'Injured list',
  fortyMan: '40-man roster',
})[selectedRosterView.value])

const recordLabel = computed(() => {
  return formatRecord(team.value?.record)
})

const PLAYER_STATS_INTEGER_KEYS = Object.freeze({
  batting: new Set(['gamesPlayed', 'atBats', 'runs', 'hits', 'doubles', 'triples', 'homeRuns', 'rbi', 'baseOnBalls', 'strikeOuts', 'stolenBases', 'caughtStealing']),
  pitching: new Set(['W', 'L', 'G', 'GS', 'CG', 'ShO', 'SV', 'SVO', 'hits', 'runs', 'ER', 'homeRuns', 'hitByPitch', 'baseOnBalls', 'strikeOuts']),
})
const PLAYER_STATS_FIXED_DECIMALS = Object.freeze({
  avg: 3,
  obp: 3,
  slg: 3,
  ops: 3,
  ERA: 2,
  whip: 2,
  WAR: 1,
})
const PLAYER_STATS_LEADING_ZERO_KEYS = new Set(['avg', 'obp', 'slg', 'ops'])

function sortedPlayerStats(category) {
  const entries = team.value?.playerStats?.[category]?.players || []
  const sort = playerStatsSort[category]
  const descending = sort.startsWith('-')
  const key = descending ? sort.slice(1) : sort

  return entries.slice().sort((left, right) => {
    let comparison
    if (key === 'player') {
      comparison = (left.player.full_name || '').localeCompare(right.player.full_name || '')
    } else {
      const leftValue = Number(left.stats?.[key])
      const rightValue = Number(right.stats?.[key])
      const leftMissing = !Number.isFinite(leftValue)
      const rightMissing = !Number.isFinite(rightValue)
      if (leftMissing || rightMissing) {
        if (leftMissing && rightMissing) return 0
        return leftMissing ? 1 : -1
      }
      comparison = leftValue - rightValue
    }

    return descending ? -comparison : comparison
  })
}

function togglePlayerStatsSort(category, key) {
  const current = playerStatsSort[category]
  playerStatsSort[category] = current === key ? `-${key}` : current === `-${key}` ? key : `-${key}`
}

function playerStatsSortIndicator(category, key) {
  const sort = playerStatsSort[category]
  if (sort === key) return '↑'
  if (sort === `-${key}`) return '↓'
  return ''
}

function formatPlayerStatValue(category, key, value) {
  if (value === null || value === undefined || value === '') return '—'

  const numericValue = Number(value)
  if (!Number.isFinite(numericValue)) return value
  if (PLAYER_STATS_INTEGER_KEYS[category].has(key)) return String(Math.trunc(numericValue))

  const decimals = PLAYER_STATS_FIXED_DECIMALS[key]
  const formatted = decimals === undefined ? String(numericValue) : numericValue.toFixed(decimals)
  return PLAYER_STATS_LEADING_ZERO_KEYS.has(key) ? formatted.replace(/^(-?)0\./, '$1.') : formatted
}

function sortedTeamStats() {
  const category = teamStatsCategory.value
  const entries = team.value?.teamStats?.[category]?.teams || []
  const sort = teamStatsSort.value
  const descending = sort.startsWith('-')
  const key = descending ? sort.slice(1) : sort

  return entries.slice().sort((left, right) => {
    if (key === 'team') return descending
      ? (right.team.name || '').localeCompare(left.team.name || '')
      : (left.team.name || '').localeCompare(right.team.name || '')

    const leftValue = Number(left.stats?.[key])
    const rightValue = Number(right.stats?.[key])
    const leftMissing = !Number.isFinite(leftValue)
    const rightMissing = !Number.isFinite(rightValue)
    if (leftMissing || rightMissing) {
      if (leftMissing && rightMissing) return 0
      return leftMissing ? 1 : -1
    }
    const comparison = leftValue - rightValue
    return descending ? -comparison : comparison
  })
}

function toggleTeamStatsSort(key) {
  teamStatsSort.value = teamStatsSort.value === key ? `-${key}` : teamStatsSort.value === `-${key}` ? key : `-${key}`
}

function teamStatsSortIndicator(key) {
  if (teamStatsSort.value === key) return '↑'
  if (teamStatsSort.value === `-${key}`) return '↓'
  return ''
}

function formatRecord(record) {
  if (!record?.games_played) return 'No completed games'
  return [record.wins, record.losses, ...(record.ties ? [record.ties] : [])].join('–')
}

const divisionGapLabel = computed(() => {
  const standing = team.value?.divisionRank
  if (!standing) return ''

  const direction = standing.rank === 1 ? 'ahead' : 'behind'
  const value = Number(standing.rank === 1 ? standing.games_ahead : standing.games_behind)
  if (!Number.isFinite(value)) return ''

  const formatted = Number.isInteger(value) ? value.toFixed(0) : value.toFixed(1)
  return `${formatted} ${Math.abs(value) === 1 ? 'game' : 'games'} ${direction}`
})

function formatTeamSummaryStat(key, value) {
  if (value === null || value === undefined || value === '') return '—'
  const number = Number(value)
  if (!Number.isFinite(number)) return value
  if (key === 'avg') return number.toFixed(3).replace(/^0\./, '.')
  if (key === 'ERA') return number.toFixed(2)
  return String(Math.trunc(number))
}

const recentRecordEntries = computed(() => (
  [10, 30, 50].map((window) => {
    const record = team.value?.record?.recent?.[window]
    return record?.games_played ? { window, label: formatRecord(record) } : null
  }).filter(Boolean)
))

const scheduleMonthKeys = computed(() => (
  [...new Set((team.value?.scheduleGames || []).map((game) => game.officialDate?.slice(0, 7)).filter(Boolean))].sort()
))

watch(
  () => [team.value?.id, team.value?.season, scheduleMonthKeys.value.join(',')],
  ([teamIdValue, season, monthKeys]) => {
    if (!teamIdValue || !season || !monthKeys) {
      selectedScheduleMonth.value = null
      return
    }

    const availableMonths = monthKeys.split(',')
    if (selectedScheduleMonth.value && availableMonths.includes(selectedScheduleMonth.value)) return

    const now = new Date()
    const currentMonth = [now.getFullYear(), String(now.getMonth() + 1).padStart(2, '0')].join('-')
    selectedScheduleMonth.value = availableMonths.includes(currentMonth) ? currentMonth : availableMonths[availableMonths.length - 1]
  },
  { immediate: true },
)

const scheduleMonthLabel = computed(() => {
  if (!selectedScheduleMonth.value) return ((team.value?.season || '') + ' schedule').trim()
  const [year, month] = selectedScheduleMonth.value.split('-').map(Number)
  return new Intl.DateTimeFormat('en-US', { month: 'long', year: 'numeric' }).format(new Date(year, month - 1, 1, 12))
})

const scheduleCalendarDays = computed(() => {
  if (!selectedScheduleMonth.value) return []

  const [year, month] = selectedScheduleMonth.value.split('-').map(Number)
  const gamesByDate = new Map()
  for (const game of team.value?.scheduleGames || []) {
    if (!game.officialDate?.startsWith(selectedScheduleMonth.value + '-')) continue
    if (!gamesByDate.has(game.officialDate)) gamesByDate.set(game.officialDate, [])
    gamesByDate.get(game.officialDate).push(game)
  }

  const cells = Array.from({ length: new Date(year, month - 1, 1).getDay() }, () => null)
  const daysInMonth = new Date(year, month, 0).getDate()
  for (let day = 1; day <= daysInMonth; day += 1) {
    const date = [selectedScheduleMonth.value, String(day).padStart(2, '0')].join('-')
    cells.push({ date, day, games: gamesByDate.get(date) || [] })
  }
  while (cells.length % 7 !== 0) cells.push(null)
  return cells
})

const canShowPreviousScheduleMonth = computed(() => (
  Boolean(selectedScheduleMonth.value && scheduleMonthKeys.value.length && selectedScheduleMonth.value > scheduleMonthKeys.value[0])
))
const canShowNextScheduleMonth = computed(() => (
  Boolean(selectedScheduleMonth.value && scheduleMonthKeys.value.length && selectedScheduleMonth.value < scheduleMonthKeys.value.at(-1))
))

function shiftScheduleMonth(offset) {
  if (!selectedScheduleMonth.value) return
  const [year, month] = selectedScheduleMonth.value.split('-').map(Number)
  const target = new Date(year, month - 1 + offset, 1, 12)
  selectedScheduleMonth.value = [target.getFullYear(), String(target.getMonth() + 1).padStart(2, '0')].join('-')
}

function scheduleGameLabel(game) {
  if (teamScore(game) !== null && teamScore(game) !== undefined) {
    return resultLabel(game) + ', ' + teamScore(game) + '–' + opponentScore(game)
  }

  const status = String(game.detailedStatus || game.status || '').toLowerCase()
  if (['postponed', 'cancelled', 'canceled', 'suspended'].some((value) => status.includes(value))) {
    return game.detailedStatus || titleize(game.status)
  }
  if (!game.scheduledAt) return game.detailedStatus || 'Time TBD'

  return new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit' }).format(new Date(game.scheduledAt))
}

function scheduleOpponentLogo(game) {
  const gameOpponent = opponent(game)
  return gameOpponent?.logo_url || (gameOpponent?.mlb_id ? teamLogoUrl(gameOpponent.mlb_id) : null)
}

function isToday(value) {
  const now = new Date()
  const today = [now.getFullYear(), String(now.getMonth() + 1).padStart(2, '0'), String(now.getDate()).padStart(2, '0')].join('-')
  return value === today
}

const dashboard = computed(() => team.value?.performanceDashboard || {})
const nextSeriesGames = computed(() => {
  const upcoming = team.value?.upcomingGames || []
  if (!upcoming.length) return []

  const opponentId = opponent(upcoming[0])?.id
  const series = []
  for (const game of upcoming) {
    if (opponent(game)?.id !== opponentId) break
    series.push(game)
  }
  return series
})
const nextOpponent = computed(() => nextSeriesGames.value.length ? opponent(nextSeriesGames.value[0]) : null)
const opponentPrep = computed(() => team.value?.opponentPreparation || {})
const lineupPlayers = computed(() => (team.value?.rosters?.active || []).filter((membership) => !['P', 'SP', 'RP', 'PITCHER'].includes(String(membership.primaryPosition || '').toUpperCase())))
watch(nextOpponent, (opponent) => {
  if (!lineupEvaluation.opponent && opponent?.name) lineupEvaluation.opponent = opponent.name
})
const nextSeriesDateLabel = computed(() => {
  const games = nextSeriesGames.value
  if (!games.length) return 'No upcoming series'

  const first = formatDate(games[0].officialDate, true)
  const last = formatDate(games.at(-1).officialDate, true)
  return first === last ? first : `${first} – ${last}`
})
const rankingGroups = computed(() => [
  {
    key: 'offense',
    title: 'Offensive rankings',
    metrics: [
      { key: 'ops', label: 'OPS', entry: dashboard.value.rankings?.offense?.ops, value: formatDecimal(dashboard.value.rankings?.offense?.ops?.value) },
      { key: 'runs-per-game', label: 'Runs / G', entry: dashboard.value.rankings?.offense?.runs_per_game, value: formatDecimal(dashboard.value.rankings?.offense?.runs_per_game?.value, 2) },
      { key: 'home-runs', label: 'Home Runs', entry: dashboard.value.rankings?.offense?.home_runs, value: formatInteger(dashboard.value.rankings?.offense?.home_runs?.value) },
      { key: 'batting-average', label: 'AVG', entry: dashboard.value.rankings?.offense?.batting_average, value: formatDecimal(dashboard.value.rankings?.offense?.batting_average?.value) },
      { key: 'stolen-bases', label: 'Stolen Bases', entry: dashboard.value.rankings?.offense?.stolen_bases, value: formatInteger(dashboard.value.rankings?.offense?.stolen_bases?.value) },
      { key: 'strikeout-rate', label: 'K Rate', entry: dashboard.value.rankings?.offense?.strikeout_rate, value: formatPercent(dashboard.value.rankings?.offense?.strikeout_rate?.value) },
      { key: 'walk-rate', label: 'BB Rate', entry: dashboard.value.rankings?.offense?.walk_rate, value: formatPercent(dashboard.value.rankings?.offense?.walk_rate?.value) },
    ],
  },
  {
    key: 'pitching',
    title: 'Pitching rankings',
    metrics: [
      { key: 'era', label: 'ERA', entry: dashboard.value.rankings?.pitching?.era, value: formatTwoDecimalPitchingRate(dashboard.value.rankings?.pitching?.era?.value) },
      { key: 'whip', label: 'WHIP', entry: dashboard.value.rankings?.pitching?.whip, value: formatTwoDecimalPitchingRate(dashboard.value.rankings?.pitching?.whip?.value) },
      { key: 'saves', label: 'Saves', entry: dashboard.value.rankings?.pitching?.saves, value: formatInteger(dashboard.value.rankings?.pitching?.saves?.value) },
      { key: 'strikeouts', label: 'Strikeouts', entry: dashboard.value.rankings?.pitching?.strikeouts, value: formatInteger(dashboard.value.rankings?.pitching?.strikeouts?.value) },
      { key: 'quality-starts', label: 'Quality Starts', entry: dashboard.value.rankings?.pitching?.quality_starts, value: formatInteger(dashboard.value.rankings?.pitching?.quality_starts?.value) },
      { key: 'strikeout-rate', label: 'K Rate', entry: dashboard.value.rankings?.pitching?.strikeout_rate, value: formatPercent(dashboard.value.rankings?.pitching?.strikeout_rate?.value) },
      { key: 'walk-rate', label: 'BB Rate', entry: dashboard.value.rankings?.pitching?.walk_rate, value: formatPercent(dashboard.value.rankings?.pitching?.walk_rate?.value) },
    ],
  },
])

function formatDate(value, includeYear = false) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    ...(includeYear ? { year: 'numeric' } : {}),
  }).format(new Date(`${value}T12:00:00`))
}

function formatTimestamp(value) {
  if (!value) return 'Unavailable'
  return new Intl.DateTimeFormat('en-US', {
    month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit',
  }).format(new Date(value))
}

function titleize(value) {
  return String(value || 'Status unavailable').replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function opponent(game) {
  return game.homeTeam.id === team.value.id ? game.awayTeam : game.homeTeam
}

function isHome(game) {
  return game.homeTeam.id === team.value.id
}

function teamScore(game) {
  return isHome(game) ? game.homeScore : game.awayScore
}

function opponentScore(game) {
  return isHome(game) ? game.awayScore : game.homeScore
}

function resultLabel(game) {
  if (teamScore(game) === null || teamScore(game) === undefined) return '—'
  if (teamScore(game) === opponentScore(game)) return 'T'
  return teamScore(game) > opponentScore(game) ? 'W' : 'L'
}

function probablePitcher(game) {
  return isHome(game) ? game.homeProbablePitcher : game.awayProbablePitcher
}

function opponentProbablePitcher(game) {
  return isHome(game) ? game.awayProbablePitcher : game.homeProbablePitcher
}

function seriesLocation(game) {
  return isHome(game) ? `vs ${nextOpponent.value?.abbreviation}` : `at ${nextOpponent.value?.abbreviation}`
}

function formatDecimal(value, digits = 3) {
  if (value === null || value === undefined || value === '') return '—'
  const number = Number(value)
  if (!Number.isFinite(number)) return '—'
  return number.toFixed(digits)
}

function formatInteger(value) {
  if (value === null || value === undefined || value === '') return '—'
  const number = Number(value)
  if (!Number.isFinite(number)) return '—'
  return Math.round(number).toLocaleString('en-US')
}

function formatPercent(value, digits = 1) {
  if (value === null || value === undefined || value === '') return '—'
  const number = Number(value)
  if (!Number.isFinite(number)) return '—'
  return `${(number * 100).toFixed(digits)}%`
}

function signedChange(value, unit) {
  if (value === null || value === undefined) return '—'
  const number = Number(value)
  const formatted = `${number > 0 ? '+' : ''}${number.toFixed(1)}`
  return unit === 'mph' ? `${formatted} mph` : `${formatted} pts`
}

function evidenceLabel(item) {
  const velocity = Number(item.velocity)
  return [item.pitch_name, Number.isFinite(velocity) ? `${velocity.toFixed(1)} mph` : null].filter(Boolean).join(' · ')
}

function formatRank(entry) {
  if (!entry || !entry.rank) return '—'
  return `#${entry.rank}`
}

function rankingBarPercent(entry) {
  const rank = Number(entry?.rank || 0)
  const totalTeams = Number(dashboard.value.rankings?.context?.total_teams || 30)
  if (!Number.isFinite(rank) || rank <= 0 || !Number.isFinite(totalTeams) || totalTeams <= 0) return 0
  if (rank === 1) return 100

  return Math.round(Math.max(0, Math.min(100, ((totalTeams - rank) / totalTeams) * 100)) * 10) / 10
}

function handleProfileTabKeydown(event, currentIndex) {
  let nextIndex
  if (event.key === 'ArrowRight') nextIndex = (currentIndex + 1) % profileTabs.length
  if (event.key === 'ArrowLeft') nextIndex = (currentIndex - 1 + profileTabs.length) % profileTabs.length
  if (event.key === 'Home') nextIndex = 0
  if (event.key === 'End') nextIndex = profileTabs.length - 1
  if (nextIndex === undefined) return

  event.preventDefault()
  selectedProfileTab.value = profileTabs[nextIndex].id
  event.currentTarget.closest('[role="tablist"]')?.querySelectorAll('[role="tab"]')?.[nextIndex]?.focus()
}

async function saveOpponentReport() {
  if (!team.value?.id || !nextOpponent.value || savingReport.value) return

  savingReport.value = true
  reportSaveError.value = ''
  try {
    const response = await fetch(`/api/teams/${encodeURIComponent(team.value.id)}/opponent_reports`, {
      method: 'POST',
      headers: adminRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
      body: JSON.stringify({ season: team.value.season }),
    })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(payload.message || 'Unable to generate opponent report.')
    await refresh()
  } catch (requestError) {
    reportSaveError.value = requestError.message
  } finally {
    savingReport.value = false
  }
}

function suggestedPosition(membership) {
  const position = String(membership?.primaryPosition || '').toUpperCase()
  return lineupPositions.includes(position) ? position : ''
}

function populateLineup() {
  lineupRows.value = Array.from({ length: 9 }, (_, index) => {
    const membership = lineupPlayers.value[index]
    return {
      battingSlot: index + 1,
      playerId: membership?.player?.id ? String(membership.player.id) : '',
      defensivePosition: suggestedPosition(membership),
      lockOrder: false,
    }
  })
}

function decisionConstraints() {
  return {
    locked_player_ids: lineupRows.value.filter((row) => row.lockOrder && row.playerId).map((row) => Number(row.playerId)),
    locked_batting_order: Object.fromEntries(lineupRows.value.filter((row) => row.lockOrder && row.playerId).map((row) => [row.playerId, row.battingSlot])),
    excluded_player_ids: lineupDecision.excludedPlayerIds.map(Number),
    required_starter_ids: lineupDecision.requiredStarterIds.map(Number),
    unavailable_player_ids: [],
  }
}

function applyRecommendedEntries(entries) {
  lineupRows.value = Array.from({ length: 9 }, (_, index) => {
    const entry = entries[index] || {}
    return { battingSlot: index + 1, playerId: entry.player_id ? String(entry.player_id) : '', defensivePosition: entry.defensive_position || '', lockOrder: false }
  })
}

async function recommendLineup() {
  if (!team.value?.id || recommendingLineup.value) return
  recommendingLineup.value = true
  lineupError.value = ''
  try {
    const response = await fetch(`/api/teams/${encodeURIComponent(team.value.id)}/lineup_scenarios/recommend`, {
      method: 'POST',
      headers: adminRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
      body: JSON.stringify({ season: team.value.season, scenario_date: new Date().toISOString().slice(0, 10), evaluation_inputs: { pitcher_hand: lineupEvaluation.pitcherHand }, decision_constraints: decisionConstraints(), decision_weights: Object.fromEntries(Object.entries(lineupDecision.weights).map(([key, value]) => [key, Number(value)])), alternative_count: lineupDecision.alternativeCount }),
    })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error((payload.data?.errors || [payload.message || 'Unable to recommend a lineup.']).join(' '))
    applyRecommendedEntries(payload.data.recommended)
  } catch (requestError) {
    lineupError.value = requestError.message
  } finally {
    recommendingLineup.value = false
  }
}

async function saveLineupScenario() {
  if (!team.value?.id || savingLineup.value) return

  savingLineup.value = true
  lineupError.value = ''
  try {
    const response = await fetch(`/api/teams/${encodeURIComponent(team.value.id)}/lineup_scenarios`, {
      method: 'POST',
      headers: adminRequestHeaders({ Accept: 'application/json', 'Content-Type': 'application/json' }),
      body: JSON.stringify({
        season: team.value.season,
        scenario_date: new Date().toISOString().slice(0, 10),
        name: lineupName.value.trim() || `${team.value.abbreviation} lineup scenario`,
        notes: lineupNotes.value.trim(),
        evaluation_inputs: {
          opponent: lineupEvaluation.opponent.trim(),
          opponent_strength: Number(lineupEvaluation.opponentStrength),
          park_factor: Number(lineupEvaluation.parkFactor),
          pitcher_hand: lineupEvaluation.pitcherHand,
          recent_performance: Number(lineupEvaluation.recentPerformance),
          reliability: Number(lineupEvaluation.reliability),
        },
        decision_constraints: decisionConstraints(),
        decision_weights: Object.fromEntries(Object.entries(lineupDecision.weights).map(([key, value]) => [key, Number(value)])),
        alternative_count: lineupDecision.alternativeCount,
        entries: lineupRows.value.map((row) => ({
          player_id: row.playerId,
          batting_slot: row.battingSlot,
          defensive_position: row.defensivePosition,
        })),
      }),
    })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error((payload.violations || [payload.message || 'Unable to save lineup scenario.']).join(' '))
    lineupName.value = ''
    lineupNotes.value = ''
    await refresh()
  } catch (requestError) {
    lineupError.value = requestError.message
  } finally {
    savingLineup.value = false
  }
}
</script>

<template>
  <main class="team-profile-shell" :aria-busy="loading">
    <div v-if="loading && !team" class="team-state" data-test="team-loading">Building team profile…</div>
    <div v-else-if="error" class="team-state team-state--error" data-test="team-error">
      <p>{{ error }}</p>
      <button type="button" @click="refresh">Try again</button>
    </div>

    <template v-else-if="team">
      <RouterLink class="team-back" :to="{ name: 'teams' }">← All MLB teams</RouterLink>

      <section class="team-hero" :style="teamHeaderStyle">
        <svg class="team-hero__pattern" viewBox="0 0 720 360" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
          <path d="M455 24 696 180 455 336 214 180Z" />
          <path d="m455 74 164 106-164 106-164-106Z" />
          <circle cx="455" cy="180" r="32" />
          <path d="M455 38v284M313 180h284" />
        </svg>
        <p class="team-hero__title">Team profile <span>MLB ID: {{ team.mlbId }}</span></p>

        <div class="team-logo"><img :src="team.logoUrl" :alt="`${team.name} logo`" /></div>
        <div class="team-identity">
          <h1>{{ team.name }}</h1>
          <span>{{ team.abbreviation }} · {{ team.locationName }}</span>
        </div>
        <label class="season-picker">
          <span class="season-picker__label">Profile season</span>
          <select v-model.number="selectedSeason" :disabled="loading" data-test="team-season-select">
            <option v-for="season in team.availableSeasons" :key="season" :value="season">{{ season }}</option>
          </select>
          <span v-if="loading" class="season-loading" role="status" aria-live="polite" data-test="season-loading">
            <i aria-hidden="true"></i>
            Loading {{ selectedSeason }} season…
          </span>
        </label>

        <section class="team-summary" aria-label="Season summary">
          <article class="team-summary__record">
            <div>
              <span>{{ team.season }} record</span><strong>{{ recordLabel }}</strong><small>{{ team.record.games_played ||
                0 }} games</small>
            </div>
            <dl v-if="recentRecordEntries.length" class="team-summary__recent-records">
              <div v-for="entry in recentRecordEntries" :key="entry.window">
                <dt>Last {{ entry.window }}</dt>
                <dd>{{ entry.label }}</dd>
              </div>
            </dl>
          </article>
          <article><span>Run differential</span><strong>{{ (team.record.runs_scored || 0) - (team.record.runs_allowed ||
              0) }}</strong><small>{{ team.record.runs_scored || 0 }} RS · {{ team.record.runs_allowed || 0 }} RA</small>
          </article>
          <article data-test="division-rank">
            <span>Division rank</span><strong>{{ team.divisionRank ? '#' + team.divisionRank.rank : '—' }}</strong>
            <small>
              {{ team.divisionRank?.division?.name || 'Division unavailable' }}
              <br/><template v-if="divisionGapLabel"> · {{ divisionGapLabel }}</template>
            </small>
          </article>
          <article class="team-summary__leaders" data-test="team-stat-summary">
            <span>Team stats</span>
            <dl>
              <div>
                <dt>AVG</dt>
                <dd>{{ formatTeamSummaryStat('avg', team.teamStatsSummary?.batting?.avg?.value) }} <small>#{{ team.teamStatsSummary?.batting?.avg?.rank || '—' }}</small></dd>
              </div>
              <div>
                <dt>ERA</dt>
                <dd>{{ formatTeamSummaryStat('ERA', team.teamStatsSummary?.pitching?.ERA?.value) }} <small>#{{ team.teamStatsSummary?.pitching?.ERA?.rank || '—' }}</small></dd>
              </div>
              <div>
                <dt>HR</dt>
                <dd>{{ formatTeamSummaryStat('HR', team.teamStatsSummary?.batting?.homeRuns?.value) }} <small>#{{ team.teamStatsSummary?.batting?.homeRuns?.rank || '—' }}</small></dd>
              </div>
            </dl>
          </article>
        </section>

        <div class="team-hero__footer">
          <div class="team-explore-links">
            <span class="team-explore-links__label">Explore this team</span>
            <nav class="team-external-links" aria-label="External team profiles">
              <a v-for="link in externalTeamLinks" :key="link.key" :href="link.href" target="_blank" rel="noopener noreferrer" data-test="external-team-link">
                {{ link.label }} <span aria-hidden="true">↗</span>
              </a>
            </nav>
          </div>
        </div>
      </section>

      <nav class="team-profile-tabs" role="tablist" aria-label="Team profile sections">
        <button v-for="(tab, index) in profileTabs" :id="`team-profile-tab-${tab.id}`" :key="tab.id" type="button"
          role="tab" :aria-controls="`team-profile-panel-${tab.id}`" :aria-selected="selectedProfileTab === tab.id"
          :tabindex="selectedProfileTab === tab.id ? 0 : -1" :class="{ 'is-selected': selectedProfileTab === tab.id }"
          :data-test="`team-profile-tab-${tab.id}`" @click="selectedProfileTab = tab.id"
          @keydown="handleProfileTabKeydown($event, index)">
          {{ tab.label }}
          <span v-if="tab.id === 'roster'">{{ team.rosters.active.length }}</span>
        </button>
      </nav>

      <SavedAnalysisControls analysis-type="team_dashboard" :state="savedAnalysisState"
        :reproducible-url="savedAnalysisUrl" compact @apply="openSavedAnalysis" />

      <section v-show="selectedProfileTab === 'player-stats'" id="team-profile-panel-player-stats"
        class="team-panel team-profile-tab-panel player-stats-panel" role="tabpanel"
        aria-labelledby="team-profile-tab-player-stats" data-test="team-profile-panel-player-stats">
        <header>
          <div>
            <p>Basic player statistics</p>
            <h2>{{ team.playerStats.season }} player stats</h2>
          </div>
          <div class="team-stats-mode-toggle" role="tablist" aria-label="Player stats category">
            <button type="button" :class="{ 'is-selected': playerStatsCategory === 'batting' }" @click="playerStatsCategory = 'batting'">Hitting</button>
            <button type="button" :class="{ 'is-selected': playerStatsCategory === 'pitching' }" @click="playerStatsCategory = 'pitching'">Pitching</button>
          </div>
        </header>

        <div v-if="playerStatsCategory === 'batting' && team.playerStats.batting.players.length" class="player-stats-category" data-test="team-player-stats-batting">
          <h3>Batters</h3>
          <div class="player-stats-table-wrap">
            <table class="player-stats-table">
              <thead>
                <tr>
                  <th scope="col">
                    <button type="button" class="player-stats-sort-button" :aria-sort="playerStatsSortIndicator('batting', 'player') === '↑' ? 'ascending' : playerStatsSortIndicator('batting', 'player') === '↓' ? 'descending' : 'none'" @click="togglePlayerStatsSort('batting', 'player')">
                      Player <span>{{ playerStatsSortIndicator('batting', 'player') }}</span>
                    </button>
                  </th>
                  <th v-for="column in team.playerStats.batting.columns" :key="column.key" scope="col">
                    <button type="button" class="player-stats-sort-button" :aria-sort="playerStatsSortIndicator('batting', column.key) === '↑' ? 'ascending' : playerStatsSortIndicator('batting', column.key) === '↓' ? 'descending' : 'none'" @click="togglePlayerStatsSort('batting', column.key)">
                      {{ column.label }} <span>{{ playerStatsSortIndicator('batting', column.key) }}</span>
                    </button>
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="entry in sortedPlayerStats('batting')" :key="entry.player.id">
                  <th scope="row">
                    <RouterLink class="player-stats-player" :to="{ name: 'player-profile', params: { id: entry.player.id } }">
                      <span class="player-stats-headshot">
                        <img v-if="entry.player.headshot_url" :src="entry.player.headshot_url" :alt="`${entry.player.full_name} headshot`" />
                        <b v-else>{{ entry.player.first_name?.[0] }}{{ entry.player.last_name?.[0] }}</b>
                      </span>
                      {{ entry.player.full_name }}
                    </RouterLink>
                  </th>
                  <td v-for="column in team.playerStats.batting.columns" :key="column.key">{{ formatPlayerStatValue('batting', column.key, entry.stats[column.key]) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
        <p v-else-if="playerStatsCategory === 'batting'" class="team-empty">No batting stats are stored for {{ team.playerStats.season }}.</p>

        <div v-if="playerStatsCategory === 'pitching' && team.playerStats.pitching.players.length" class="player-stats-category" data-test="team-player-stats-pitching">
          <h3>Pitchers</h3>
          <div class="player-stats-table-wrap">
            <table class="player-stats-table">
              <thead>
                <tr>
                  <th scope="col">
                    <button type="button" class="player-stats-sort-button" :aria-sort="playerStatsSortIndicator('pitching', 'player') === '↑' ? 'ascending' : playerStatsSortIndicator('pitching', 'player') === '↓' ? 'descending' : 'none'" @click="togglePlayerStatsSort('pitching', 'player')">
                      Player <span>{{ playerStatsSortIndicator('pitching', 'player') }}</span>
                    </button>
                  </th>
                  <th v-for="column in team.playerStats.pitching.columns" :key="column.key" scope="col">
                    <button type="button" class="player-stats-sort-button" :aria-sort="playerStatsSortIndicator('pitching', column.key) === '↑' ? 'ascending' : playerStatsSortIndicator('pitching', column.key) === '↓' ? 'descending' : 'none'" @click="togglePlayerStatsSort('pitching', column.key)">
                      {{ column.label }} <span>{{ playerStatsSortIndicator('pitching', column.key) }}</span>
                    </button>
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="entry in sortedPlayerStats('pitching')" :key="entry.player.id">
                  <th scope="row">
                    <RouterLink class="player-stats-player" :to="{ name: 'player-profile', params: { id: entry.player.id } }">
                      <span class="player-stats-headshot">
                        <img v-if="entry.player.headshot_url" :src="entry.player.headshot_url" :alt="`${entry.player.full_name} headshot`" />
                        <b v-else>{{ entry.player.first_name?.[0] }}{{ entry.player.last_name?.[0] }}</b>
                      </span>
                      {{ entry.player.full_name }}
                    </RouterLink>
                  </th>
                  <td v-for="column in team.playerStats.pitching.columns" :key="column.key">{{ formatPlayerStatValue('pitching', column.key, entry.stats[column.key]) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
        <p v-else-if="playerStatsCategory === 'pitching'" class="team-empty">No pitching stats are stored for {{ team.playerStats.season }}.</p>
      </section>

      <section v-show="selectedProfileTab === 'team-stats'" id="team-profile-panel-team-stats"
        class="team-panel team-profile-tab-panel team-stats-panel" role="tabpanel"
        aria-labelledby="team-profile-tab-team-stats" data-test="team-profile-panel-team-stats">
        <header class="team-stats-header">
          <div>
            <p>League-wide team statistics</p>
            <h2>{{ team.teamStats.season }} team stats</h2>
          </div>
          <div class="team-stats-mode-toggle" role="tablist" aria-label="Team stats category">
            <button type="button" :class="{ 'is-selected': teamStatsCategory === 'batting' }" @click="teamStatsCategory = 'batting'; teamStatsSort = '-ops'">Hitting</button>
            <button type="button" :class="{ 'is-selected': teamStatsCategory === 'pitching' }" @click="teamStatsCategory = 'pitching'; teamStatsSort = '-strikeOuts'">Pitching</button>
          </div>
        </header>

        <div class="player-stats-table-wrap team-stats-table-wrap" data-test="team-stats-table">
          <table class="player-stats-table team-stats-table">
            <thead>
              <tr>
                <th scope="col">
                  <button type="button" class="player-stats-sort-button" @click="toggleTeamStatsSort('team')">
                    Team <span>{{ teamStatsSortIndicator('team') }}</span>
                  </button>
                </th>
                <th scope="col">League</th>
                <th v-for="column in team.teamStats[teamStatsCategory].columns" :key="column.key" scope="col">
                  <button type="button" class="player-stats-sort-button" @click="toggleTeamStatsSort(column.key)">
                    {{ column.label }} <span>{{ teamStatsSortIndicator(column.key) }}</span>
                  </button>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(entry, index) in sortedTeamStats()" :key="entry.team.id">
                <th scope="row" :class="{ 'is-current-team': entry.team.id === team.id }"><span class="team-stats-rank">{{ index + 1 }}</span>{{ entry.team.name }}</th>
                <td :class="{ 'is-current-team': entry.team.id === team.id }">{{ entry.team.league || '—' }}</td>
                <td v-for="column in team.teamStats[teamStatsCategory].columns" :key="column.key" :class="{ 'is-current-team': entry.team.id === team.id }">
                  {{ formatPlayerStatValue(teamStatsCategory, column.key, entry.stats[column.key]) }}
                </td>
              </tr>
              <tr v-if="!sortedTeamStats().length">
                <td :colspan="team.teamStats[teamStatsCategory].columns.length + 2">No team stats are stored for {{ team.teamStats.season }}.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <div v-show="selectedProfileTab === 'opponent'" id="team-profile-panel-opponent" class="team-profile-tab-panel"
        role="tabpanel" aria-labelledby="team-profile-tab-opponent" data-test="team-profile-panel-opponent">

        <section class="team-panel opponent-prep" data-test="opponent-preparation">
          <header>
            <div>
              <p>Opponent preparation</p>
              <h2>Next series</h2>
            </div>
            <div class="opponent-report-actions">
              <span>{{ nextSeriesGames.length }} {{ nextSeriesGames.length === 1 ? 'game' : 'games' }}</span>
              <button type="button" :disabled="!nextOpponent || savingReport" data-test="save-opponent-report"
                @click="saveOpponentReport">
                {{ savingReport ? 'Generating…' : 'Save opponent report' }}
              </button>
            </div>
          </header>
          <p v-if="reportSaveError" class="opponent-report-error" role="alert">{{ reportSaveError }}</p>

          <div v-if="nextOpponent" class="opponent-prep__overview">
            <div class="opponent-prep__identity">
              <span class="opponent-prep__logo">
                <img :src="teamLogoUrl(nextOpponent.mlb_id)" :alt="`${nextOpponent.name} logo`" />
              </span>
              <div>
                <small>Next opponent</small>
                <RouterLink :to="{ name: 'team-profile', params: { id: nextOpponent.id } }">
                  {{ nextOpponent.name }}
                </RouterLink>
                <p>{{ nextSeriesDateLabel }} · {{ seriesLocation(nextSeriesGames[0]) }}</p>
              </div>
            </div>
            <div class="opponent-prep__venue">
              <small>Series venue</small>
              <strong>{{ nextSeriesGames[0].venueName || 'Venue TBD' }}</strong>
            </div>
          </div>

          <div v-if="nextSeriesGames.length" class="probable-starters" aria-label="Probable starters">
            <article v-for="game in nextSeriesGames" :key="game.id" :data-test="`opponent-series-game-${game.id}`">
              <header>
                <div><strong>{{ formatDate(game.officialDate, true) }}</strong><span>{{ seriesLocation(game) }}</span>
                </div>
                <RouterLink :to="{ name: 'game-summary', params: { id: game.id } }">Game preview →</RouterLink>
              </header>
              <div class="starter-matchup">
                <div>
                  <small>{{ team.abbreviation }} probable</small>
                  <RouterLink v-if="probablePitcher(game)?.id"
                    :to="{ name: 'player-profile', params: { id: probablePitcher(game).id } }"
                    :data-test="`team-probable-${game.id}`">
                    {{ probablePitcher(game).full_name }}
                  </RouterLink>
                  <strong v-else>{{ probablePitcher(game)?.full_name || 'TBD' }}</strong>
                </div>
                <span aria-hidden="true">vs</span>
                <div>
                  <small>{{ nextOpponent.abbreviation }} probable</small>
                  <RouterLink v-if="opponentProbablePitcher(game)?.id"
                    :to="{ name: 'player-profile', params: { id: opponentProbablePitcher(game).id } }"
                    :data-test="`opponent-probable-${game.id}`">
                    {{ opponentProbablePitcher(game).full_name }}
                  </RouterLink>
                  <strong v-else>{{ opponentProbablePitcher(game)?.full_name || 'TBD' }}</strong>
                </div>
              </div>
            </article>
          </div>
          <p v-else class="team-empty">No upcoming opponent is stored for this season.</p>

          <section v-if="nextOpponent && opponentPrep.recentPerformance" class="opponent-recent"
            data-test="opponent-recent-performance">
            <header>
              <div><small>Recent opponent performance</small><strong>Last {{ opponentPrep.recentPerformance.games }}
                  games</strong></div>
            </header>
            <dl>
              <div>
                <dt>Record</dt>
                <dd>{{ opponentPrep.recentPerformance.wins }}–{{ opponentPrep.recentPerformance.losses }}</dd>
              </div>
              <div>
                <dt>Runs / G</dt>
                <dd>{{ formatDecimal(opponentPrep.recentPerformance.runs_per_game, 2) }}</dd>
              </div>
              <div>
                <dt>OPS</dt>
                <dd>{{ formatDecimal(opponentPrep.recentPerformance.ops) }}</dd>
              </div>
              <div>
                <dt>ERA</dt>
                <dd>{{ formatTwoDecimalPitchingRate(opponentPrep.recentPerformance.era) }}</dd>
              </div>
            </dl>
          </section>

          <section v-for="starter in opponentPrep.probableStarters || []" :key="starter.player.id"
            class="starter-scouting" :data-test="`starter-scouting-${starter.player.id}`">
            <header>
              <div>
                <small>Probable starter scouting</small>
                <RouterLink :to="{ name: 'player-profile', params: { id: starter.player.id } }">{{
                  starter.player.full_name }}</RouterLink>
              </div>
              <span>{{ starter.throws || '—' }}HP · {{ starter.sampleSize }} tracked pitches</span>
            </header>

            <div class="scouting-layout">
              <div class="scouting-table-wrap">
                <h4>Repertoire</h4>
                <table>
                  <thead>
                    <tr>
                      <th>Pitch</th>
                      <th>Usage</th>
                      <th>Velo</th>
                      <th>H-break</th>
                      <th>V-break</th>
                      <th>Evidence</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="pitch in starter.repertoire" :key="pitch.pitch_type">
                      <th>{{ pitch.pitch_name }} <small>{{ pitch.pitch_type }}</small></th>
                      <td>{{ formatDecimal(pitch.usage_percentage, 1) }}%</td>
                      <td>{{ formatDecimal(pitch.average_velocity, 1) }} mph</td>
                      <td>{{ formatDecimal(pitch.horizontal_break, 1) }} in</td>
                      <td>{{ formatDecimal(pitch.vertical_break, 1) }} in</td>
                      <td>
                        <RouterLink v-for="item in pitch.evidence" :key="item.pitch_id" class="evidence-link"
                          :to="{ name: 'game-summary', params: { id: item.game_id }, hash: `#pitch-${item.pitch_id}` }">
                          {{ evidenceLabel(item) }}</RouterLink>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>

              <div class="scouting-side">
                <article>
                  <h4>Handedness splits</h4>
                  <dl>
                    <div v-for="split in starter.handednessSplits" :key="split.batter_hand">
                      <dt>vs {{ split.batter_hand }}HB</dt>
                      <dd>{{ split.plate_appearances }} PA · K {{ formatDecimal(split.strikeout_rate, 1) }}% · Whiff {{
                        formatDecimal(split.whiff_rate, 1) }}%</dd>
                      <RouterLink v-if="split.evidence[0]" class="evidence-link"
                        :to="{ name: 'game-summary', params: { id: split.evidence[0].game_id }, hash: `#plate-appearance-${split.evidence[0].plate_appearance_id}` }">
                        View supporting PA →</RouterLink>
                    </div>
                  </dl>
                </article>
                <article>
                  <h4>Recent changes</h4>
                  <ul v-if="starter.recentChanges.length">
                    <li v-for="change in starter.recentChanges" :key="change.key">
                      <span>{{ change.label }}</span><strong
                        :class="{ 'is-up': change.change > 0, 'is-down': change.change < 0 }">{{
                          signedChange(change.change, change.unit) }}</strong>
                      <RouterLink v-if="change.evidence[0]" class="evidence-link"
                        :to="{ name: 'game-summary', params: { id: change.evidence[0].game_id }, hash: `#pitch-${change.evidence[0].pitch_id}` }">
                        Supporting pitch →</RouterLink>
                    </li>
                  </ul>
                  <p v-else>At least 200 tracked pitches are needed for recent-change comparisons.</p>
                </article>
              </div>
            </div>
          </section>

          <section class="opponent-report-history" data-test="opponent-report-history">
            <header>
              <div><small>Saved intelligence</small><strong>Opponent reports</strong></div>
              <span>{{ team.opponentReports.length }} saved</span>
            </header>
            <div v-if="team.opponentReports.length" class="opponent-report-list">
              <RouterLink v-for="report in team.opponentReports" :key="report.id"
                :to="{ name: 'opponent-report', params: { id: report.id } }"
                :data-test="`opponent-report-${report.id}`">
                <span>
                  <strong>{{ report.title }}</strong>
                  <small>Generated {{ formatTimestamp(report.generatedAt) }}</small>
                </span>
                <em>{{ report.probableStarterCount }} {{ report.probableStarterCount === 1 ? 'starter' : 'starters' }}
                  →</em>
              </RouterLink>
            </div>
            <p v-else>No reports saved for {{ team.season }} yet.</p>
          </section>
        </section>

      </div>

      <div v-show="selectedProfileTab === 'lineup'" id="team-profile-panel-lineup" class="team-profile-tab-panel"
        role="tabpanel" aria-labelledby="team-profile-tab-lineup" data-test="team-profile-panel-lineup">
        <section class="team-panel lineup-scenarios" data-test="lineup-scenarios">
          <header>
            <div>
              <p>Lineup planner</p>
              <h2>Lineup scenarios</h2>
            </div>
            <span>9 hitters · defensive coverage required</span>
          </header>
          <div class="lineup-scenarios__intro">
            <p>Build a DH lineup from the active roster. Saving checks batting order, duplicate players, position
              coverage, and roster availability.</p>
            <button type="button" data-test="populate-lineup" @click="populateLineup">Start with active roster</button>
          </div>
          <div class="lineup-scenarios__fields">
            <label>Scenario name<input v-model="lineupName" type="text"
                placeholder="e.g. vs RHP — series opener" /></label>
            <label>Notes<input v-model="lineupNotes" type="text" placeholder="Optional game-plan notes" /></label>
          </div>
          <fieldset class="lineup-evaluation" data-test="lineup-evaluation-inputs">
            <legend>Evaluation context</legend>
            <label>Opponent<select v-model="lineupEvaluation.opponent" data-test="lineup-opponent-select">
                <option value="">Choose team</option>
                <option v-for="teamOption in opponentTeamOptions" :key="teamOption.id" :value="teamOption.name">
                  {{ teamOption.abbreviation }} · {{ teamOption.name }}
                </option>
              </select></label>
            <label>Opponent strength (0–100)<input v-model.number="lineupEvaluation.opponentStrength" type="number"
                min="0" max="100" /></label>
            <label>Park factor<input v-model.number="lineupEvaluation.parkFactor" type="number" min="80"
                max="120" /></label>
            <label>Pitcher hand<select v-model="lineupEvaluation.pitcherHand">
                <option value="R">RHP</option>
                <option value="L">LHP</option>
              </select></label>
            <label>Recent performance (0–100)<input v-model.number="lineupEvaluation.recentPerformance" type="number"
                min="0" max="100" /></label>
            <label>Reliability (0–100)<input v-model.number="lineupEvaluation.reliability" type="number" min="0"
                max="100" /></label>
          </fieldset>
          <fieldset class="lineup-decision" data-test="lineup-decision-support">
            <legend>Decision support</legend>
            <label v-for="(weight, key) in lineupDecision.weights" :key="key">{{ key }} weight (%)<input
                v-model.number="lineupDecision.weights[key]" type="number" min="0" max="100" /></label>
            <label>Alternatives<input v-model.number="lineupDecision.alternativeCount" type="number" min="0"
                max="5" /></label>
            <label class="lineup-decision__wide">Required starters
              <select v-model="lineupDecision.requiredStarterIds" multiple>
                <option v-for="membership in lineupPlayers" :key="membership.player.id"
                  :value="String(membership.player.id)">{{ membership.player.fullName }}</option>
              </select>
            </label>
            <label class="lineup-decision__wide">Exclude / unavailable players
              <select v-model="lineupDecision.excludedPlayerIds" multiple>
                <option v-for="membership in lineupPlayers" :key="membership.player.id"
                  :value="String(membership.player.id)">{{ membership.player.fullName }}</option>
              </select>
            </label>
            <button type="button" :disabled="recommendingLineup" data-test="recommend-lineup"
              @click="recommendLineup">{{ recommendingLineup ? 'Recommending…' : 'Recommend batting order' }}</button>
          </fieldset>
          <div class="lineup-grid" role="table" aria-label="Lineup scenario editor">
            <div class="lineup-grid__header" role="row">
              <span>Order</span><span>Player</span><span>Defense</span><span>Lock</span></div>
            <label v-for="row in lineupRows" :key="row.battingSlot" class="lineup-row"
              :data-test="`lineup-row-${row.battingSlot}`">
              <strong>{{ row.battingSlot }}</strong>
              <select v-model="row.playerId" :aria-label="`Batting slot ${row.battingSlot} player`">
                <option value="">Choose player</option>
                <option v-for="membership in lineupPlayers" :key="membership.player.id"
                  :value="String(membership.player.id)">
                  {{ membership.player.fullName }} · {{ membership.primaryPosition || '—' }}
                </option>
              </select>
              <select v-model="row.defensivePosition"
                :aria-label="`Batting slot ${row.battingSlot} defensive position`">
                <option value="">Position</option>
                <option v-for="position in lineupPositions" :key="position" :value="position">{{ position }}</option>
              </select>
              <input v-model="row.lockOrder" type="checkbox" :aria-label="`Lock batting slot ${row.battingSlot}`" />
            </label>
          </div>
          <p v-if="lineupError" class="lineup-scenarios__error" role="alert">{{ lineupError }}</p>
          <footer class="lineup-scenarios__footer">
            <span>{{ lineupPlayers.length }} active players available</span>
            <button type="button" :disabled="savingLineup" data-test="save-lineup-scenario" @click="saveLineupScenario">
              {{ savingLineup ? 'Checking constraints…' : 'Save lineup scenario' }}
            </button>
          </footer>
          <div v-if="team.lineupScenarios.length" class="lineup-scenario-history">
            <strong>Saved scenarios · score comparison</strong>
            <div class="lineup-score-comparison" data-test="lineup-score-comparison">
              <article v-for="scenario in team.lineupScenarios" :key="scenario.id">
                <div><strong>{{ scenario.name }}</strong><span>{{ scenario.totalScore ?? '—' }}/100</span></div>
                <small>
                  Opponent {{ scenario.scoreBreakdown?.opponent ?? '—' }} ·
                  Park {{ scenario.scoreBreakdown?.park ?? '—' }} ·
                  Platoon {{ scenario.scoreBreakdown?.platoon ?? '—' }} ·
                  Recent {{ scenario.scoreBreakdown?.recent_performance ?? '—' }} ·
                  Reliability {{ scenario.scoreBreakdown?.reliability ?? '—' }}
                </small>
                <small>Weights: 20% opponent · 15% park · 25% platoon · 20% recent · 20% reliability</small>
                <RouterLink :to="{ name: 'lineup-scenario', params: { id: scenario.id } }">Open scenario →</RouterLink>
              </article>
            </div>
            <ul>
              <li v-for="scenario in team.lineupScenarios" :key="scenario.id">
                <RouterLink :to="{ name: 'lineup-scenario', params: { id: scenario.id } }">{{ scenario.name }}
                </RouterLink>
                <span>{{ formatDate(scenario.scenarioDate, true) }} · {{ scenario.entryCount }} players</span>
              </li>
            </ul>
          </div>
        </section>

      </div>

      <div v-show="selectedProfileTab === 'overview'" id="team-profile-panel-overview" class="team-profile-tab-panel"
        role="tabpanel" aria-labelledby="team-profile-tab-overview" data-test="team-profile-panel-overview">
        <TeamLeadersCard :leaders="team.teamLeaders" :season="team.season" />

        <section class="team-panel performance-panel" data-test="team-performance-dashboard">
          <header>
            <div>
              <p>Daily analytics</p>
              <h2>Team performance dashboard</h2>
            </div>
            <span>Built from precomputed daily tables</span>
          </header>

          <div v-if="dashboard.analyticsCoverage?.complete === false" class="analytics-coverage-warning"
            data-test="analytics-coverage-warning">
            <strong>Incomplete pitching coverage</strong>
            <span>
              {{ dashboard.analyticsCoverage.missing_game_count }} of {{
                dashboard.analyticsCoverage.completed_game_count }} completed games
              {{ dashboard.analyticsCoverage.missing_game_count === 1 ? 'is' : 'are' }} missing pitching details. Season
              rankings may be incomplete.
            </span>
          </div>

          <p class="ranking-scale-note"><i aria-hidden="true"></i> Longer bars indicate a stronger league rank; the #1
            team fills the scale.</p>

          <div class="ranking-grid" data-test="team-ranking-cards">
            <article v-for="group in rankingGroups" :key="group.key" class="ranking-card"
              :data-test="`${group.key}-ranking-card`">
              <header class="ranking-card__heading">
                <h3>{{ group.title }}</h3>
                <span>Rank</span>
              </header>
              <div class="ranking-card__metrics">
                <div v-for="metric in group.metrics" :key="metric.key" class="ranking-row"
                  :data-test="`${group.key}-ranking-${metric.key}`">
                  <strong class="ranking-row__label">{{ metric.label }}</strong>
                  <div class="ranking-bar" role="progressbar"
                    :aria-label="`${group.title}: ${metric.label} ${formatRank(metric.entry)} of ${dashboard.rankings?.context?.total_teams || 30}`"
                    :aria-valuenow="rankingBarPercent(metric.entry)" aria-valuemin="0" aria-valuemax="100">
                    <i class="ranking-bar__fill" :style="{ width: `${rankingBarPercent(metric.entry)}%` }"></i>
                    <span class="ranking-bar__value"
                      :class="{ 'ranking-bar__value--outside': rankingBarPercent(metric.entry) < 24 }"
                      :style="{ left: `${rankingBarPercent(metric.entry)}%` }">
                      {{ metric.value }}
                    </span>
                  </div>
                  <b class="ranking-row__rank">{{ formatRank(metric.entry) }}</b>
                </div>
              </div>
            </article>
          </div>

          <div class="performance-grid performance-grid--details">

            <article>
              <h3>Recent form</h3>
              <dl>
                <div v-for="window in ['7', '15', '30']" :key="window">
                  <dt>Last {{ window }} games</dt>
                  <dd>
                    {{ dashboard.recentForm?.[window]?.wins || 0 }}-{{ dashboard.recentForm?.[window]?.losses || 0 }} ·
                    HR {{ formatInteger(dashboard.recentForm?.[window]?.home_runs) }} ·
                    R/G {{ formatDecimal(dashboard.recentForm?.[window]?.runs_per_game, 2) }} ·
                    OPS {{ formatDecimal(dashboard.recentForm?.[window]?.ops) }} ·
                    ERA {{ formatTwoDecimalPitchingRate(dashboard.recentForm?.[window]?.era) }}
                  </dd>
                </div>
              </dl>
            </article>

            <article>
              <h3>Home / road</h3>
              <dl>
                <div>
                  <dt>Home</dt>
                  <dd>{{ dashboard.homeRoadSplits?.home?.wins || 0 }}-{{ dashboard.homeRoadSplits?.home?.losses || 0 }}
                    · RD {{ dashboard.homeRoadSplits?.home?.run_differential || 0 }}</dd>
                </div>
                <div>
                  <dt>Road</dt>
                  <dd>{{ dashboard.homeRoadSplits?.road?.wins || 0 }}-{{ dashboard.homeRoadSplits?.road?.losses || 0 }}
                    · RD {{ dashboard.homeRoadSplits?.road?.run_differential || 0 }}</dd>
                </div>
              </dl>
            </article>

            <article>
              <h3>Platoon splits</h3>
              <dl>
                <div>
                  <dt>Offense vs LHP</dt>
                  <dd>K {{ formatPercent(dashboard.platoonSplits?.offense?.vs_left?.strikeout_rate) }} · EV {{
                    formatDecimal(dashboard.platoonSplits?.offense?.vs_left?.average_exit_velocity, 1) }}</dd>
                </div>
                <div>
                  <dt>Offense vs RHP</dt>
                  <dd>K {{ formatPercent(dashboard.platoonSplits?.offense?.vs_right?.strikeout_rate) }} · EV {{
                    formatDecimal(dashboard.platoonSplits?.offense?.vs_right?.average_exit_velocity, 1) }}</dd>
                </div>
                <div>
                  <dt>Pitching vs LHB</dt>
                  <dd>K {{ formatPercent(dashboard.platoonSplits?.pitching?.vs_left?.strikeout_rate) }} · Velo {{
                    formatDecimal(dashboard.platoonSplits?.pitching?.vs_left?.average_velocity, 1) }}</dd>
                </div>
                <div>
                  <dt>Pitching vs RHB</dt>
                  <dd>K {{ formatPercent(dashboard.platoonSplits?.pitching?.vs_right?.strikeout_rate) }} · Velo {{
                    formatDecimal(dashboard.platoonSplits?.pitching?.vs_right?.average_velocity, 1) }}</dd>
                </div>
              </dl>
            </article>

            <article>
              <h3>Starter / bullpen</h3>
              <dl>
                <div>
                  <dt>Starters</dt>
                  <dd>{{ formatDecimal(dashboard.starterBullpen?.starters?.innings_pitched, 1) }} IP · ERA {{
                    formatTwoDecimalPitchingRate(dashboard.starterBullpen?.starters?.era) }} · WHIP {{
                      formatTwoDecimalPitchingRate(dashboard.starterBullpen?.starters?.whip) }}</dd>
                </div>
                <div>
                  <dt>Bullpen</dt>
                  <dd>{{ formatDecimal(dashboard.starterBullpen?.bullpen?.innings_pitched, 1) }} IP · ERA {{
                    formatTwoDecimalPitchingRate(dashboard.starterBullpen?.bullpen?.era) }} · WHIP {{
                      formatTwoDecimalPitchingRate(dashboard.starterBullpen?.bullpen?.whip) }}</dd>
                </div>
              </dl>
            </article>

            <article>
              <h3>One-run games</h3>
              <dl>
                <div>
                  <dt>Record</dt>
                  <dd>{{ dashboard.oneRunPerformance?.wins || 0 }}-{{ dashboard.oneRunPerformance?.losses || 0 }}</dd>
                </div>
                <div>
                  <dt>Win rate</dt>
                  <dd>{{ formatPercent(dashboard.oneRunPerformance?.winning_percentage) }}</dd>
                </div>
                <div>
                  <dt>Games</dt>
                  <dd>{{ dashboard.oneRunPerformance?.games || 0 }}</dd>
                </div>
              </dl>
            </article>
          </div>

          <div class="signals-grid">
            <article>
              <h3>Current strengths</h3>
              <ul>
                <li v-for="entry in dashboard.strengths || []" :key="entry">{{ entry }}</li>
              </ul>
            </article>
            <article>
              <h3>Areas of concern</h3>
              <ul>
                <li v-for="entry in dashboard.concerns || []" :key="entry">{{ entry }}</li>
              </ul>
            </article>
          </div>
        </section>

        <div class="team-schedule-grid">
          <section class="team-panel">
            <header>
              <div>
                <p>Next on the calendar</p>
                <h2>Upcoming games</h2>
              </div><span>{{ team.upcomingGames.length }} shown</span>
            </header>
            <ol v-if="team.upcomingGames.length" class="game-list" data-test="upcoming-games">
              <li v-for="game in team.upcomingGames" :key="game.id">
                <time>{{ formatDate(game.officialDate) }}</time>
                <div><strong>{{ isHome(game) ? 'vs' : '@' }} {{ opponent(game).abbreviation }}</strong><span>{{
                  game.venueName
                  || game.detailedStatus || 'Venue TBD' }}</span></div>
                <small>{{ probablePitcher(game)?.full_name || 'Probable TBD' }}</small>
              </li>
            </ol>
            <p v-else class="team-empty">No upcoming games are stored for this season.</p>
          </section>

          <section class="team-panel">
            <header>
              <div>
                <p>Latest finals</p>
                <h2>Recent results</h2>
              </div><span>{{ team.recentGames.length }} shown</span>
            </header>
            <ol v-if="team.recentGames.length" class="game-list" data-test="recent-games">
              <li v-for="game in team.recentGames" :key="game.id" class="game-list__linked">
                <RouterLink class="game-result-link" :to="{ name: 'game-summary', params: { id: game.id } }">
                  <time>{{ formatDate(game.officialDate) }}</time>
                  <div><strong>{{ isHome(game) ? 'vs' : '@' }} {{ opponent(game).abbreviation }}</strong><span>{{
                      teamScore(game) }}–{{ opponentScore(game) }}</span></div>
                  <b :class="`result result--${resultLabel(game).toLowerCase()}`">{{ resultLabel(game) }}</b>
                </RouterLink>
              </li>
            </ol>
            <p v-else class="team-empty">No completed games are stored for this season.</p>
          </section>
        </div>

      </div>

      <section v-show="selectedProfileTab === 'roster'" id="team-profile-panel-roster"
        class="team-panel roster-panel team-profile-tab-panel" role="tabpanel" aria-labelledby="team-profile-tab-roster"
        data-test="team-profile-panel-roster">
        <header>
          <div>
            <p>Dated roster state</p>
            <h2>{{ team.season }} roster</h2>
          </div>
          <div class="roster-view-controls">
            <div role="group" aria-label="Roster view">
              <button type="button" data-test="roster-view-active"
                :class="{ 'is-selected': selectedRosterView === 'active' }"
                :aria-pressed="selectedRosterView === 'active'" @click="selectedRosterView = 'active'">
                Active <span>{{ team.rosters.active.length }}</span>
              </button>
              <button type="button" data-test="roster-view-injured"
                :class="{ 'is-selected': selectedRosterView === 'injured' }"
                :aria-pressed="selectedRosterView === 'injured'" @click="selectedRosterView = 'injured'">
                IL <span>{{ injuredRoster.length }}</span>
              </button>
              <button type="button" data-test="roster-view-40man"
                :class="{ 'is-selected': selectedRosterView === 'fortyMan' }"
                :aria-pressed="selectedRosterView === 'fortyMan'" @click="selectedRosterView = 'fortyMan'">
                40-man <span>{{ team.rosters.fortyMan.length }}</span>
              </button>
            </div>
            <small>As of {{ formatDate(team.rosterAsOf, true) }}</small>
          </div>
        </header>
        <section v-if="depthChartGroups.length" class="depth-chart" data-test="team-depth-chart"
          aria-labelledby="team-depth-chart-heading">
          <div class="depth-chart__intro">
            <div>
              <p>Position coverage</p>
              <h3 id="team-depth-chart-heading">Depth chart</h3>
            </div>
            <small>Based on the selected roster view</small>
          </div>
          <div class="depth-chart__grid">
            <article v-for="group in depthChartGroups" :key="group.key" class="depth-chart__group">
              <header>
                <div>
                  <span class="depth-chart__role">{{ group.role }}</span>
                  <h4>{{ group.label }}</h4>
                </div>
                <b>{{ group.playerCount }}</b>
              </header>
              <div v-for="lane in group.lanes" :key="lane.position" class="depth-chart__lane">
                <span class="depth-chart__position">{{ lane.position }}</span>
                <ol>
                  <li v-for="membership in lane.players" :key="membership.id">
                    <span class="depth-chart__rank">{{ lane.players.indexOf(membership) + 1 }}</span>
                    <RouterLink :to="{ name: 'player-profile', params: { id: membership.player.id } }">
                      {{ membership.player.fullName }}
                    </RouterLink>
                    <span v-if="membership.injured" class="depth-chart__status">IL</span>
                  </li>
                </ol>
              </div>
            </article>
          </div>
        </section>
        <div v-if="displayedRoster.length" class="roster-table-wrap" data-test="team-roster">
          <table>
            <thead>
              <tr>
                <th>Player</th>
                <th>#</th>
                <th>Pos</th>
                <th>Status</th>
                <th>Member since</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="membership in displayedRoster" :key="membership.id">
                <td>
                  <RouterLink class="roster-player"
                    :to="{ name: 'player-profile', params: { id: membership.player.id } }">
                    <span class="roster-headshot">
                      <img v-if="membership.player.headshotUrl" :src="membership.player.headshotUrl"
                        :alt="`${membership.player.fullName} headshot`" />
                      <b v-else>{{ membership.player.firstName?.[0] }}{{ membership.player.lastName?.[0] }}</b>
                    </span>
                    <strong>{{ membership.player.fullName }}</strong>
                  </RouterLink>
                </td>
                <td>{{ membership.jerseyNumber || '—' }}</td>
                <td>{{ membership.primaryPosition || '—' }}</td>
                <td><span class="roster-status" :class="{ 'roster-status--injured': membership.injured }">{{
                  membership.statusDescription || titleize(membership.rosterStatus) }}</span></td>
                <td>{{ formatDate(membership.startsOn, true) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p v-else class="team-empty">No players are stored for this team's {{ rosterViewLabel.toLowerCase() }}.</p>
      </section>

      <section v-show="selectedProfileTab === 'schedule'" id="team-profile-panel-schedule"
        class="team-panel schedule-panel team-profile-tab-panel" role="tabpanel"
        aria-labelledby="team-profile-tab-schedule" data-test="team-profile-panel-schedule">
        <header class="schedule-calendar__header">
          <div>
            <p>Season schedule</p>
            <h2 data-test="schedule-month-label">{{ scheduleMonthLabel }}</h2>
          </div>
          <nav class="schedule-month-nav" aria-label="Schedule month navigation">
            <button type="button" :disabled="!canShowPreviousScheduleMonth" aria-label="Previous month"
              data-test="schedule-previous-month" @click="shiftScheduleMonth(-1)">‹</button>
            <button type="button" :disabled="!canShowNextScheduleMonth" aria-label="Next month"
              data-test="schedule-next-month" @click="shiftScheduleMonth(1)">›</button>
          </nav>
        </header>

        <div v-if="team.scheduleGames.length" class="schedule-calendar-scroll">
          <div class="schedule-calendar" data-test="team-schedule-calendar">
            <div class="schedule-calendar__weekdays" aria-hidden="true">
              <span v-for="weekday in SCHEDULE_WEEKDAYS" :key="weekday">{{ weekday }}</span>
            </div>
            <div class="schedule-calendar__grid">
              <div v-for="(day, index) in scheduleCalendarDays" :key="day?.date || 'empty-' + index"
                class="schedule-day" :class="{ 'schedule-day--empty': !day, 'schedule-day--today': day && isToday(day.date) }">
                <template v-if="day">
                  <time :datetime="day.date">{{ day.day }}</time>
                  <div class="schedule-day__games">
                    <RouterLink v-for="game in day.games" :key="game.id"
                      :to="{ name: 'game-summary', params: { id: game.id } }" class="schedule-game"
                      :class="{ 'schedule-game--final': teamScore(game) !== null && teamScore(game) !== undefined }"
                      :data-test="'schedule-game-' + game.id"
                      :aria-label="formatDate(game.officialDate, true) + ', ' + (isHome(game) ? 'vs ' : 'at ') + opponent(game).name + ', ' + scheduleGameLabel(game)">
                      <img v-if="scheduleOpponentLogo(game)" :src="scheduleOpponentLogo(game)"
                        :alt="opponent(game).name + ' logo'" />
                      <span class="schedule-game__opponent">
                        <small>{{ isHome(game) ? 'vs' : '@' }}</small>
                        <strong>{{ opponent(game).team_name || opponent(game).name }}</strong>
                      </span>
                      <b>{{ scheduleGameLabel(game) }}</b>
                      <small v-if="game.gameNumber && game.doubleheader && game.doubleheader !== 'N'">Game {{ game.gameNumber }}</small>
                    </RouterLink>
                  </div>
                </template>
              </div>
            </div>
          </div>
        </div>
        <p v-else class="team-empty">No games are stored for the {{ team.season }} season.</p>
      </section>

      <footer class="team-freshness">
        <span>Schedule synced {{ formatTimestamp(team.sourceMetadata.scheduleLastSyncedAt) }}</span>
        <span>Roster synced {{ formatTimestamp(team.sourceMetadata.rosterLastSyncedAt) }}</span>
      </footer>
    </template>
  </main>
</template>

<style scoped>
.team-profile-shell {
  width: min(1500px, calc(100% - 2rem));
  margin: 0 auto;
  padding: 2.2rem 0 5rem;
  color: #10263d;
}

.team-back {
  color: #8d392e;
  font-size: .82rem;
  font-weight: 800;
  text-decoration: none;
}

.team-hero {
  position: relative;
  isolation: isolate;
  display: grid;
  grid-template-columns: 180px 1fr auto;
  gap: 2rem;
  align-items: center;
  margin-top: 1rem;
  padding: 1.35rem 2rem 0;
  border: 1px solid color-mix(in srgb, var(--profile-team-primary) 60%, #10263d);
  border-radius: 28px;
  color: #fffdf7;
  background: linear-gradient(124deg, var(--profile-team-primary), var(--profile-team-secondary));
  box-shadow: 0 20px 58px rgba(64, 43, 20, .11);
}

.team-hero__title {
  grid-column: 1 / -1;
  margin: 0 0 .1rem 2.65rem;
  color: rgba(255, 253, 247, .72);
  font-size: .78rem;
  font-weight: 900;
  letter-spacing: .16em;
  line-height: 1;
  text-transform: uppercase;
}

.team-hero__title span {
  color: rgba(255, 253, 247, .48);
  font-size: 1em;
  letter-spacing: .08em;
}

.team-hero__pattern {
  position: absolute;
  z-index: -1;
  top: -5rem;
  right: -1rem;
  width: min(56%, 720px);
  height: 150%;
  color: var(--profile-team-accent);
  opacity: .12;
  transform: rotate(-7deg);
  pointer-events: none;
}

.team-hero__pattern path,
.team-hero__pattern circle {
  fill: none;
  stroke: currentColor;
  stroke-width: 6;
}

.team-hero__pattern path:first-child {
  fill: currentColor;
  opacity: .24;
  stroke: none;
}

.team-logo {
  display: grid;
  place-items: center;
  width: 160px;
  height: 160px;
  border-radius: 50%;
  background: rgba(255, 255, 255, .94);
  box-shadow: inset 0 0 0 1px #dedbd2;
}

.team-logo img {
  width: 118px;
  height: 118px;
  object-fit: contain;
}

.team-panel header p {
  margin: 0;
  color: #a93627;
  font-size: .72rem;
  font-weight: 800;
  letter-spacing: .16em;
  text-transform: uppercase;
}

.team-hero__footer {
  display: grid;
  grid-column: 1 / -1;
  grid-template-columns: minmax(0, 1fr);
  gap: 1rem;
  align-items: center;
  margin: 0 -2rem;
  padding: .7rem 2rem 1rem;
  border-radius: 0 0 27px 27px;
  background: #fffdf7;
}

.team-explore-links {
  display: flex;
  flex-wrap: wrap;
  gap: .7rem 1rem;
  align-items: center;
}

.team-explore-links__label {
  color: #65747e;
  font-size: .67rem;
  font-weight: 900;
  letter-spacing: .08em;
  text-transform: uppercase;
}

.team-external-links { display: flex; flex-wrap: wrap; gap: .5rem; }
.team-external-links a { display: inline-flex; align-items: center; gap: .3rem; padding: .28rem .62rem; border: 1px solid rgba(83,101,117,.12); border-radius: 999px; color: #526779; background: #eef2f5; box-shadow: inset 0 -1px 0 rgba(255,255,255,.12); font-size: .78rem; font-weight: 400; line-height: 1; text-decoration: none; transition: transform .16s ease, background .16s ease, color .16s ease; }
.team-external-links a:hover { color: #fffaf0; background: #526779; transform: translateY(-1px); }
.team-external-links a:focus-visible { outline: 3px solid rgba(31,111,235,.32); outline-offset: 2px; }
.team-external-links a span { color: inherit; font-size: inherit; }

.team-identity h1 {
  margin: .2rem 0;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: clamp(3.5rem, 7vw, 7rem);
  line-height: .9;
  color: #fffdf7;
  text-transform: uppercase;
}

.team-identity span {
  color: rgba(255, 253, 247, .78);
  font-size: 1.05rem;
}

.season-picker__label {
  display: block;
  margin-bottom: .35rem;
  color: rgba(255, 253, 247, .72);
  font-size: .72rem;
  font-weight: 800;
  text-transform: uppercase;
}

.season-picker select {
  min-width: 120px;
  padding: .7rem .9rem;
  border: 1px solid #c9c8c0;
  border-radius: 12px;
  color: #10263d;
  background: white;
  font: inherit;
  font-weight: 800;
}

.season-picker select:disabled {
  cursor: wait;
  opacity: .65;
}

.season-loading {
  display: flex;
  gap: .45rem;
  align-items: center;
  margin-top: .55rem;
  color: #435767;
  font-size: .72rem;
  font-weight: 750;
  white-space: nowrap;
}

.season-loading i {
  display: block;
  width: 14px;
  height: 14px;
  border: 2px solid rgba(16, 38, 61, .2);
  border-top-color: #a93627;
  border-radius: 50%;
  animation: team-season-spin .7s linear infinite;
}

@keyframes team-season-spin {
  to {
    transform: rotate(360deg);
  }
}

@media (prefers-reduced-motion: reduce) {
  .season-loading i {
    animation-duration: 1.6s;
  }
}

.team-summary {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0;
  grid-column: 1 / -1;
  margin: 0 -2rem;
  line-height: 1.2;
  padding: 1.2rem 2rem .65rem;
  color: #10263d;
  background: #fffdf7;
}

.team-summary article,
.team-panel {
  border: 1px solid #d9d7ce;
  border-radius: 24px;
  background: rgba(255, 255, 255, .72);
}

.team-summary article {
  min-width: 0;
  padding: 0 .8rem;
  border-width: 0 1px 0 0;
  border-radius: 0;
  background: transparent;
  text-align: center;
}

.team-summary article:first-child { padding-left: 0; }
.team-summary article:last-child { padding-right: 0; border-right: 0; }

.team-summary span,
.team-summary small,
.team-summary strong {
  display: block;
}

.team-summary span {
  color: #65747e;
  font-size: .67rem;
  font-weight: 800;
  letter-spacing: .1em;
  text-transform: uppercase;
  margin-bottom: .25rem;
}

.team-summary strong {
  margin: .25rem 0;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: clamp(1.75rem, 3.2vw, 3.1rem);
  line-height: .9;
}

.team-summary .summary-date {
  font-family: inherit;
  font-size: .92rem;
  line-height: 2.6rem;
}

.team-summary small {
  color: #69747c;
  font-size: .72rem;
}

.team-summary__record {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  text-align: left;
}

.team-summary__recent-records {
  display: grid;
  grid-template-columns: repeat(1, auto);
  gap: .7rem;
  margin: 0;
  text-align: right;
}

.team-summary__recent-records dt {
  color: #69747c;
  font-size: .58rem;
  font-weight: 800;
  letter-spacing: .08em;
  text-transform: uppercase;
  white-space: nowrap;
}

.team-summary__recent-records dd {
  margin: .2rem 0 0;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.05rem;
  font-weight: 900;
  white-space: nowrap;
}

.team-summary__leaders dl {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: .45rem;
  margin: .75rem 0 0;
}

.team-summary__leaders dt {
  color: #69747c;
  font-size: .85rem;
  font-weight: 900;
  letter-spacing: .08em;
}

.team-summary__leaders dd {
  margin: .18rem 0 0;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.5rem;
  font-weight: 900;
}

.team-summary__leaders dd small {
  display: block;
  margin-top: .08rem;
  color: #69747c;
  font-family: inherit;
  font-size: .85rem;
  font-weight: 800;
}

.player-stats-panel {
  margin-bottom: 1rem;
}

.player-stats-category + .player-stats-category {
  margin-top: 2rem;
}

.player-stats-category h3 {
  margin: 1.25rem 0 .75rem;
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.35rem;
  letter-spacing: .05em;
  text-transform: uppercase;
}

.player-stats-table-wrap {
  overflow-x: auto;
  border: 1px solid #d9d7ce;
  border-radius: 16px;
}

.player-stats-table {
  min-width: 1180px;
  font-variant-numeric: tabular-nums;
}

.player-stats-table th,
.player-stats-table td {
  white-space: nowrap;
}

.player-stats-sort-button {
  display: inline-flex;
  align-items: center;
  gap: .3rem;
  padding: .25rem .35rem;
  border: 0;
  color: inherit;
  background: transparent;
  font: inherit;
  font-weight: 900;
  cursor: pointer;
}

.player-stats-sort-button:hover,
.player-stats-sort-button:focus-visible {
  color: #a93627;
}

.player-stats-sort-button span {
  min-width: .7rem;
}

.player-stats-table thead th:not(:first-child),
.player-stats-table tbody td {
  text-align: right;
}

.player-stats-table tbody tr:nth-child(even) th,
.player-stats-table tbody tr:nth-child(even) td {
  background: #faf5ea;
}

.player-stats-player {
  display: inline-flex;
  align-items: center;
  gap: .65rem;
  color: #10263d;
  text-decoration: none;
}

.player-stats-player:hover {
  color: #a93627;
}

.player-stats-headshot {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  overflow: hidden;
  border-radius: 50%;
  color: #fff;
  background: #10263d;
  font-size: .65rem;
}

.player-stats-headshot img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  object-position: center 16%;
}

.team-stats-panel {
  margin-bottom: 1rem;
}

.team-stats-header {
  display: flex;
  align-items: end;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1rem;
}

.team-stats-header p {
  margin: 0 0 .3rem;
  color: #a93627;
  font-size: .68rem;
  font-weight: 900;
  letter-spacing: .12em;
  text-transform: uppercase;
}

.team-stats-header h2 {
  margin: 0;
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 2rem;
}

.team-stats-mode-toggle {
  display: inline-flex;
  gap: .2rem;
  padding: .2rem;
  border: 1px solid #d9d7ce;
  border-radius: 10px;
  background: #faf5ea;
}

.team-stats-mode-toggle button {
  padding: .55rem .8rem;
  border: 0;
  border-radius: 8px;
  color: #697680;
  background: transparent;
  font: inherit;
  font-weight: 800;
  cursor: pointer;
}

.team-stats-mode-toggle button.is-selected {
  color: #fff;
  background: #10263d;
}

.team-stats-table-wrap {
  max-height: 680px;
  overflow: auto;
}

.team-stats-table thead th {
  position: sticky;
  top: 0;
  z-index: 1;
  background: #f4f0e6;
}

.team-stats-table tbody th {
  text-align: left;
}

.team-stats-table tbody th.is-current-team,
.team-stats-table tbody td.is-current-team {
  font-weight: 800;
}

.team-stats-table tbody td,
.team-stats-table tbody th {
  padding-top: .65rem;
  padding-bottom: .65rem;
}

.team-stats-rank {
  display: inline-block;
  width: 2rem;
  color: #697680;
  font-size: .78rem;
  text-align: right;
  margin-right: .65rem;
}

.team-coming-soon { min-height: 260px; margin-bottom: 1rem; padding: 3rem 1.5rem; text-align: center; }
.team-coming-soon p { margin: 0; color: #a93627; font-size: .68rem; font-weight: 900; letter-spacing: .12em; text-transform: uppercase; }
.team-coming-soon h2 { margin: .35rem 0 .5rem; font-family: 'Avenir Next Condensed', sans-serif; font-size: 2.8rem; text-transform: uppercase; }
.team-coming-soon span { color: #697680; }

.team-profile-tabs {
  display: flex;
  gap: .45rem;
  margin: 0 0 1rem;
  overflow-x: auto;
  padding: .3rem;
  border: 1px solid #d9d7ce;
  border-radius: 16px;
  background: rgba(255, 250, 240, .72);
}

.team-profile-tabs button {
  display: inline-flex;
  gap: .45rem;
  align-items: center;
  justify-content: center;
  min-width: 130px;
  padding: .72rem 1rem;
  border: 0;
  border-radius: 12px;
  color: #5b6871;
  background: transparent;
  font: inherit;
  font-size: .78rem;
  font-weight: 900;
  letter-spacing: .06em;
  text-transform: uppercase;
  cursor: pointer;
}

.team-profile-tabs button span {
  display: grid;
  min-width: 22px;
  height: 22px;
  padding: 0 .35rem;
  place-items: center;
  border-radius: 999px;
  color: inherit;
  background: rgba(16, 38, 61, .09);
  font-size: .65rem;
}

.team-profile-tabs button.is-selected {
  color: #fffaf0;
  background: #10263d;
  box-shadow: 0 5px 14px rgba(16, 38, 61, .18);
}

.team-profile-tabs button.is-selected span {
  background: rgba(255, 255, 255, .16);
}

.team-profile-tab-panel:focus {
  outline: none;
}

.team-schedule-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}

.team-panel {
  padding: 1.35rem;
}

.schedule-panel {
  margin-bottom: 1rem;
  overflow: hidden;
  padding: 0;
  background: rgba(255, 253, 247, .94);
}

.schedule-calendar__header {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: center;
  padding: 1.25rem 1.35rem;
  border-bottom: 1px solid #d9d7ce;
}

.schedule-calendar__header p {
  margin: 0;
  color: #a93627;
  font-size: .68rem;
  font-weight: 900;
  letter-spacing: .12em;
  text-transform: uppercase;
}

.schedule-calendar__header h2 {
  margin: .15rem 0 0;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: clamp(2rem, 4vw, 3.2rem);
  text-transform: uppercase;
}

.schedule-month-nav {
  display: flex;
  gap: .45rem;
}

.schedule-month-nav button {
  display: grid;
  width: 44px;
  height: 40px;
  padding: 0;
  place-items: center;
  border: 1px solid rgba(16, 38, 61, .2);
  border-radius: 10px;
  color: #10263d;
  background: #fffdf8;
  font-size: 1.6rem;
  font-weight: 900;
  cursor: pointer;
}

.schedule-month-nav button:hover:not(:disabled) {
  color: #fffaf0;
  background: #10263d;
}

.schedule-month-nav button:disabled {
  opacity: .32;
  cursor: not-allowed;
}

.schedule-calendar-scroll {
  overflow-x: auto;
}

.schedule-calendar {
  min-width: 980px;
}

.schedule-calendar__weekdays {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
  color: #526572;
  background: #f1eee7;
  font-size: .72rem;
  font-weight: 900;
  letter-spacing: .08em;
  text-align: center;
  text-transform: uppercase;
}

.schedule-calendar__weekdays span {
  padding: .7rem .4rem;
  border-right: 1px solid #d9d7ce;
}

.schedule-calendar__weekdays span:last-child {
  border-right: 0;
}

.schedule-calendar__grid {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
  border-top: 1px solid #d9d7ce;
  border-left: 1px solid #d9d7ce;
}

.schedule-day {
  min-height: 168px;
  padding: .55rem;
  border-right: 1px solid #d9d7ce;
  border-bottom: 1px solid #d9d7ce;
  background: rgba(255, 255, 255, .76);
}

.schedule-day--empty {
  background: rgba(232, 235, 235, .42);
}

.schedule-day > time {
  display: grid;
  width: 28px;
  height: 28px;
  margin-bottom: .35rem;
  place-items: center;
  border: 1px solid transparent;
  border-radius: 50%;
  color: #485966;
  font-size: .78rem;
  font-weight: 850;
}

.schedule-day--today > time {
  border-color: #a93627;
  color: #fff;
  background: #a93627;
}

.schedule-day__games {
  display: grid;
  gap: .4rem;
}

.schedule-game {
  display: grid;
  grid-template-columns: 38px minmax(0, 1fr);
  gap: .12rem .45rem;
  align-items: center;
  padding: .5rem;
  border: 1px solid rgba(16, 38, 61, .1);
  border-radius: 11px;
  color: #10263d;
  background: rgba(241, 245, 247, .86);
  text-decoration: none;
  transition: border-color .16s ease, box-shadow .16s ease, transform .16s ease;
}

.schedule-game--final {
  background: rgba(255, 250, 240, .94);
}

.schedule-game:hover {
  border-color: rgba(169, 54, 39, .42);
  box-shadow: 0 6px 16px rgba(16, 38, 61, .1);
  transform: translateY(-1px);
}

.schedule-game > img {
  grid-row: 1 / span 3;
  width: 38px;
  height: 38px;
  object-fit: contain;
}

.schedule-game__opponent {
  display: flex;
  gap: .3rem;
  align-items: baseline;
  min-width: 0;
}

.schedule-game__opponent small {
  color: #7b858c;
  font-size: .64rem;
  font-weight: 900;
  text-transform: uppercase;
}

.schedule-game__opponent strong {
  overflow: hidden;
  font-size: .76rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.schedule-game > b {
  color: #5a6872;
  font-size: .7rem;
}

.schedule-game > small {
  grid-column: 2;
  color: #8b5b43;
  font-size: .6rem;
  font-weight: 800;
}

.opponent-prep {
  overflow: hidden;
  background: linear-gradient(135deg, rgba(255, 250, 240, .95), rgba(232, 239, 243, .88));
}

.lineup-scenarios {
  background: linear-gradient(135deg, rgba(237, 247, 240, .92), rgba(255, 252, 244, .96));
}

.lineup-scenarios__intro,
.lineup-scenarios__footer {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: center;
}

.lineup-scenarios__intro p {
  max-width: 700px;
  margin: 0;
  color: #526572;
  font-size: .84rem;
}

.lineup-scenarios button {
  padding: .55rem .8rem;
  border: 1px solid rgba(16, 38, 61, .18);
  border-radius: 999px;
  color: #173652;
  background: #fffdf7;
  font-size: .72rem;
  font-weight: 900;
  cursor: pointer;
}

.lineup-scenarios__footer button {
  border: 0;
  color: #fffaf0;
  background: #20543c;
}

.lineup-scenarios button:disabled {
  opacity: .5;
  cursor: not-allowed;
}

.lineup-scenarios__fields {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: .7rem;
  margin-top: .9rem;
}

.lineup-scenarios__fields label {
  display: grid;
  gap: .3rem;
  color: #697784;
  font-size: .68rem;
  font-weight: 900;
  letter-spacing: .06em;
  text-transform: uppercase;
}

.lineup-evaluation {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: .7rem;
  margin: .9rem 0 0;
  padding: .8rem;
  border: 1px solid rgba(16, 38, 61, .12);
  border-radius: 14px;
}

.lineup-evaluation legend {
  grid-column: 1 / -1;
  padding: 0 .3rem;
  color: #173652;
  font-size: .72rem;
  font-weight: 900;
  letter-spacing: .08em;
  text-transform: uppercase;
}

.lineup-evaluation label {
  display: grid;
  gap: .3rem;
  color: #697784;
  font-size: .65rem;
  font-weight: 900;
  letter-spacing: .05em;
  text-transform: uppercase;
}

.lineup-evaluation input,
.lineup-evaluation select {
  min-width: 0;
  padding: .55rem .65rem;
  border: 1px solid rgba(16, 38, 61, .16);
  border-radius: 9px;
  color: #173652;
  background: #fffdf7;
  font: inherit;
}

.lineup-scenarios input,
.lineup-row select {
  min-width: 0;
  padding: .55rem .65rem;
  border: 1px solid rgba(16, 38, 61, .16);
  border-radius: 9px;
  color: #173652;
  background: #fffdf7;
  font: inherit;
}

.lineup-grid {
  display: grid;
  gap: .35rem;
  margin-top: .9rem;
}

.lineup-grid__header,
.lineup-row {
  display: grid;
  grid-template-columns: 64px minmax(0, 1fr) 120px 42px;
  gap: .55rem;
  align-items: center;
}

.lineup-grid__header {
  padding: 0 .4rem;
  color: #71808c;
  font-size: .65rem;
  font-weight: 900;
  letter-spacing: .07em;
  text-transform: uppercase;
}

.lineup-row {
  padding: .38rem;
  border-radius: 10px;
  background: rgba(255, 255, 255, .74);
}

.lineup-row>strong {
  display: grid;
  width: 28px;
  height: 28px;
  place-items: center;
  border-radius: 50%;
  color: #fffaf0;
  background: #173652;
  font-size: .78rem;
}

.lineup-scenarios__error {
  margin: .8rem 0 0;
  padding: .65rem .8rem;
  border-radius: 10px;
  color: #7d291f;
  background: #f5ddd5;
  font-size: .78rem;
  font-weight: 800;
}

.lineup-decision {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: .65rem;
  margin: .9rem 0 0;
  padding: .8rem;
  border: 1px solid rgba(32, 84, 60, .2);
  border-radius: 14px;
  background: rgba(237, 247, 240, .72);
}

.lineup-decision legend {
  grid-column: 1 / -1;
  color: #20543c;
  font-size: .72rem;
  font-weight: 900;
  letter-spacing: .08em;
  text-transform: uppercase;
}

.lineup-decision label {
  display: grid;
  gap: .25rem;
  color: #526572;
  font-size: .64rem;
  font-weight: 900;
  text-transform: uppercase;
}

.lineup-decision input,
.lineup-decision select {
  min-width: 0;
  padding: .45rem;
  border: 1px solid rgba(16, 38, 61, .15);
  border-radius: 8px;
  background: #fffdf7;
  font: inherit;
}

.lineup-decision select[multiple] {
  min-height: 4.5rem;
}

.lineup-decision__wide {
  grid-column: span 2;
}

.lineup-decision button {
  align-self: end;
  padding: .55rem .7rem;
  border: 0;
  border-radius: 9px;
  color: #fffaf0;
  background: #20543c;
  font: inherit;
  font-weight: 900;
  cursor: pointer;
}

.lineup-scenarios__footer {
  margin-top: .9rem;
  color: #667680;
  font-size: .75rem;
}

.lineup-scenario-history {
  margin-top: 1rem;
  padding-top: .8rem;
  border-top: 1px solid rgba(16, 38, 61, .1);
}

.lineup-scenario-history strong {
  color: #173652;
  font-size: .78rem;
  text-transform: uppercase;
}

.lineup-scenario-history ul {
  display: grid;
  gap: .35rem;
  margin: .5rem 0 0;
  padding: 0;
  list-style: none;
}

.lineup-score-comparison {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: .55rem;
  margin-top: .55rem;
}

.lineup-score-comparison article {
  display: grid;
  gap: .25rem;
  padding: .7rem;
  border-radius: 12px;
  background: rgba(32, 84, 60, .08);
}

.lineup-score-comparison article>div {
  display: flex;
  justify-content: space-between;
  gap: .5rem;
}

.lineup-score-comparison article>div span {
  color: #20543c;
  font-weight: 900;
}

.lineup-score-comparison small {
  color: #526572;
  font-size: .67rem;
  line-height: 1.4;
}

.lineup-score-comparison a {
  color: #20543c;
  font-size: .7rem;
  font-weight: 900;
}

.lineup-scenario-history li {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
}

.lineup-scenario-history a {
  color: #20543c;
  font-size: .8rem;
  font-weight: 900;
}

.lineup-scenario-history span {
  color: #71808c;
  font-size: .72rem;
}

.opponent-report-actions {
  display: flex;
  gap: .75rem;
  align-items: center;
}

.opponent-report-actions button {
  padding: .55rem .8rem;
  border: 0;
  border-radius: 999px;
  color: #fffaf0;
  background: #8d392e;
  font-size: .72rem;
  font-weight: 900;
  cursor: pointer;
}

.opponent-report-actions button:disabled {
  opacity: .5;
  cursor: not-allowed;
}

.opponent-report-error {
  margin-top: .7rem;
  padding: .65rem .8rem;
  border-radius: 10px;
  color: #7d291f;
  background: #f5ddd5;
  font-size: .78rem;
  font-weight: 800;
}

.opponent-report-history {
  margin-top: .9rem;
  padding: 1rem;
  border: 1px solid rgba(16, 38, 61, .12);
  border-radius: 18px;
  background: rgba(16, 38, 61, .04);
}

.opponent-report-history>header {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: end;
}

.opponent-report-history>header small,
.opponent-report-history>header strong {
  display: block;
}

.opponent-report-history>header small {
  color: #a93627;
  font-size: .64rem;
  font-weight: 900;
  letter-spacing: .1em;
  text-transform: uppercase;
}

.opponent-report-history>header span,
.opponent-report-history>p {
  color: #667680;
  font-size: .75rem;
}

.opponent-report-list {
  display: grid;
  gap: .5rem;
  margin-top: .7rem;
}

.opponent-report-list>a {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: center;
  padding: .7rem .8rem;
  border-radius: 12px;
  color: #173652;
  background: rgba(255, 255, 255, .78);
  text-decoration: none;
}

.opponent-report-list strong,
.opponent-report-list small {
  display: block;
}

.opponent-report-list small {
  margin-top: .15rem;
  color: #71808c;
  font-size: .68rem;
}

.opponent-report-list em {
  color: #8d392e;
  font-size: .7rem;
  font-style: normal;
  font-weight: 900;
  white-space: nowrap;
}

.opponent-prep__overview {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: center;
  margin-top: 1rem;
  padding: 1rem;
  border-radius: 18px;
  color: #fffaf0;
  background: #10263d;
}

.opponent-prep__identity {
  display: flex;
  min-width: 0;
  gap: .9rem;
  align-items: center;
}

.opponent-prep__logo {
  display: grid;
  flex: 0 0 auto;
  width: 66px;
  height: 66px;
  place-items: center;
  border-radius: 50%;
  background: #fff;
}

.opponent-prep__logo img {
  width: 48px;
  height: 48px;
  object-fit: contain;
}

.opponent-prep__identity small,
.opponent-prep__identity a,
.opponent-prep__identity p,
.opponent-prep__venue small,
.opponent-prep__venue strong {
  display: block;
}

.opponent-prep__identity small,
.opponent-prep__venue small {
  color: #9fb0bc;
  font-size: .66rem;
  font-weight: 900;
  letter-spacing: .1em;
  text-transform: uppercase;
}

.opponent-prep__identity a {
  margin: .15rem 0;
  color: #fffaf0;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.7rem;
  font-weight: 900;
  line-height: 1;
  text-decoration-color: rgba(255, 250, 240, .35);
  text-underline-offset: .14em;
  text-transform: uppercase;
}

.opponent-prep__identity p {
  margin: .3rem 0 0;
  color: #d2dce2;
  font-size: .78rem;
}

.opponent-prep__venue {
  flex: 0 0 auto;
  max-width: 240px;
  text-align: right;
}

.opponent-prep__venue strong {
  margin-top: .25rem;
}

.probable-starters {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: .75rem;
  margin-top: .75rem;
}

.probable-starters>article {
  padding: .9rem;
  border: 1px solid rgba(16, 38, 61, .11);
  border-radius: 16px;
  background: rgba(255, 255, 255, .76);
}

.probable-starters>article>header {
  display: flex;
  justify-content: space-between;
  gap: .7rem;
  align-items: start;
  padding-bottom: .7rem;
  border-bottom: 1px solid rgba(16, 38, 61, .09);
}

.probable-starters>article>header strong,
.probable-starters>article>header span {
  display: block;
}

.probable-starters>article>header span {
  margin-top: .15rem;
  color: #6d7b85;
  font-size: .7rem;
  font-weight: 800;
  text-transform: uppercase;
}

.probable-starters>article>header a {
  color: #8d392e;
  font-size: .68rem;
  font-weight: 850;
  text-decoration: none;
}

.starter-matchup {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
  gap: .6rem;
  align-items: center;
  padding-top: .75rem;
}

.starter-matchup>span {
  color: #a93627;
  font-size: .65rem;
  font-weight: 900;
  text-transform: uppercase;
}

.starter-matchup>div:last-child {
  text-align: right;
}

.starter-matchup small,
.starter-matchup a,
.starter-matchup strong {
  display: block;
}

.starter-matchup small {
  margin-bottom: .25rem;
  color: #71808c;
  font-size: .61rem;
  font-weight: 850;
  letter-spacing: .06em;
  text-transform: uppercase;
}

.starter-matchup a,
.starter-matchup strong {
  overflow: hidden;
  color: #173652;
  font-size: .84rem;
  font-weight: 850;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.opponent-recent {
  margin-top: .85rem;
  padding: 1rem;
  border: 1px solid rgba(16, 38, 61, .11);
  border-radius: 16px;
  background: rgba(255, 255, 255, .76);
}

.opponent-recent>header small,
.opponent-recent>header strong {
  display: block;
}

.opponent-recent>header small,
.starter-scouting>header small {
  color: #a93627;
  font-size: .64rem;
  font-weight: 900;
  letter-spacing: .1em;
  text-transform: uppercase;
}

.opponent-recent>header strong {
  margin-top: .2rem;
}

.opponent-recent dl {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: .6rem;
  margin: .8rem 0 0;
}

.opponent-recent dl div {
  padding: .7rem;
  border-radius: 12px;
  background: rgba(16, 38, 61, .055);
}

.opponent-recent dt {
  color: #71808c;
  font-size: .62rem;
  font-weight: 850;
  text-transform: uppercase;
}

.opponent-recent dd {
  margin: .2rem 0 0;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.35rem;
  font-weight: 900;
}

.starter-scouting {
  margin-top: .85rem;
  padding: 1rem;
  border: 1px solid rgba(16, 38, 61, .14);
  border-radius: 18px;
  background: rgba(255, 255, 255, .82);
}

.starter-scouting>header {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: end;
  padding-bottom: .8rem;
  border-bottom: 1px solid rgba(16, 38, 61, .1);
}

.starter-scouting>header small,
.starter-scouting>header a {
  display: block;
}

.starter-scouting>header a {
  margin-top: .2rem;
  color: #173652;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.55rem;
  font-weight: 900;
  text-transform: uppercase;
}

.starter-scouting>header>span {
  color: #667680;
  font-size: .7rem;
  font-weight: 850;
}

.scouting-layout {
  display: grid;
  grid-template-columns: minmax(0, 1.7fr) minmax(270px, .8fr);
  gap: .8rem;
  margin-top: .8rem;
}

.scouting-table-wrap {
  overflow-x: auto;
}

.scouting-layout h4 {
  margin: 0 0 .55rem;
  color: #173652;
  font-size: .72rem;
  letter-spacing: .08em;
  text-transform: uppercase;
}

.scouting-table-wrap table {
  width: 100%;
  border-collapse: collapse;
  font-size: .72rem;
}

.scouting-table-wrap th,
.scouting-table-wrap td {
  padding: .55rem .45rem;
  border-top: 1px solid rgba(16, 38, 61, .09);
  text-align: right;
  white-space: nowrap;
}

.scouting-table-wrap th:first-child {
  text-align: left;
}

.scouting-table-wrap tbody th small {
  display: block;
  color: #7a858d;
  font-size: .58rem;
}

.scouting-table-wrap td:last-child {
  max-width: 170px;
  white-space: normal;
}

.evidence-link {
  display: block;
  margin-top: .2rem;
  color: #8d392e;
  font-size: .62rem;
  font-weight: 800;
  text-decoration: none;
}

.evidence-link:hover {
  text-decoration: underline;
}

.scouting-side {
  display: grid;
  gap: .7rem;
}

.scouting-side>article {
  padding: .8rem;
  border-radius: 13px;
  background: rgba(16, 38, 61, .05);
}

.scouting-side dl {
  margin: 0;
}

.scouting-side dl>div+div {
  margin-top: .65rem;
  padding-top: .65rem;
  border-top: 1px solid rgba(16, 38, 61, .09);
}

.scouting-side dt {
  font-size: .68rem;
  font-weight: 900;
}

.scouting-side dd {
  margin: .15rem 0 0;
  color: #526573;
  font-size: .68rem;
  line-height: 1.4;
}

.scouting-side ul {
  margin: 0;
  padding: 0;
  list-style: none;
}

.scouting-side li {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: .3rem .6rem;
  padding: .45rem 0;
  border-top: 1px solid rgba(16, 38, 61, .08);
  font-size: .68rem;
}

.scouting-side li:first-child {
  border-top: 0;
}

.scouting-side li .evidence-link {
  grid-column: 1 / -1;
}

.scouting-side .is-up {
  color: #1b6d45;
}

.scouting-side .is-down {
  color: #9b3328;
}

.scouting-side article>p {
  margin: 0;
  color: #6f7d86;
  font-size: .68rem;
  line-height: 1.45;
}

.performance-panel h3 {
  margin: 0 0 .55rem;
  font-size: .9rem;
  letter-spacing: .05em;
  text-transform: uppercase;
  color: #5f6c76;
}

.analytics-coverage-warning {
  display: flex;
  gap: .35rem;
  flex-direction: column;
  margin-top: 1rem;
  padding: .75rem .9rem;
  border: 1px solid #d89a32;
  border-radius: 12px;
  color: #68420d;
  background: #fff4d8;
}

.analytics-coverage-warning span {
  font-size: .86rem;
}

.ranking-scale-note {
  display: flex;
  gap: .45rem;
  align-items: center;
  margin: 1rem 0 0;
  color: #69757e;
  font-size: .72rem;
}

.ranking-scale-note i {
  display: block;
  width: 34px;
  height: 7px;
  border-radius: 999px;
  background: linear-gradient(90deg, #10263d, #1d4d73);
}

.ranking-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1rem;
  margin-top: 1rem;
}

.ranking-card {
  min-width: 0;
  padding: 1.1rem;
  border: 1px solid #d9d7ce;
  border-radius: 20px;
  background: rgba(255, 255, 255, .78);
  box-shadow: 0 10px 28px rgba(16, 38, 61, .055);
}

.ranking-card__heading {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: end;
  padding: 0 .15rem .85rem;
  border-bottom: 1px solid #e4e1d9;
}

.performance-panel .ranking-card__heading h3 {
  margin: 0;
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.35rem;
  letter-spacing: .065em;
}

.ranking-card__heading span {
  width: 52px;
  color: #68747e;
  font-size: .66rem;
  font-weight: 900;
  letter-spacing: .08em;
  text-align: center;
  text-transform: uppercase;
}

.ranking-card__metrics {
  display: grid;
  gap: .9rem;
  padding-top: 1rem;
}

.ranking-row {
  display: grid;
  grid-template-columns: 82px minmax(0, 1fr) 52px;
  gap: .7rem;
  align-items: center;
}

.ranking-row__label {
  color: #253d51;
  font-size: .83rem;
}

.ranking-bar {
  position: relative;
  height: 42px;
  overflow: hidden;
  border: 1px solid rgba(16, 38, 61, .07);
  border-radius: 10px;
  background: linear-gradient(180deg, #edf0f2, #e3e7e9);
  box-shadow: inset 0 1px 4px rgba(16, 38, 61, .08);
}

.ranking-bar__fill {
  position: absolute;
  inset: 0 auto 0 0;
  display: block;
  border-radius: 9px;
  background: linear-gradient(90deg, #10263d, #1d4d73);
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, .08);
  transition: width .35s ease;
}

.ranking-bar__value {
  position: absolute;
  z-index: 1;
  top: 50%;
  padding: .18rem .42rem;
  border-radius: 7px;
  color: #fff;
  background: rgba(8, 25, 42, .28);
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1rem;
  font-weight: 900;
  line-height: 1;
  white-space: nowrap;
  transform: translate(-100%, -50%);
}

.ranking-bar__value--outside {
  color: #10263d;
  background: transparent;
  transform: translate(.35rem, -50%);
}

.ranking-row__rank {
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.35rem;
  text-align: center;
}

.performance-grid {
  display: grid;
  gap: .75rem;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  margin-top: 1rem;
}

.performance-grid article,
.signals-grid article {
  padding: .75rem;
  border: 1px solid #e3dfd7;
  border-radius: 14px;
  background: rgba(255, 255, 255, .66);
}

.performance-grid dl {
  margin: 0;
  display: grid;
  gap: .35rem;
}

.performance-grid dt {
  color: #6f7981;
  font-size: .72rem;
  font-weight: 700;
}

.performance-grid dd {
  margin: 0;
  color: #1d3448;
  font-weight: 700;
}

.signals-grid {
  display: grid;
  gap: .75rem;
  margin-top: .85rem;
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.signals-grid ul {
  margin: 0;
  padding-left: 1rem;
  color: #445767;
}

.signals-grid li {
  margin: .22rem 0;
}

.team-panel>header {
  display: flex;
  justify-content: space-between;
  align-items: end;
  gap: 1rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid #e2e0d8;
}

.team-panel h2 {
  margin: .12rem 0 0;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 2rem;
  text-transform: uppercase;
}

.team-panel header>span {
  color: #778087;
  font-size: .75rem;
}

.game-list {
  margin: 0;
  padding: 0;
  list-style: none;
}

.game-list li {
  display: grid;
  grid-template-columns: 82px 1fr auto;
  gap: .9rem;
  align-items: center;
  padding: .85rem 0;
  border-bottom: 1px solid #ece9e1;
}

.game-list li:last-child {
  border-bottom: 0;
}

.game-list li.game-list__linked {
  display: block;
  padding: 0;
}

.game-result-link {
  display: grid;
  grid-template-columns: 82px 1fr auto;
  gap: .9rem;
  align-items: center;
  padding: .85rem 0;
  color: inherit;
  text-decoration: none;
}

.game-result-link:hover strong,
.game-result-link:focus-visible strong {
  color: #a93627;
}

.game-list time,
.game-list small {
  color: #69747c;
  font-size: .76rem;
}

.game-list strong,
.game-list span {
  display: block;
}

.game-list span {
  margin-top: .15rem;
  color: #758088;
  font-size: .75rem;
}

.result {
  display: grid;
  place-items: center;
  width: 30px;
  height: 30px;
  border-radius: 50%;
  color: white;
  font-size: .75rem;
}

.result--w {
  background: #176044;
}

.result--l {
  background: #9c382c;
}

.result--t {
  background: #69747c;
}

.roster-panel {
  margin-top: 0;
}

.roster-view-controls {
  display: flex;
  gap: .8rem;
  align-items: center;
}

.roster-view-controls>div {
  display: inline-flex;
  padding: .2rem;
  border-radius: 999px;
  background: #e9e6dd;
}

.roster-view-controls button {
  display: inline-flex;
  gap: .35rem;
  align-items: center;
  padding: .42rem .7rem;
  border: 0;
  border-radius: 999px;
  color: #5c6871;
  background: transparent;
  font: inherit;
  font-size: .72rem;
  font-weight: 800;
  cursor: pointer;
}

.roster-view-controls button span {
  display: grid;
  place-items: center;
  min-width: 20px;
  height: 20px;
  padding: 0 .3rem;
  border-radius: 999px;
  color: inherit;
  background: rgba(16, 38, 61, .09);
  font-size: .64rem;
}

.roster-view-controls button.is-selected {
  color: #fffaf0;
  background: #10263d;
  box-shadow: 0 3px 10px rgba(16, 38, 61, .18);
}

.roster-view-controls button.is-selected span {
  background: rgba(255, 255, 255, .16);
}

.roster-view-controls>small {
  color: #778087;
  font-size: .7rem;
  white-space: nowrap;
}

.depth-chart {
  margin: 1.25rem 0 1.5rem;
  padding: 1rem;
  border: 1px solid #e7e2d8;
  border-radius: 16px;
  background: #f8f6ef;
}

.depth-chart__intro {
  display: flex;
  align-items: end;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: .85rem;
}

.depth-chart__intro p,
.depth-chart__role {
  margin: 0 0 .2rem;
  color: #a93627;
  font-size: .63rem;
  font-weight: 800;
  letter-spacing: .12em;
  text-transform: uppercase;
}

.depth-chart__intro h3 {
  margin: 0;
  color: #10263d;
  font-size: 1.15rem;
}

.depth-chart__intro small {
  color: #778087;
  font-size: .7rem;
}

.depth-chart__grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: .7rem;
}

.depth-chart__group {
  min-width: 0;
  padding: .85rem;
  border: 1px solid #e8e5dd;
  border-radius: 12px;
  background: #fffdf8;
}

.depth-chart__group>header {
  display: flex;
  align-items: start;
  justify-content: space-between;
  gap: .5rem;
  padding-bottom: .55rem;
  border-bottom: 1px solid #ebe7de;
}

.depth-chart__group h4 {
  margin: 0;
  color: #10263d;
  font-size: .88rem;
}

.depth-chart__group>header>b {
  display: grid;
  place-items: center;
  min-width: 23px;
  height: 23px;
  border-radius: 50%;
  color: #fffaf0;
  background: #10263d;
  font-size: .68rem;
}

.depth-chart__lane {
  display: grid;
  grid-template-columns: 28px minmax(0, 1fr);
  gap: .5rem;
  padding-top: .65rem;
}

.depth-chart__position {
  color: #69747c;
  font-size: .68rem;
  font-weight: 800;
}

.depth-chart__lane ol {
  display: grid;
  gap: .35rem;
  margin: 0;
  padding: 0;
  list-style: none;
}

.depth-chart__lane li {
  display: flex;
  align-items: center;
  gap: .35rem;
  min-width: 0;
  color: #10263d;
  font-size: .76rem;
}

.depth-chart__lane a {
  overflow: hidden;
  color: inherit;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.depth-chart__lane a:hover {
  color: #a93627;
}

.depth-chart__rank {
  display: grid;
  place-items: center;
  width: 17px;
  height: 17px;
  border-radius: 50%;
  color: #69747c;
  background: #ebe8df;
  font-size: .6rem;
  font-weight: 800;
}

.depth-chart__status {
  margin-left: auto;
  padding: .16rem .3rem;
  border-radius: 999px;
  color: #8d392e;
  background: #f3dfd8;
  font-size: .58rem;
  font-weight: 800;
}

.roster-table-wrap {
  overflow-x: auto;
}

table {
  width: 100%;
  border-collapse: collapse;
}

th,
td {
  padding: .75rem .8rem;
  border-bottom: 1px solid #e8e5dd;
  text-align: left;
}

th {
  color: #69747c;
  font-size: .68rem;
  letter-spacing: .08em;
  text-transform: uppercase;
}

.roster-player {
  display: inline-flex;
  align-items: center;
  gap: .7rem;
  color: #10263d;
  text-decoration: none;
}

.roster-player:hover strong {
  color: #a93627;
}

.roster-headshot {
  display: grid;
  place-items: center;
  width: 42px;
  height: 42px;
  overflow: hidden;
  border-radius: 50%;
  color: white;
  background: #10263d;
}

.roster-headshot img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  object-position: center 16%;
}

.roster-headshot b {
  font-size: .72rem;
}

.roster-status {
  display: inline-block;
  padding: .3rem .55rem;
  border-radius: 999px;
  color: #176044;
  background: #dcefe5;
  font-size: .7rem;
  font-weight: 800;
}

.roster-status--injured {
  color: #8d392e;
  background: #f3dfd8;
}

.team-empty {
  padding: 1rem 0 0;
  color: #758088;
}

.team-freshness {
  display: flex;
  justify-content: flex-end;
  gap: 1.5rem;
  padding: 1rem;
  color: #727c83;
  font-size: .72rem;
}

.team-state {
  margin-top: 2rem;
  padding: 2rem;
  border-radius: 20px;
  background: #fffaf0;
}

.team-state--error {
  color: #8f2e23;
}

.team-state button {
  padding: .65rem 1rem;
  border: 0;
  border-radius: 999px;
  color: white;
  background: #10263d;
  font-weight: 800;
}

@media (max-width: 900px) {
  .team-hero {
    grid-template-columns: 100px 1fr;
  }

  .team-logo {
    width: 90px;
    height: 90px;
  }

  .team-logo img {
    width: 68px;
    height: 68px;
  }

  .season-picker {
    grid-column: 1 / -1;
  }

  .team-summary {
    grid-template-columns: 1fr 1fr;
  }

  .team-schedule-grid {
    grid-template-columns: 1fr;
  }

  .ranking-grid {
    grid-template-columns: 1fr;
  }

  .performance-grid {
    grid-template-columns: 1fr 1fr;
  }

  .signals-grid {
    grid-template-columns: 1fr;
  }

  .roster-panel>header {
    align-items: flex-start;
    flex-direction: column;
  }

  .depth-chart__grid {
    grid-template-columns: 1fr 1fr;
  }
}

@media (max-width: 900px) {
  .scouting-layout {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 560px) {
  .team-hero {
    grid-template-columns: 1fr;
    padding: 1.25rem;
  }

  .team-summary,
  .team-hero__footer {
    margin-inline: -1.25rem;
    padding-inline: 1.25rem;
  }

  .team-summary {
    grid-template-columns: 1fr;
  }

  .team-summary__record {
    align-items: flex-start;
    flex-direction: column;
  }

  .team-summary__recent-records {
    width: 100%;
    text-align: left;
  }

  .team-profile-tabs button {
    flex: 0 0 auto;
    min-width: 118px;
  }

  .schedule-calendar__header {
    align-items: flex-start;
    padding: 1rem;
  }

  .schedule-calendar {
    min-width: 840px;
  }

  .team-identity h1 {
    font-size: 3.4rem;
  }

  .ranking-card {
    padding: .85rem;
  }

  .ranking-row {
    grid-template-columns: 68px minmax(0, 1fr) 42px;
    gap: .45rem;
  }

  .ranking-bar {
    height: 38px;
  }

  .ranking-row__label {
    font-size: .75rem;
  }

  .ranking-card__heading span {
    width: 42px;
  }

  .performance-grid {
    grid-template-columns: 1fr;
  }

  .depth-chart {
    padding: .8rem;
  }

  .depth-chart__intro {
    align-items: flex-start;
    flex-direction: column;
    gap: .35rem;
  }

  .depth-chart__grid {
    grid-template-columns: 1fr;
  }

  .game-list li,
  .game-result-link {
    grid-template-columns: 68px 1fr auto;
  }

  .roster-view-controls {
    width: 100%;
    align-items: flex-start;
    flex-direction: column;
  }
}

@media (max-width: 560px) {

  .opponent-prep__overview,
  .starter-scouting>header {
    align-items: flex-start;
    flex-direction: column;
  }

  .opponent-prep__venue {
    max-width: none;
    text-align: left;
  }

  .opponent-recent dl {
    grid-template-columns: 1fr 1fr;
  }
}

@media (max-width: 560px) {

  .lineup-evaluation,
  .lineup-decision {
    grid-template-columns: 1fr;
  }

  .lineup-decision__wide {
    grid-column: auto;
  }

  .lineup-grid__header,
  .lineup-row {
    grid-template-columns: 36px minmax(0, 1fr) 80px 32px;
  }
}
</style>
