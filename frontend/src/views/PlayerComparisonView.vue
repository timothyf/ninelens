<script setup>
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import PlayerComparisonPicker from '../components/PlayerComparisonPicker.vue'
import SavedAnalysisControls from '../components/SavedAnalysisControls.vue'
import NotesPanel from '../components/NotesPanel.vue'
import { usePlayerComparisonProfiles } from '../composables/usePlayerComparisonProfiles'
import { formatBaseballStatValue } from '../utils/baseballStatFormatting'
import {
  benchmarkKeyForStat,
  commonWeightedOverallScores,
  directionalityForStat,
  opportunityForRows,
  percentileScore,
  reliabilityAdjustedScore,
  relativeComparisonScore,
  robustBenchmarkScore,
  weightedOverallScore,
} from '../utils/comparisonScoring'

const route = useRoute()
const router = useRouter()
const leftId = ref(route.query.left ? String(route.query.left) : '')
const rightId = ref(route.query.right ? String(route.query.right) : '')
const thirdId = ref(route.query.third ? String(route.query.third) : '')
const savedAnalysisState = computed(() => ({ leftPlayerId: leftId.value, rightPlayerId: rightId.value, thirdPlayerId: thirdId.value }))
const savedAnalysisUrl = computed(() => {
  const query = new URLSearchParams()
  if (leftId.value) query.set('left', leftId.value)
  if (rightId.value) query.set('right', rightId.value)
  if (thirdId.value) query.set('third', thirdId.value)
  return `/compare${query.size ? `?${query}` : ''}`
})
const comparisonIds = computed(() => [leftId.value, rightId.value, thirdId.value].filter(Boolean))
const { players: comparisonProfiles, loading: comparisonRequestLoading, error: comparisonRequestError } = usePlayerComparisonProfiles(comparisonIds, { requestParams: { view: 'comparison' } })
const leftPlayer = computed(() => comparisonProfiles.value.find((player) => String(player.id) === String(leftId.value)) || null)
const rightPlayer = computed(() => comparisonProfiles.value.find((player) => String(player.id) === String(rightId.value)) || null)
const thirdPlayer = computed(() => comparisonProfiles.value.find((player) => String(player.id) === String(thirdId.value)) || null)
const leftLoading = computed(() => comparisonRequestLoading.value && !leftPlayer.value)
const rightLoading = computed(() => comparisonRequestLoading.value && !rightPlayer.value)
const thirdLoading = computed(() => comparisonRequestLoading.value && Boolean(thirdId.value) && !thirdPlayer.value)
const leftError = computed(() => comparisonRequestError.value)
const rightError = computed(() => comparisonRequestError.value)
const thirdError = computed(() => comparisonRequestError.value)

const comparisonPlayers = computed(() => [leftPlayer.value, rightPlayer.value, thirdPlayer.value].filter(Boolean))
const hasThirdPlayer = computed(() => Boolean(thirdId.value))
const profileLoaders = computed(() => [
  { label: 'Player A', name: leftPlayer.value?.fullName, loading: leftLoading.value, error: leftError.value },
  { label: 'Player B', name: rightPlayer.value?.fullName, loading: rightLoading.value, error: rightError.value },
  { label: 'Player C', name: thirdPlayer.value?.fullName, loading: thirdLoading.value, error: thirdError.value },
].filter((profile, index) => index < 2 || Boolean(thirdId.value)))
const loadedProfileCount = computed(() => profileLoaders.value.filter((profile) => !profile.loading && !profile.error && profile.name).length)
const comparisonLoading = computed(() => profileLoaders.value.some((profile) => profile.loading))
const showSeasonComparison = computed(() => comparisonPlayers.value.every((player) => player.profile?.active !== false))

