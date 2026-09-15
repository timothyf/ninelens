<script setup>
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import PlayerComparisonPicker from '../components/PlayerComparisonPicker.vue'
import SavedAnalysisControls from '../components/SavedAnalysisControls.vue'
import NotesPanel from '../components/NotesPanel.vue'
import { usePlayerProfile } from '../composables/usePlayerProfile'
import { formatBaseballStatValue } from '../utils/baseballStatFormatting'

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
const { player: leftPlayer, loading: leftLoading, error: leftError } = usePlayerProfile(leftId, null, { includeCoreSection: true })
const { player: rightPlayer, loading: rightLoading, error: rightError } = usePlayerProfile(rightId, null, { includeCoreSection: true })
const { player: thirdPlayer, loading: thirdLoading, error: thirdError } = usePlayerProfile(thirdId, null, { includeCoreSection: true })

const comparisonPlayers = computed(() => [leftPlayer.value, rightPlayer.value, thirdPlayer.value].filter(Boolean))
const hasThirdPlayer = computed(() => Boolean(thirdId.value))
const showSeasonComparison = computed(() => comparisonPlayers.value.every((player) => player.profile?.active !== false))

const ready = computed(() => Boolean(
  leftPlayer.value &&
  rightPlayer.value &&
  String(leftPlayer.value.id) !== String(rightPlayer.value.id) &&
  (!thirdId.value || (thirdPlayer.value && ![leftPlayer.value.id, rightPlayer.value.id].map(String).includes(String(thirdPlayer.value.id))))
))
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
  avg: 12, obp: 16, slg: 14, ops: 18, war: 12,
  era: 18, whip: 14, 'k/9': 10, 'bb/9': 8, 'k/bb': 12,
  hits: 6, runs: 6, homeruns: 9, rbi: 8, stolenbases: 4,
  wins: 5, saves: 5, strikeouts: 8, inningspitched: 6,
}
const weightOverrides = ref({})
const LOWER_IS_BETTER = {
  batting: new Set(['strikeouts', 'caughtstealing', 'k_percentage']),
  pitching: new Set(['l', 'era', 'hits', 'runs', 'er', 'homeruns', 'hitbypitch', 'baseonballs', 'whip', 'avg', 'bb_percentage']),
}
const DECIMAL_STAT_KEYS = new Set([
  'avg', 'obp', 'slg', 'ops', 'era', 'whip', 'inningspitched', 'ip',
  'k/9', 'bb/9', 'k/bb', 'hr/9', 'h/9', 'war',
])
const PERCENTAGE_STAT_KEYS = new Set(['k_percentage', 'bb_percentage'])
const AT_BAT_KEYS = new Set(['atbats', 'ab'])
const PER_AT_BAT_STAT_KEYS = new Set([
  'hits', 'runs', 'homeruns', 'doubles', 'triples', 'rbi', 'runsbattedin',
  'strikeouts', 'walks', 'stolenbases', 'caughtstealing', 'totalbases',
])

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
  const statsByPlayer = overviews.map((overview) => [...overview.stats, ...overview.comparisonStats])
  const definitions = new Map()
  for (const stat of statsByPlayer.flat()) {
    if (!definitions.has(stat.key)) definitions.set(stat.key, stat.label)
  }
  const valuesByPlayer = statsByPlayer.map((stats) => Object.fromEntries(stats.map((stat) => [stat.key, stat.value])))
  return [...definitions].map(([key, label]) => ({ key, label, values: valuesByPlayer.map((values) => values[key]), left: valuesByPlayer[0]?.[key], right: valuesByPlayer[1]?.[key] }))
}

const settingRows = computed(() => {
  const rows = [...seasonRows.value, ...careerRows.value]
  const seen = new Set()
  return rows.filter((row) => {
    if (seen.has(row.key)) return false
    seen.add(row.key)
    return true
  })
})

function statWeight(key) {
  const normalizedKey = String(key).trim().toLowerCase()
  return Number(weightOverrides.value[normalizedKey] ?? DEFAULT_STAT_WEIGHTS[normalizedKey] ?? 5)
}

function setWeight(key, value) {
  weightOverrides.value[String(key).trim().toLowerCase()] = Number(value)
}

