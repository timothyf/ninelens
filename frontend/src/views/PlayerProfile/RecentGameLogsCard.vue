<script setup>
import { computed, inject, ref, watch } from 'vue'

const { player, formatDate, formatBaseballStatValue } = inject('player-profile-context')

const battingColumns = [
  ['at_bats', 'AB'], ['runs', 'R'], ['hits', 'H'], ['total_bases', 'TB'], ['doubles', '2B'],
  ['triples', '3B'], ['home_runs', 'HR'], ['runs_batted_in', 'RBI'], ['walks', 'BB'],
  ['intentional_walks', 'IBB'], ['strikeouts', 'SO'], ['stolen_bases', 'SB'], ['caught_stealing', 'CS'],
  ['batting_average', 'AVG'], ['on_base_percentage', 'OBP'], ['slugging_percentage', 'SLG'],
  ['hit_by_pitch', 'HBP'], ['sacrifice_hits', 'SAC'], ['sacrifice_flies', 'SF'],
]

const pitchingColumns = [
  ['wins', 'W'], ['losses', 'L'], ['era', 'ERA'], ['games', 'G'], ['games_started', 'GS'],
  ['complete_games', 'CG'], ['shutouts', 'SHO'], ['saves', 'SV'], ['save_opportunities', 'SVO'],
  ['innings_pitched', 'IP'], ['hits', 'H'], ['runs', 'R'], ['earned_runs', 'ER'], ['home_runs', 'HR'],
  ['hit_batters', 'HB'], ['walks', 'BB'], ['intentional_walks', 'IBB'], ['strikeouts', 'SO'],
  ['pitches_strikes', 'NP-S'], ['batting_average', 'AVG'], ['whip', 'WHIP'], ['go_ao', 'GO/AO'],
]

const category = computed(() => player.value?.gameLogs?.category === 'pitching' ? 'pitching' : 'batting')
const columns = computed(() => category.value === 'pitching' ? pitchingColumns : battingColumns)
const limitOptions = computed(() => category.value === 'pitching' ? [5, 10, 15] : [10, 20, 30])
const selectedLimit = ref(category.value === 'pitching' ? 5 : 10)
const allRows = computed(() => player.value?.gameLogs?.[category.value] || [])
const rows = computed(() => allRows.value.slice(0, selectedLimit.value))
const title = computed(() => category.value === 'pitching' ? 'Pitching game logs' : 'Game logs')
const limitLabel = computed(() => `Last ${selectedLimit.value} games`)
const totals = computed(() => category.value === 'pitching' ? pitchingTotals(rows.value) : battingTotals(rows.value))

watch(category, (value) => {
  selectedLimit.value = value === 'pitching' ? 5 : 10
})

function displayValue(key, value) {
  if (value === null || value === undefined || value === '') return '—'
  if (['batting_average', 'on_base_percentage', 'slugging_percentage'].includes(key)) return Number(value).toFixed(3)
  if (['era', 'whip'].includes(key)) return formatBaseballStatValue(key, value)
  return value
}

function battingTotals(gameRows) {
  const total = Object.fromEntries(battingColumns.map(([key]) => [key, sum(gameRows, key)]))
  total.batting_average = rate(total.hits, total.at_bats)
  total.on_base_percentage = rate(
    total.hits + total.walks + total.hit_by_pitch,
    total.at_bats + total.walks + total.hit_by_pitch + total.sacrifice_flies,
  )
  total.slugging_percentage = rate(total.total_bases, total.at_bats)
  return total
}

function pitchingTotals(gameRows) {
  const total = Object.fromEntries(pitchingColumns.map(([key]) => [key, sum(gameRows, key)]))
  total.games = gameRows.length
  total.innings_pitched = formatInnings(gameRows.reduce((outCount, row) => outCount + inningsToOuts(row.innings_pitched), 0))
  total.era = rate(total.earned_runs * 9, inningsToDecimal(total.innings_pitched))
  total.whip = rate(total.hits + total.walks, inningsToDecimal(total.innings_pitched))
  total.batting_average = rate(total.hits, gameRows.reduce((atBats, row) => atBats + Number(row.batters_faced || 0), 0))
  total.pitches_strikes = sumPitchCounts(gameRows)
  return total
}

function sum(gameRows, key) {
  const values = gameRows.map((row) => Number(row[key])).filter(Number.isFinite)
  return values.length ? values.reduce((total, value) => total + value, 0) : null
}

function rate(numerator, denominator) {
  return numerator !== null && denominator ? numerator / denominator : null
}

function inningsToOuts(value) {
  if (value === null || value === undefined || value === '') return 0
  const [whole, remainder = '0'] = String(value).split('.')
  return (Number(whole) || 0) * 3 + Math.min(Number(remainder) || 0, 2)
}

function formatInnings(outs) {
  return `${Math.floor(outs / 3)}.${outs % 3}`
}

function inningsToDecimal(value) {
  const outs = inningsToOuts(value)
  return outs / 3
}

function sumPitchCounts(gameRows) {
  const totals = gameRows.reduce((result, row) => {
    const [pitches, strikes] = String(row.pitches_strikes || '').split('-').map(Number)
    if (Number.isFinite(pitches)) result.pitches += pitches
    if (Number.isFinite(strikes)) result.strikes += strikes
    return result
  }, { pitches: 0, strikes: 0 })
  return totals.pitches || totals.strikes ? `${totals.pitches}-${totals.strikes}` : null
}
</script>

<template>
  <section class="profile-stat-table game-logs-card" data-test="recent-game-logs">
    <header class="profile-section-heading">
      <div>
        <p class="eyebrow">Recent performance</p>
        <h2>{{ title }}</h2>
      </div>
      <label class="game-logs-limit">
        <select v-model.number="selectedLimit" aria-label="Games shown">
          <option v-for="limit in limitOptions" :key="limit" :value="limit">Last {{ limit }} games</option>
        </select>
      </label>
    </header>

    <div v-if="rows.length" class="game-logs-table-wrap">
      <table class="game-logs-table">
        <thead>
          <tr>
            <th class="game-logs-table__date">Date</th>
            <th class="game-logs-table__team">Team</th>
            <th class="game-logs-table__opponent">OPP</th>
            <th v-for="([key, label]) in columns" :key="key">{{ label }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in rows" :key="`${row.date}-${row.team}-${row.opponent}`">
            <th class="game-logs-table__date">{{ formatDate(row.date) }}</th>
            <td class="game-logs-table__team">{{ row.team || '—' }}</td>
            <td class="game-logs-table__opponent">{{ row.opponent || '—' }}</td>
            <td v-for="([key]) in columns" :key="key">{{ displayValue(key, row[key]) }}</td>
          </tr>
        </tbody>
        <tfoot>
          <tr>
            <th class="game-logs-table__date">Totals</th>
            <td class="game-logs-table__team">—</td>
            <td class="game-logs-table__opponent">{{ rows.length }} games</td>
            <td v-for="([key]) in columns" :key="key">{{ displayValue(key, totals[key]) }}</td>
          </tr>
        </tfoot>
      </table>
    </div>
    <p v-else class="profile-empty">No recent game logs are available for this player.</p>
  </section>
</template>