const ready = computed(() => Boolean(
  leftPlayer.value &&
  rightPlayer.value &&
  String(leftPlayer.value.id) !== String(rightPlayer.value.id) &&
  (!thirdId.value || (thirdPlayer.value && ![leftPlayer.value.id, rightPlayer.value.id].map(String).includes(String(thirdPlayer.value.id))))
))
const singleSeasonCareerComparison = computed(() =>
  ready.value && comparisonPlayers.value.every((player) => player.careerOverview.seasonCount === 1),
)
const comparisonNoteKey = computed(() => {
  if (!ready.value) return ''
  return [leftId.value, rightId.value, thirdId.value].filter(Boolean).map(Number).sort((a, b) => a - b).join(':')
})
const sameCategory = computed(() =>
  ready.value && comparisonPlayers.value.every((player) => player.seasonOverview.category === comparisonPlayers.value[0].seasonOverview.category),
)
const seasonRows = computed(() => alignedRows('season'))
const careerRows = computed(() => alignedRows('career'))
const settingsOpen = ref(false)
const DEFAULT_STAT_WEIGHTS = {
  // Balanced Hitter preset: avoid double-counting overlapping stats and favor total value.
  avg: 0, obp: 18, slg: 16, war: 20,
  wrc_plus: 18, k_percentage: 8, bb_percentage: 8, iso: 6, baserunning_runs: 6,
  era: 18, whip: 14, 'k/9': 10, 'bb/9': 8, 'k/bb': 12,
  hits: 0, runs: 0, homeruns: 0, rbi: 0, stolenbases: 0,
  wins: 5, saves: 5, strikeouts: 0, inningspitched: 6,
  gamesplayed: 0, g: 0, plateappearances: 0, pa: 0, atbats: 0, ab: 0,
  h: 0, so: 0, ops: 0,
  ops_plus: 0, offensive_runs: 0, defensive_value: 15, tzr: 0, total_zone_runs: 0,
  k_minus_bb_percentage: 0, era_minus: 18, fip: 14, fip_minus: 14, xfip: 12, xfip_minus: 12,
}
const STAT_WEIGHT_LABELS = {
  avg: 'AVG', obp: 'OBP', slg: 'SLG', ops: 'OPS', war: 'WAR', wrc_plus: 'wRC+', ops_plus: 'OPS+',
  iso: 'ISO', tzr: 'TZR', total_zone_runs: 'TZR', k_percentage: 'K%', bb_percentage: 'BB%', k_minus_bb_percentage: 'K-BB%',
  baserunning_runs: 'BSR', offensive_runs: 'Offensive runs', defensive_value: 'Defensive value',
  era: 'ERA', era_minus: 'ERA-', whip: 'WHIP', fip: 'FIP', fip_minus: 'FIP-', xfip: 'xFIP', xfip_minus: 'xFIP-',
  'k/9': 'K/9', 'bb/9': 'BB/9', 'k/bb': 'K/BB',
  gamesplayed: 'G', plateappearances: 'PA', atbats: 'AB', hits: 'H', strikeouts: 'SO', homeruns: 'HR', runs: 'R', rbi: 'RBI',
  stolenbases: 'SB', wins: 'W', saves: 'SV', inningspitched: 'IP',
}
const SAVED_WEIGHTS_STORAGE_KEY = 'ninelens.compare.stat-weights'
const weightOverrides = ref({})
const savedWeightOverrides = ref({})
const weightRevision = ref(0)
const LOWER_IS_BETTER = {
  batting: new Set(['strikeouts', 'caughtstealing', 'k_percentage']),
  pitching: new Set(['l', 'era', 'hits', 'runs', 'er', 'homeruns', 'hitbypitch', 'baseonballs', 'whip', 'avg', 'bb_percentage']),
}
const DECIMAL_STAT_KEYS = new Set([
  'avg', 'obp', 'slg', 'ops', 'era', 'whip', 'inningspitched', 'ip', 'defensive_value', 'tzr',
  'k/9', 'bb/9', 'k/bb', 'hr/9', 'h/9', 'war',
])
const PERCENTAGE_STAT_KEYS = new Set(['k_percentage', 'bb_percentage', 'fielding_percentage'])
const AT_BAT_KEYS = new Set(['atbats', 'ab'])
const PER_AT_BAT_STAT_KEYS = new Set([
  'hits', 'runs', 'homeruns', 'doubles', 'triples', 'rbi', 'runsbattedin',
  'strikeouts', 'walks', 'stolenbases', 'caughtstealing', 'totalbases',
])
const MINIMUM_OVERALL_COVERAGE = 0.5
const OFFENSIVE_SCORE_KEYS = new Set(['wrc_plus', 'obp', 'slg', 'iso', 'k_percentage', 'bb_percentage', 'baserunning_runs'])
const VALUE_SCORE_WEIGHTS = {
  war: 60,
  wrc_plus: 15,
  defensive_value: 15,
  baserunning_runs: 10,
}
const CAREER_PERFORMANCE_SHARE = 0.85
const CAREER_DURABILITY_SHARE = 0.15
const CAREER_STAT_LABELS = {
  wrc_plus: 'wRC+',
  defensive_value: 'Defensive value',
  offensive_runs: 'Offensive runs',
  baserunning_runs: 'BsR',
  k_percentage: 'K%',
  bb_percentage: 'BB%',
}

function normalizeWeightOverrides(weights) {
  if (!weights || typeof weights !== 'object') return {}

  return Object.fromEntries(Object.entries(weights).flatMap(([key, value]) => {
    const normalizedKey = String(key).trim().toLowerCase()
    const normalizedValue = Number(value)
    if (!normalizedKey || !Number.isFinite(normalizedValue) || normalizedValue < 0 || normalizedValue > 100) return []
    return [[normalizedKey, normalizedValue]]
  }))
}

function loadSavedWeights() {
  if (typeof localStorage === 'undefined' || typeof localStorage.getItem !== 'function') return

  try {
    const saved = JSON.parse(localStorage.getItem(SAVED_WEIGHTS_STORAGE_KEY) || '{}')
    const normalized = normalizeWeightOverrides(saved)
    weightOverrides.value = { ...normalized }
    savedWeightOverrides.value = { ...normalized }
  } catch {
    weightOverrides.value = {}
    savedWeightOverrides.value = {}
  }
}

const weightsDirty = computed(() => JSON.stringify(weightOverrides.value) !== JSON.stringify(savedWeightOverrides.value))

function saveWeights() {
  const normalized = normalizeWeightOverrides(weightOverrides.value)
  if (typeof localStorage !== 'undefined' && typeof localStorage.setItem === 'function') {
    try {
      localStorage.setItem(SAVED_WEIGHTS_STORAGE_KEY, JSON.stringify(normalized))
    } catch {
      return
    }
  }

  weightOverrides.value = { ...normalized }
  savedWeightOverrides.value = { ...normalized }
}

watch([leftId, rightId, thirdId], () => {
  const query = {}
  if (leftId.value) query.left = leftId.value
  if (rightId.value) query.right = rightId.value
  if (thirdId.value) query.third = thirdId.value
  router.replace({ name: 'player-comparison', query })
})

watch(
  () => [route.query.left, route.query.right, route.query.third],
  ([left, right, third]) => {
    leftId.value = left ? String(left) : ''
    rightId.value = right ? String(right) : ''
    thirdId.value = third ? String(third) : ''
  },
)

function alignedRows(scope) {
  if (!ready.value) return []
  const leftOverview = scope === 'season' ? leftPlayer.value.seasonOverview : leftPlayer.value.careerOverview
  const overviews = comparisonPlayers.value.map((player) => scope === 'season' ? player.seasonOverview : player.careerOverview)
  const statsByPlayer = overviews.map((overview, playerIndex) => [
    ...overview.stats,
    ...overview.comparisonStats,
    ...defensiveComparisonRows(comparisonPlayers.value[playerIndex], scope),
  ]).map(withDefensiveValueFallback)
  const definitions = new Map()
  for (const stat of statsByPlayer.flat()) {
    if (!definitions.has(stat.key)) definitions.set(stat.key, stat.label)
  }
  const valuesByPlayer = statsByPlayer.map((stats) => Object.fromEntries(stats.map((stat) => [stat.key, stat.value])))
  return [...definitions].map(([key, label]) => ({ key, label, values: valuesByPlayer.map((values) => values[key]), left: valuesByPlayer[0]?.[key], right: valuesByPlayer[1]?.[key] }))
}