function scoreValue(row, playerIndex, scope) {
  const value = Number(row.values[playerIndex])
  const category = scope === 'season'
    ? comparisonPlayers.value[playerIndex]?.seasonOverview.category
    : comparisonPlayers.value[playerIndex]?.careerOverview.category
  const normalizedKey = String(row.key).trim().toLowerCase()
  const shouldNormalize = category === 'batting' && PER_AT_BAT_STAT_KEYS.has(normalizedKey)
  const comparableValue = shouldNormalize ? perAtBatValue(value, playerIndex, scope) : value
  const values = comparisonPlayers.value.map((_, index) => {
    const candidate = Number(row.values[index])
    return shouldNormalize ? perAtBatValue(candidate, index, scope) : candidate
  }).filter(Number.isFinite)
  if (!Number.isFinite(comparableValue) || values.length < 2) return null

  const minimum = Math.min(...values)
  const maximum = Math.max(...values)
  if (minimum === maximum) return 100

  const lowerIsBetter = LOWER_IS_BETTER[category]?.has(String(row.key).toLowerCase()) === true
  const normalized = lowerIsBetter
    ? (maximum - comparableValue) / (maximum - minimum)
    : (comparableValue - minimum) / (maximum - minimum)
  return normalized * 100
}

function perAtBatValue(value, playerIndex, scope) {
  if (!Number.isFinite(value)) return null
  const rows = scope === 'season' ? seasonRows.value : careerRows.value
  const atBatsRow = rows.find((row) => AT_BAT_KEYS.has(String(row.key).trim().toLowerCase()))
  const atBats = Number(atBatsRow?.values[playerIndex])
  return Number.isFinite(atBats) && atBats > 0 ? value / atBats : null
}

function overallScore(scope, playerIndex) {
  const rows = scope === 'season' ? seasonRows.value : careerRows.value
  let weightedTotal = 0
  let totalWeight = 0
  rows.forEach((row) => {
    const weight = statWeight(row.key)
    const score = scoreValue(row, playerIndex, scope)
    if (weight > 0 && score !== null) {
      weightedTotal += score * weight
      totalWeight += weight
    }
  })
  return totalWeight ? Math.round(weightedTotal / totalWeight) : null
}

function resetWeights() {
  weightOverrides.value = {}
}

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
        <button type="button" class="comparison-settings__reset" @click="resetWeights">Reset defaults</button>
      </div>
    </section>

    <div v-if="leftLoading || rightLoading || thirdLoading" class="comparison-state">Loading player profiles…</div>
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
          <thead><tr><th>{{ leftPlayer.fullName }}<small class="comparison-score">Overall score <strong>{{ overallScore('season', 0) ?? '—' }}/100</strong></small></th><th>Statistic</th><th>{{ rightPlayer.fullName }}<small class="comparison-score">Overall score <strong>{{ overallScore('season', 1) ?? '—' }}/100</strong></small></th><th v-if="hasThirdPlayer">{{ thirdPlayer.fullName }}<small class="comparison-score">Overall score <strong>{{ overallScore('season', 2) ?? '—' }}/100</strong></small></th></tr></thead>
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
          <thead><tr><th>{{ leftPlayer.fullName }}<small class="comparison-score">Overall score <strong>{{ overallScore('career', 0) ?? '—' }}/100</strong></small></th><th>Statistic</th><th>{{ rightPlayer.fullName }}<small class="comparison-score">Overall score <strong>{{ overallScore('career', 1) ?? '—' }}/100</strong></small></th><th v-if="hasThirdPlayer">{{ thirdPlayer.fullName }}<small class="comparison-score">Overall score <strong>{{ overallScore('career', 2) ?? '—' }}/100</strong></small></th></tr></thead>
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
.comparison-settings__reset { margin-top: .8rem; padding: .45rem .7rem; border: 1px solid rgba(169,54,39,.25); border-radius: 8px; color: #a93627; background: transparent; font: inherit; font-size: .7rem; font-weight: 800; cursor: pointer; }
@media (max-width: 650px) { .comparison-selectors,.comparison-selectors--three { grid-template-columns: 1fr; } .comparison-versus { margin: 0 auto; } .comparison-table-panel { overflow-x: auto; } .comparison-table-panel table { min-width: 560px; } }
</style>