const settingRows = computed(() => {
  const rows = [...seasonRows.value, ...careerRows.value]
  const catalogRows = Object.entries(STAT_WEIGHT_LABELS).map(([key, label]) => ({ key, label, values: [] }))
  const seen = new Set()
  return [...rows, ...catalogRows].filter((row) => {
    const normalizedKey = String(row.key).trim().toLowerCase()
    if (seen.has(normalizedKey)) return false
    seen.add(normalizedKey)
    return true
  })
})

function statWeight(key) {
  const normalizedKey = String(key).trim().toLowerCase()
  return Number(weightOverrides.value[normalizedKey] ?? DEFAULT_STAT_WEIGHTS[normalizedKey] ?? 0)
}

function defensiveComparisonRows(player, scope) {
  if (scope === 'season') {
    return defensiveRowsForSeason(player, player.seasonOverview.season)
  }

  const defensiveSeasons = player?.defensiveStats?.seasons || []
  const rows = defensiveSeasons.filter((candidate) => candidate.season !== null && candidate.season !== undefined)
  if (rows.length === 0) return []
  const games = rows.reduce((total, row) => total + (Number(row.games) || 0), 0)
  const fieldingRows = rows.filter((row) => Number.isFinite(Number(row.fieldingPercentage)))
  const fieldingPercentage = fieldingRows.length > 0
    ? fieldingRows.reduce((total, row) => total + (Number(row.fieldingPercentage) * (Number(row.games) || 1)), 0) /
      fieldingRows.reduce((total, row) => total + (Number(row.games) || 1), 0)
    : null
  const defensiveRunsSaved = sumAvailable(rows.map((row) => row.defensiveRunsSaved))
  const outsAboveAverage = sumAvailable(rows.map((row) => row.outsAboveAverage))
  const totalZoneRuns = sumAvailable(rows.map((row) => row.totalZoneRuns))
  return defensiveRowsFromSeason({ games, fieldingPercentage, defensiveRunsSaved, totalZoneRuns, outsAboveAverage })
}

function defensiveRowsForSeason(player, season) {
  const row = (player?.defensiveStats?.seasons || []).find((candidate) => Number(candidate.season) === Number(season))
  return defensiveRowsFromSeason(row)
}

function defensiveRowsFromSeason(row) {
  if (!row) return []
  const hasTotalZoneRuns = Number.isFinite(Number(row.totalZoneRuns))
  const hasMeaningfulDrs = Number.isFinite(Number(row.defensiveRunsSaved)) &&
    (!hasTotalZoneRuns || Number(row.defensiveRunsSaved) !== 0)
  const defensiveValue = hasMeaningfulDrs
    ? row.defensiveRunsSaved
    : hasTotalZoneRuns
      ? row.totalZoneRuns
      : row.outsAboveAverage
  const displayedDrs = hasTotalZoneRuns && Number(row.defensiveRunsSaved) === 0
    ? null
    : row.defensiveRunsSaved
  return [
    { key: 'defensive_value', label: 'Defensive value', value: defensiveValue },
    { key: 'defensive_runs_saved', label: 'DRS', value: displayedDrs },
    { key: 'total_zone_runs', label: 'TZR', value: row.totalZoneRuns },
    { key: 'outs_above_average', label: 'OAA', value: row.outsAboveAverage },
    { key: 'fielding_percentage', label: 'Fielding %', value: row.fieldingPercentage },
    { key: 'defensive_games', label: 'Defensive G', value: row.games },
  ].filter((stat) => stat.value !== null && stat.value !== undefined)
}

function sumAvailable(values) {
  const numericValues = values.map(Number).filter(Number.isFinite)
  return numericValues.length > 0 ? numericValues.reduce((total, value) => total + value, 0) : null
}

function withDefensiveValueFallback(stats) {
  const tzr = stats.find((stat) => ['tzr', 'total_zone_runs'].includes(String(stat.key).trim().toLowerCase()))
  const tzrValue = Number(tzr?.value)
  if (!Number.isFinite(tzrValue)) return stats

  const defensiveIndex = stats.findIndex((stat) => String(stat.key).trim().toLowerCase() === 'defensive_value')
  const drs = stats.find((stat) => String(stat.key).trim().toLowerCase() === 'defensive_runs_saved')
  const drsValue = Number(drs?.value)
  const defensiveValue = Number(stats[defensiveIndex]?.value)
  const drsUnavailable = !Number.isFinite(drsValue) || drsValue === 0
  const defensiveValueUnavailable = !Number.isFinite(defensiveValue) || defensiveValue === 0

  if (!drsUnavailable || !defensiveValueUnavailable) return stats
  if (defensiveIndex === -1) return [...stats, { key: 'defensive_value', label: 'Defensive value', value: tzrValue }]

  return stats.map((stat, index) => index === defensiveIndex ? { ...stat, value: tzrValue } : stat)
}

function setWeight(key, value) {
  const normalizedKey = String(key).trim().toLowerCase()
  const normalizedValue = Number(value)
  if (!Number.isFinite(normalizedValue)) return

  if (normalizedValue === Number(DEFAULT_STAT_WEIGHTS[normalizedKey] ?? 0)) {
    const nextOverrides = { ...weightOverrides.value }
    delete nextOverrides[normalizedKey]
    weightOverrides.value = nextOverrides
  } else {
    weightOverrides.value = {
      ...weightOverrides.value,
      [normalizedKey]: Math.min(100, Math.max(0, normalizedValue)),
    }
  }
  weightRevision.value += 1
}

function scoreValue(row, playerIndex, scope) {
  const rawValue = row.values[playerIndex]
  if (rawValue === null || rawValue === undefined || rawValue === '') return null
  const value = Number(rawValue)
  const useSeasonScoring = scope === 'career' && singleSeasonCareerComparison.value
  const scoringScope = useSeasonScoring ? 'season' : scope
  const category = scoringScope === 'season'
    ? comparisonPlayers.value[playerIndex]?.seasonOverview.category
    : comparisonPlayers.value[playerIndex]?.careerOverview.category
  const normalizedKey = String(row.key).trim().toLowerCase()
  const shouldNormalize = category === 'batting' && PER_AT_BAT_STAT_KEYS.has(normalizedKey)
  const comparableValue = shouldNormalize ? perAtBatValue(value, playerIndex, scoringScope) : value
  const overview = scoringScope === 'season'
    ? comparisonPlayers.value[playerIndex]?.seasonOverview
    : comparisonPlayers.value[playerIndex]?.careerOverview
  const comparisonBenchmark = findComparisonBenchmark(overview?.comparisonBenchmarks, row.key)
  const contextualBenchmarkKey = benchmarkKeyForStat(normalizedKey, category)
  const contextualBenchmark = contextualBenchmarkKey
    ? comparisonPlayers.value[playerIndex]?.contextualBenchmarks?.metrics?.find((metric) => metric.metricKey === contextualBenchmarkKey)
    : null
  const benchmarkMetric = comparisonBenchmark || contextualBenchmark
  const benchmarkDirection = directionalityForStat(normalizedKey, category, benchmarkMetric?.directionality)
  const benchmarkValue = benchmarkMetric?.unit === 'percent' && Math.abs(comparableValue) <= 1
    ? comparableValue * 100
    : comparableValue
  const benchmarkScore = benchmarkMetric
    ? robustBenchmarkScore(benchmarkValue, benchmarkMetric, benchmarkDirection)
      ?? percentileScore(benchmarkMetric.percentile, benchmarkDirection)
    : null
  if (benchmarkScore !== null) {
    return reliabilityAdjustedScore(
      benchmarkScore,
      benchmarkMetric.sampleSize ?? opportunityForRows(scoringScope === 'season' ? seasonRows.value : careerRows.value, playerIndex, category),
      category,
      scoringScope,
    )
  }
  const values = comparisonPlayers.value.map((_, index) => {
    const candidate = Number(row.values[index])
    return shouldNormalize ? perAtBatValue(candidate, index, scoringScope) : candidate
  }).filter(Number.isFinite)
  if (!Number.isFinite(comparableValue) || values.length < 2) return null

  const lowerIsBetter = LOWER_IS_BETTER[category]?.has(String(row.key).toLowerCase()) === true
  const normalizedScore = relativeComparisonScore(
    comparableValue,
    values,
    lowerIsBetter ? 'lower_better' : 'higher_better',
  )
  if (normalizedScore === null) return null
  return reliabilityAdjustedScore(
    normalizedScore,
    opportunityForRows(scoringScope === 'season' ? seasonRows.value : careerRows.value, playerIndex, category),
    category,
    scoringScope,
  ) ?? normalizedScore
}

function findComparisonBenchmark(benchmarks, statKey) {
  if (!benchmarks || typeof benchmarks !== 'object') return null

  const normalizedKey = normalizeComparisonKey(statKey)
  const entry = Object.entries(benchmarks).find(([key]) => normalizeComparisonKey(key) === normalizedKey)
  return entry?.[1] || null
}

function normalizeComparisonKey(key) {
  return String(key || '')
    .trim()
    .toLowerCase()
    .replace(/[+%]/g, (match) => match === '+' ? 'plus' : 'percentage')
    .replace(/[^a-z0-9]+/g, '')
}

function perAtBatValue(value, playerIndex, scope) {
  if (!Number.isFinite(value)) return null
  const rows = scope === 'season' ? seasonRows.value : careerRows.value
  const atBatsRow = rows.find((row) => AT_BAT_KEYS.has(String(row.key).trim().toLowerCase()))
  const atBats = Number(atBatsRow?.values[playerIndex])
  return Number.isFinite(atBats) && atBats > 0 ? value / atBats : null
}

function headlineScore(scope, playerIndex, model) {
  return headlineSummary(scope, model).scores[playerIndex]
}

function headlineCoverage(scope, model) {
  return headlineSummary(scope, model).coverage
}

function headlineSummary(scope, model) {
  if (scope === 'career') {
    const careerSummary = careerHeadlineSummary(model)
    if (careerSummary) return careerSummary
  }
  weightRevision.value
  const rows = scope === 'season' ? seasonRows.value : careerRows.value
  const statScoresByPlayer = comparisonPlayers.value.map((_, playerIndex) => rows.map((row) => ({
    key: String(row.key).trim().toLowerCase(),
    score: scoreValue(row, playerIndex, scope),
  })))
  const weights = Object.fromEntries(rows.map((row) => {
    const key = String(row.key).trim().toLowerCase()
    if (model === 'offense') return [key, OFFENSIVE_SCORE_KEYS.has(key) ? statWeight(key) : 0]
    if (model === 'value') {
      const baseWeight = VALUE_SCORE_WEIGHTS[key] || 0
      const override = weightOverrides.value[key]
      return [key, override === undefined ? baseWeight : Number(override)]
    }
    return [key, statWeight(key)]
  }))
  return commonWeightedOverallScores(statScoresByPlayer, weights, { minimumCoverage: MINIMUM_OVERALL_COVERAGE })
}

function careerHeadlineSummary(model) {
  const hasSeasonData = comparisonPlayers.value.every((player) => player.careerOverview.seasons?.length > 0)
  if (!hasSeasonData) return null

  const playerSeasonResults = comparisonPlayers.value.map((player) => {
    const results = player.careerOverview.seasons.map((season) => careerSeasonScore(player, season, model)).filter(Boolean)
    const weightedResults = results.filter((result) => result.score !== null && result.opportunity > 0)
    const totalOpportunity = weightedResults.reduce((total, result) => total + result.opportunity, 0)
    const performance = totalOpportunity > 0
      ? weightedResults.reduce((total, result) => total + (result.score * result.opportunity), 0) / totalOpportunity
      : null
    const coverage = totalOpportunity > 0
      ? weightedResults.reduce((total, result) => total + (result.coverage * result.opportunity), 0) / totalOpportunity
      : 0
    return { performance, coverage }
  })

  const opportunities = comparisonPlayers.value.map((player) => careerOpportunity(player))
  const seasons = comparisonPlayers.value.map((player) => Number(player.careerOverview.seasonCount) || 0)
  const opportunityScores = opportunities.map((value) => relativeComparisonScore(value, opportunities) ?? 50)
  const seasonScores = seasons.map((value) => relativeComparisonScore(value, seasons) ?? 50)
  const durabilityScores = opportunityScores.map((score, index) => (score * 0.75) + (seasonScores[index] * 0.25))
  const scores = playerSeasonResults.map(({ performance }, index) => {
    if (performance === null) return null
    return Math.round((performance * CAREER_PERFORMANCE_SHARE) + (durabilityScores[index] * CAREER_DURABILITY_SHARE))
  })
  const coverage = playerSeasonResults.reduce((total, result) => total + result.coverage, 0) / playerSeasonResults.length
  return { scores, coverage, durabilityScores }
}

function careerSeasonScore(player, season, model) {
  const rows = careerSeasonRows(player, season)
  const category = player.careerOverview.category
  const statScores = rows.map((row) => {
    const key = String(row.key).trim().toLowerCase()
    const benchmark = findComparisonBenchmark(season.comparisonBenchmarks, row.key)
    const value = Number(row.value)
    if (!Number.isFinite(value) || !benchmark) return { key, score: null }
    const direction = directionalityForStat(key, category, benchmark.directionality)
    const score = robustBenchmarkScore(value, benchmark, direction) ?? percentileScore(benchmark.percentile, direction)
    return {
      key,
      score: score === null ? null : reliabilityAdjustedScore(score, opportunityForSeason(rows, category), category, 'season'),
    }
  })
  const weights = Object.fromEntries(rows.map((row) => {
    const key = String(row.key).trim().toLowerCase()
    if (model === 'offense') return [key, OFFENSIVE_SCORE_KEYS.has(key) ? statWeight(key) : 0]
    const baseWeight = VALUE_SCORE_WEIGHTS[key] || 0
    const override = weightOverrides.value[key]
    return [key, override === undefined ? baseWeight : Number(override)]
  }))
  const result = weightedOverallScore(statScores, weights, { minimumCoverage: MINIMUM_OVERALL_COVERAGE })
  return { score: result.score, coverage: result.coverage, opportunity: opportunityForSeason(rows, category) }
}

function careerSeasonRows(player, season) {
  const rows = [...(season.totalStats || season.stats || [])]
  const advancedSeason = player.advancedStats.seasons.find((candidate) => Number(candidate.season) === Number(season.season))
  Object.entries(advancedSeason?.totalValues || {}).forEach(([key, value]) => {
    if (!rows.some((row) => row.key === key)) rows.push({ key, label: CAREER_STAT_LABELS[key] || key, value })
  })
  defensiveRowsForSeason(player, season.season)
    .filter((row) => row.key === 'defensive_value')
    .forEach((row) => {
      const existing = rows.find((candidate) => candidate.key === row.key)
      if (existing) existing.value = row.value
      else rows.push(row)
    })
  return rows
}

function opportunityForSeason(rows, category) {
  const keys = category === 'pitching'
    ? new Set(['inningspitched', 'ip', 'battersfaced', 'bf'])
    : new Set(['plateappearances', 'pa', 'atbats', 'ab'])
  const row = rows.find((candidate) => keys.has(String(candidate.key).trim().toLowerCase()))
  const value = Number(row?.value)
  return Number.isFinite(value) && value > 0 ? value : 0
}

function careerOpportunity(player) {
  return player.careerOverview.seasons.reduce((total, season) => {
    const rows = careerSeasonRows(player, season)
    return total + opportunityForSeason(rows, player.careerOverview.category)
  }, 0)
}

function headlineLabel(scope, playerIndex, model) {
  const score = headlineScore(scope, playerIndex, model)
  return score === null ? 'Insufficient data' : `${score}/100`
}

function headlineCoverageLabel(scope, model) {
  return `Data coverage ${Math.round(headlineCoverage(scope, model) * 100)}%`
}

function primaryScoreTitle(scope) {
  const category = comparisonPlayers.value[0]?.[scope === 'season' ? 'seasonOverview' : 'careerOverview']?.category
  return category === 'pitching' ? 'Pitching score' : 'Offensive score'
}

function primaryScoreModel(scope) {
  const category = comparisonPlayers.value[0]?.[scope === 'season' ? 'seasonOverview' : 'careerOverview']?.category
  return category === 'pitching' ? 'pitching' : 'offense'
}

function valueBreakdownLabel(scope, playerIndex) {
  const parts = [
    ['Offense', 'wrc_plus'],
    ['Defense', 'defensive_value'],
    ['Baserunning', 'baserunning_runs'],
  ].map(([label, key]) => {
    const rows = scope === 'season' ? seasonRows.value : careerRows.value
    const row = rows.find((candidate) => String(candidate.key).trim().toLowerCase() === key)
    if (!row) return `${label} —`
    const score = scoreValue(row, playerIndex, scope)
    return `${label} ${score === null ? '—' : Math.round(score)}`
  })
  return `Breakdown: ${parts.join(' · ')}`
}

function careerDurabilityLabel(playerIndex) {
  const durability = careerHeadlineSummary('value')?.durabilityScores?.[playerIndex]
  return durability === undefined ? '' : `Durability ${Math.round(durability)}/100 · 85% performance / 15% durability`
}

function resetWeights() {
  weightOverrides.value = {}
}

loadSavedWeights()

function selectPlayer(side, player) {
  if (side === 'left') leftId.value = String(player.id)
  else if (side === 'right') rightId.value = String(player.id)
  else thirdId.value = String(player.id)
}

function clearPlayer(side) {
  if (side === 'left') leftId.value = ''
  else if (side === 'right') rightId.value = ''
  else thirdId.value = ''
}

function openSavedAnalysis(item) {
  router.push(item.reproducibleUrl)
}

function statValue(key, value) {
  if (value === null || value === undefined) return '—'

  const number = Number(value)
  const normalizedKey = String(key).trim().toLowerCase()
  if (PERCENTAGE_STAT_KEYS.has(normalizedKey)) {
    return Number.isFinite(number) ? `${(number * 100).toFixed(1)}%` : '—'
  }

  if (!DECIMAL_STAT_KEYS.has(normalizedKey) && Number.isInteger(number)) {
    return number.toLocaleString('en-US')
  }

  return formatBaseballStatValue(key, value)
}

function comparisonClass(row, playerIndex, scope) {
  const value = Number(row.values[playerIndex])
  const comparisonValues = row.values.map(Number).filter(Number.isFinite)
  if (!Number.isFinite(value) || comparisonValues.length < 2 || comparisonValues.every((candidate) => candidate === value)) return ''

  const leftCategory = scope === 'season'
    ? comparisonPlayers.value[playerIndex]?.seasonOverview.category
    : comparisonPlayers.value[playerIndex]?.careerOverview.category
  const categories = comparisonPlayers.value.map((player) => scope === 'season' ? player.seasonOverview.category : player.careerOverview.category)
  if (!leftCategory || categories.some((category) => category !== leftCategory)) return ''

  const lowerIsBetter = LOWER_IS_BETTER[leftCategory]?.has(String(row.key).toLowerCase()) === true
  const isBetter = comparisonValues.every((candidate) => lowerIsBetter ? value <= candidate : value >= candidate) && comparisonValues.some((candidate) => value !== candidate)
  const isLesser = comparisonValues.every((candidate) => lowerIsBetter ? value >= candidate : value <= candidate) && comparisonValues.some((candidate) => value !== candidate)
  return isBetter ? 'is-better' : isLesser ? 'is-lesser' : ''
}
</script>

<template>
  <main class="comparison-shell">
    <header class="comparison-hero">
      <p>Player intelligence</p>
      <h1>Side-by-side comparison</h1>
      <span>Select two or three players to align current-season and career performance.</span>
    </header>

    <SavedAnalysisControls
      analysis-type="player_comparison"
      :state="savedAnalysisState"
      :reproducible-url="savedAnalysisUrl"
      compact
      @apply="openSavedAnalysis"
    />

    <section class="comparison-selectors" :class="{ 'comparison-selectors--three': hasThirdPlayer }" aria-label="Players to compare">
      <PlayerComparisonPicker label="Player A" :selected-player="leftPlayer" :selected-player-id="leftId" :profile-loading="leftLoading" :excluded-player-ids="[rightId, thirdId]" @select="selectPlayer('left', $event)" @clear="clearPlayer('left')" />
      <div class="comparison-versus" aria-hidden="true">VS</div>
      <PlayerComparisonPicker label="Player B" :selected-player="rightPlayer" :selected-player-id="rightId" :profile-loading="rightLoading" :excluded-player-ids="[leftId, thirdId]" @select="selectPlayer('right', $event)" @clear="clearPlayer('right')" />
      <template v-if="hasThirdPlayer">
        <div class="comparison-versus" aria-hidden="true">VS</div>
        <PlayerComparisonPicker label="Player C" :selected-player="thirdPlayer" :selected-player-id="thirdId" :profile-loading="thirdLoading" :excluded-player-ids="[leftId, rightId]" @select="selectPlayer('third', $event)" @clear="clearPlayer('third')" />
      </template>
      <PlayerComparisonPicker v-else label="Player C" :selected-player="null" :selected-player-id="thirdId" :profile-loading="thirdLoading" :excluded-player-ids="[leftId, rightId]" @select="selectPlayer('third', $event)" @clear="clearPlayer('third')" />
    </section>

    <section v-if="ready" class="comparison-settings" data-test="comparison-settings">
      <button type="button" class="comparison-settings__toggle" :aria-expanded="settingsOpen" @click="settingsOpen = !settingsOpen">
        Settings <span>{{ settingsOpen ? 'Hide weights' : 'Adjust weights' }}</span>
      </button>
      <div v-if="settingsOpen" class="comparison-settings__panel">
        <div>
          <strong>Overall score weights</strong>
          <p>Scores are relative to the selected players; higher scores indicate stronger performance for the weighted stats.</p>
        </div>
        <div class="comparison-settings__weights">
          <label v-for="row in settingRows" :key="row.key">
            <span>{{ row.label }}</span>
            <input :value="statWeight(row.key)" type="number" min="0" max="100" step="1" :aria-label="`${row.label} weight`" @input="setWeight(row.key, $event.target.value)" />
          </label>
        </div>
        <div class="comparison-settings__actions">
          <button type="button" class="comparison-settings__save" :disabled="!weightsDirty" @click="saveWeights">{{ weightsDirty ? 'Save weights' : 'Weights saved' }}</button>
          <button type="button" class="comparison-settings__reset" @click="resetWeights">Reset defaults</button>
        </div>
      </div>
    </section>

    <div v-if="comparisonLoading" class="comparison-state comparison-progress" data-test="comparison-loading" role="status" aria-live="polite">
      <strong>Loading comparison data…</strong>
      <span>{{ loadedProfileCount }} of {{ profileLoaders.length }} player profiles ready</span>
      <div class="comparison-progress__track" aria-hidden="true"><span :style="{ width: `${(loadedProfileCount / profileLoaders.length) * 100}%` }"></span></div>
      <div class="comparison-progress__players">
        <span v-for="profile in profileLoaders" :key="profile.label" :class="{ 'is-ready': !profile.loading && !profile.error && profile.name }">
          {{ profile.name || profile.label }} {{ profile.loading ? 'Loading…' : profile.error ? 'Unavailable' : 'Ready' }}
        </span>
      </div>
    </div>
    <div v-else-if="(leftError && leftId) || (rightError && rightId) || (thirdError && thirdId)" class="comparison-state comparison-state--error">{{ leftError || rightError || thirdError }}</div>
    <section v-else-if="!ready" class="comparison-state">Choose at least two different players to begin the comparison.</section>

    <template v-else>
      <section class="comparison-identities" data-test="comparison-identities">
        <article v-for="player in comparisonPlayers" :key="player.id">
          <RouterLink :to="{ name: 'player-profile', params: { id: player.id } }">{{ player.fullName }}</RouterLink>
          <span>{{ player.displayTeam?.name || player.team?.name || 'Team unavailable' }}</span>
          <small>{{ player.positions?.primary?.abbreviation || '—' }} · Age {{ player.profile?.age || '—' }}</small>
        </article>
      </section>

      <NotesPanel target-type="comparison" :target-id="comparisonNoteKey" title="Comparison notes" />

      <p v-if="!sameCategory" class="comparison-note">
        These players have different primary roles; unmatched statistics are shown as unavailable.
      </p>

      <section v-if="showSeasonComparison" class="comparison-table-panel" data-test="season-comparison">
        <header><div><p>Current production</p><h2>Season comparison</h2></div><span>{{ comparisonPlayers.map((player) => player.seasonOverview.season || '—').join(' / ') }}</span></header>
        <table>
          <thead><tr><th>{{ leftPlayer.fullName }}<small class="comparison-score">{{ primaryScoreTitle('season') }} <strong>{{ headlineLabel('season', 0, primaryScoreModel('season')) }}</strong><span>{{ headlineCoverageLabel('season', primaryScoreModel('season')) }}</span><strong class="comparison-score__value">Overall value {{ headlineLabel('season', 0, 'value') }}</strong><span>{{ valueBreakdownLabel('season', 0) }}</span></small></th><th>Statistic</th><th>{{ rightPlayer.fullName }}<small class="comparison-score">{{ primaryScoreTitle('season') }} <strong>{{ headlineLabel('season', 1, primaryScoreModel('season')) }}</strong><span>{{ headlineCoverageLabel('season', primaryScoreModel('season')) }}</span><strong class="comparison-score__value">Overall value {{ headlineLabel('season', 1, 'value') }}</strong><span>{{ valueBreakdownLabel('season', 1) }}</span></small></th><th v-if="hasThirdPlayer">{{ thirdPlayer.fullName }}<small class="comparison-score">{{ primaryScoreTitle('season') }} <strong>{{ headlineLabel('season', 2, primaryScoreModel('season')) }}</strong><span>{{ headlineCoverageLabel('season', primaryScoreModel('season')) }}</span><strong class="comparison-score__value">Overall value {{ headlineLabel('season', 2, 'value') }}</strong><span>{{ valueBreakdownLabel('season', 2) }}</span></small></th></tr></thead>
          <tbody>
            <tr v-for="row in seasonRows" :key="row.key" :data-test="`season-stat-${row.key}`">
              <td :class="comparisonClass(row, 0, 'season')">{{ statValue(row.key, row.values[0]) }}</td>
              <th>{{ row.label }}</th>
              <td :class="comparisonClass(row, 1, 'season')">{{ statValue(row.key, row.values[1]) }}</td>
              <td v-if="hasThirdPlayer" :class="comparisonClass(row, 2, 'season')">{{ statValue(row.key, row.values[2]) }}</td>
            </tr>
          </tbody>
        </table>
      </section>

      <section class="comparison-table-panel" data-test="career-comparison">
        <header><div><p>Career ledger</p><h2>Career comparison</h2></div><span>{{ comparisonPlayers.map((player) => `${player.careerOverview.seasonCount} seasons`).join(' / ') }}</span></header>
        <table>
          <thead><tr><th>{{ leftPlayer.fullName }}<small class="comparison-score">{{ primaryScoreTitle('career') }} <strong>{{ headlineLabel('career', 0, primaryScoreModel('career')) }}</strong><span>{{ headlineCoverageLabel('career', primaryScoreModel('career')) }}</span><strong class="comparison-score__value">Overall value {{ headlineLabel('career', 0, 'value') }}</strong><span>{{ valueBreakdownLabel('career', 0) }}</span><span>{{ careerDurabilityLabel(0) }}</span></small></th><th>Statistic</th><th>{{ rightPlayer.fullName }}<small class="comparison-score">{{ primaryScoreTitle('career') }} <strong>{{ headlineLabel('career', 1, primaryScoreModel('career')) }}</strong><span>{{ headlineCoverageLabel('career', primaryScoreModel('career')) }}</span><strong class="comparison-score__value">Overall value {{ headlineLabel('career', 1, 'value') }}</strong><span>{{ valueBreakdownLabel('career', 1) }}</span><span>{{ careerDurabilityLabel(1) }}</span></small></th><th v-if="hasThirdPlayer">{{ thirdPlayer.fullName }}<small class="comparison-score">{{ primaryScoreTitle('career') }} <strong>{{ headlineLabel('career', 2, primaryScoreModel('career')) }}</strong><span>{{ headlineCoverageLabel('career', primaryScoreModel('career')) }}</span><strong class="comparison-score__value">Overall value {{ headlineLabel('career', 2, 'value') }}</strong><span>{{ valueBreakdownLabel('career', 2) }}</span><span>{{ careerDurabilityLabel(2) }}</span></small></th></tr></thead>
          <tbody>
            <tr v-for="row in careerRows" :key="row.key" :data-test="`career-stat-${row.key}`">
              <td :class="comparisonClass(row, 0, 'career')">{{ statValue(row.key, row.values[0]) }}</td>
              <th>{{ row.label }}</th>
              <td :class="comparisonClass(row, 1, 'career')">{{ statValue(row.key, row.values[1]) }}</td>
              <td v-if="hasThirdPlayer" :class="comparisonClass(row, 2, 'career')">{{ statValue(row.key, row.values[2]) }}</td>
            </tr>
          </tbody>
        </table>
      </section>
    </template>
  </main>
</template>

<style scoped>
.comparison-shell { width: min(1180px,calc(100% - 2rem)); margin: 0 auto; padding: 2.2rem 0 5rem; color: #10263d; }
.comparison-hero { padding: 2rem; border-radius: 28px; color: #fffaf0; background: linear-gradient(120deg,#10263d,#1f506b); }
.comparison-hero p,.comparison-table-panel header p { margin: 0; color: #e8b276; font-size: .7rem; font-weight: 900; letter-spacing: .14em; text-transform: uppercase; }
.comparison-hero h1 { margin: .25rem 0; font-family: 'Avenir Next Condensed',sans-serif; font-size: clamp(2.8rem,6vw,5rem); line-height: .95; text-transform: uppercase; }
.comparison-hero span { color: #d4dde2; }
.comparison-selectors { display: grid; grid-template-columns: minmax(0,1fr) 54px minmax(0,1fr); gap: .75rem; align-items: center; margin-top: 1rem; }
.comparison-selectors--three { grid-template-columns: minmax(0,1fr) 42px minmax(0,1fr) 42px minmax(0,1fr); }
.comparison-versus { display: grid; width: 48px; height: 48px; place-items: center; border-radius: 50%; color: #fff; background: #a93627; font-weight: 900; }
.comparison-state { margin-top: 1rem; padding: 2rem; border: 1px dashed rgba(16,38,61,.2); border-radius: 18px; color: #687781; background: rgba(255,252,245,.75); text-align: center; }
.comparison-state--error { color: #8f2d24; }
.comparison-progress { display: grid; gap: .45rem; justify-items: center; }
.comparison-progress strong { color: #10263d; }
.comparison-progress__track { width: min(420px, 100%); height: 7px; overflow: hidden; border-radius: 999px; background: rgba(16,38,61,.12); }
.comparison-progress__track span { display: block; height: 100%; border-radius: inherit; background: #20543c; transition: width .25s ease; }
.comparison-progress__players { display: flex; flex-wrap: wrap; justify-content: center; gap: .4rem .8rem; font-size: .7rem; }
.comparison-progress__players span { color: #8a5b2b; }
.comparison-progress__players span.is-ready { color: #17613d; }
.comparison-identities { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: .8rem; margin-top: 1rem; }
.comparison-identities:has(article:nth-child(3)) { grid-template-columns: repeat(3, minmax(0, 1fr)); }
.comparison-identities article { padding: 1rem; border-radius: 16px; color: #fffaf0; background: #10263d; }
.comparison-identities article:last-child { text-align: right; }
.comparison-identities a,.comparison-identities span,.comparison-identities small { display: block; }
.comparison-identities a { color: inherit; font-family: 'Avenir Next Condensed',sans-serif; font-size: 1.55rem; font-weight: 900; text-transform: uppercase; }
.comparison-identities span { margin-top: .15rem; color: #d5dde2; }
.comparison-identities small { margin-top: .3rem; color: #9fb0bc; }
.comparison-note { padding: .75rem 1rem; border-radius: 12px; color: #71521f; background: #fbefce; font-size: .78rem; }
.comparison-table-panel { margin-top: 1rem; padding: 1rem; border: 1px solid rgba(16,38,61,.12); border-radius: 20px; background: rgba(255,252,245,.84); }
.comparison-table-panel > header { display: flex; justify-content: space-between; gap: 1rem; align-items: end; padding-bottom: .8rem; }
.comparison-table-panel h2 { margin: .15rem 0 0; font-family: 'Avenir Next Condensed',sans-serif; font-size: 1.8rem; text-transform: uppercase; }
.comparison-table-panel header > span { color: #6d7a83; font-size: .72rem; font-weight: 800; }
.comparison-table-panel table { width: 100%; border-collapse: collapse; }
.comparison-table-panel th,.comparison-table-panel td { width: 33.333%; padding: .7rem; border-top: 1px solid rgba(16,38,61,.09); text-align: center; }
.comparison-table-panel:has(th:nth-child(4)) th,.comparison-table-panel:has(th:nth-child(4)) td { width: 25%; }
.comparison-table-panel thead th { color: #6d7a83; font-size: .7rem; text-transform: uppercase; }
.comparison-score { display: block; margin-top: .35rem; color: #a93627; font-size: .66rem; font-weight: 800; letter-spacing: .03em; text-transform: none; }
.comparison-score strong { color: #17613d; font-size: .9rem; }
.comparison-score__value { display: block; margin-top: .3rem; color: #10263d !important; font-size: .78rem !important; }
.comparison-score span { display: block; margin-top: .15rem; color: #687781; font-size: .58rem; font-weight: 700; letter-spacing: 0; text-transform: none; }
.comparison-table-panel tbody td { font-family: 'Avenir Next Condensed',sans-serif; font-size: 1.2rem; font-weight: 900; }
.comparison-table-panel tbody td.is-better { color: #17613d; background: rgba(42,145,91,.12); }
.comparison-table-panel tbody td.is-lesser { color: #982f27; background: rgba(181,61,48,.1); }
.comparison-table-panel tbody th { color: #61717d; font-size: .72rem; text-transform: uppercase; }
.comparison-settings { margin-top: 1rem; }
.comparison-settings__toggle { display: inline-flex; align-items: center; gap: .55rem; padding: .65rem .9rem; border: 1px solid rgba(16,38,61,.14); border-radius: 999px; color: #fffaf0; background: #20543c; font: inherit; font-size: .78rem; font-weight: 900; cursor: pointer; }
.comparison-settings__toggle span { color: #cfe1d5; font-size: .68rem; font-weight: 700; }
.comparison-settings__panel { margin-top: .7rem; padding: 1rem; border: 1px solid rgba(16,38,61,.12); border-radius: 16px; background: rgba(255,252,245,.9); }
.comparison-settings__panel p { margin: .25rem 0 0; color: #687781; font-size: .75rem; }
.comparison-settings__weights { display: flex; flex-wrap: wrap; gap: .55rem; margin-top: .8rem; }
.comparison-settings__weights label { display: grid; gap: .25rem; min-width: 105px; color: #61717d; font-size: .68rem; font-weight: 800; }
.comparison-settings__weights input { width: 100%; padding: .45rem .5rem; border: 1px solid rgba(16,38,61,.16); border-radius: 8px; color: #10263d; background: #fff; font: inherit; }
.comparison-settings__actions { display: flex; flex-wrap: wrap; gap: .55rem; margin-top: .8rem; }
.comparison-settings__save,.comparison-settings__reset { padding: .45rem .7rem; border-radius: 8px; font: inherit; font-size: .7rem; font-weight: 800; cursor: pointer; }
.comparison-settings__save { border: 1px solid #20543c; color: #fffaf0; background: #20543c; }
.comparison-settings__save:disabled { opacity: .65; cursor: default; }
.comparison-settings__reset { border: 1px solid rgba(169,54,39,.25); color: #a93627; background: transparent; }
@media (max-width: 650px) { .comparison-selectors,.comparison-selectors--three { grid-template-columns: 1fr; } .comparison-versus { margin: 0 auto; } .comparison-table-panel { overflow-x: auto; } .comparison-table-panel table { min-width: 560px; } }
</style>
