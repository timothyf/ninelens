<script setup>
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { formatTwoDecimalPitchingRate } from '../utils/baseballStatFormatting'
import { adminRequestHeaders } from '../composables/apiAuth'

const props = defineProps({
  reportId: { type: [String, Number], required: true },
})

const report = ref(null)
const loading = ref(false)
const error = ref('')
const refreshError = ref('')
const refreshing = ref(false)
const snapshot = computed(() => report.value?.snapshot || {})
let refreshTimer

async function load() {
  loading.value = true
  error.value = ''
  try {
    const response = await fetch(`/api/opponent_reports/${encodeURIComponent(props.reportId)}`, {
      headers: adminRequestHeaders({ Accept: 'application/json' }),
    })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(payload.message || 'Unable to load opponent report.')
    report.value = payload.data
    if (needsPacketRefresh(payload.data)) await refreshReport()
  } catch (requestError) {
    error.value = requestError.message
  } finally {
    loading.value = false
  }
}

function formatDate(value) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
    .format(new Date(`${value}T12:00:00`))
}

function formatTimestamp(value) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('en-US', {
    month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit',
  }).format(new Date(value))
}

function decimal(value, digits = 1) {
  const number = Number(value)
  return Number.isFinite(number) ? number.toFixed(digits) : '—'
}

function changeLabel(change) {
  const value = Number(change.change)
  if (!Number.isFinite(value)) return '—'
  return `${value > 0 ? '+' : ''}${value.toFixed(1)}${change.unit === 'mph' ? ' mph' : ' pts'}`
}

function printReport() {
  window.print()
}

async function refreshReport() {
  refreshing.value = true
  refreshError.value = ''
  try {
    const response = await fetch(`/api/opponent_reports/${encodeURIComponent(props.reportId)}/refresh`, {
      method: 'POST', headers: adminRequestHeaders({ Accept: 'application/json' }),
    })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(payload.message || `Refresh failed (${response.status}).`)
    if (payload.data) report.value = payload.data
  } catch (_error) {
    refreshError.value = _error.message || 'Unable to refresh packet.'
  } finally {
    refreshing.value = false
  }
}

function needsPacketRefresh(value) {
  const starters = value?.snapshot?.probable_starters || []
  return starters.some((starter) => !Object.prototype.hasOwnProperty.call(starter, 'batter_matchups'))
    || !Object.prototype.hasOwnProperty.call(value?.snapshot || {}, 'expected_lineups')
}

onMounted(() => {
  load()
  refreshTimer = window.setInterval(refreshReport, 60000)
})
onUnmounted(() => window.clearInterval(refreshTimer))
watch(() => props.reportId, load)
</script>

<template>
  <main class="report-shell">
    <div v-if="loading" class="report-state">Loading saved report…</div>
    <div v-else-if="error" class="report-state report-state--error">{{ error }}</div>
    <template v-else-if="report">
      <RouterLink class="report-back" :to="{ name: 'team-profile', params: { id: report.team.id } }">
        ← {{ report.team.name }}
      </RouterLink>

      <header class="report-hero">
        <div>
          <p>Opponent report · Saved snapshot</p>
          <h1>{{ report.title }}</h1>
          <span>{{ formatDate(report.series_starts_on) }} – {{ formatDate(report.series_ends_on) }}</span>
        </div>
        <div class="report-stamp">
          <small>Generated</small>
          <strong>{{ formatTimestamp(report.generated_at) }}</strong>
          <span v-if="report.owner">Owned by {{ report.owner.name || report.owner.email }}</span>
          <span>Data is preserved as of this time</span>
        </div>
        <button class="report-print" type="button" data-test="print-report" @click="printReport">Print / PDF</button>
        <button class="report-refresh" type="button" data-test="refresh-report" :disabled="refreshing" @click="refreshReport">{{ refreshing ? 'Refreshing…' : 'Refresh packet' }}</button>
      </header>
      <p v-if="refreshError" class="report-state report-state--error" role="alert">{{ refreshError }}</p>

      <section class="report-panel report-series">
        <header><p>Series plan</p><h2>{{ snapshot.opponent?.name }}</h2></header>
        <div>
          <article v-for="game in snapshot.series || []" :key="game.id">
            <strong>{{ formatDate(game.official_date) }}</strong>
            <span>{{ game.venue_name || 'Venue TBD' }}</span>
            <small>
              {{ game.away_team?.abbreviation }} {{ game.away_probable_pitcher?.full_name || 'TBD' }}
              vs {{ game.home_team?.abbreviation }} {{ game.home_probable_pitcher?.full_name || 'TBD' }}
            </small>
          </article>
        </div>
      </section>

      <section class="report-panel">
        <header><p>Expected lineup</p><h2>Opponent batting plans</h2></header>
        <p v-if="snapshot.roster" class="report-callout">{{ snapshot.roster.player_count }} players in the {{ snapshot.roster.roster_type }} roster · synced {{ formatTimestamp(snapshot.roster.last_synced_at) }}</p>
        <div v-for="lineup in snapshot.expected_lineups || []" :key="lineup.game_id" class="report-lineup">
          <strong>{{ formatDate(lineup.official_date) }} · {{ lineup.status }}</strong>
          <ol>
            <li v-for="entry in lineup.entries || []" :key="entry.player.id">
              <span>{{ entry.batting_order || '—' }}. {{ entry.player.full_name }}</span>
              <small>{{ entry.position || '—' }} · {{ entry.bats || '—' }}</small>
            </li>
          </ol>
        </div>
      </section>

      <section class="report-panel">
        <header><p>Recent form</p><h2>Opponent performance</h2></header>
        <dl class="report-metrics">
          <div><dt>Record</dt><dd>{{ snapshot.recent_performance?.wins }}–{{ snapshot.recent_performance?.losses }}</dd></div>
          <div><dt>Runs / G</dt><dd>{{ decimal(snapshot.recent_performance?.runs_per_game, 2) }}</dd></div>
          <div><dt>OPS</dt><dd>{{ decimal(snapshot.recent_performance?.ops, 3) }}</dd></div>
          <div><dt>ERA</dt><dd>{{ formatTwoDecimalPitchingRate(snapshot.recent_performance?.era) }}</dd></div>
        </dl>
      </section>

      <section v-if="!(snapshot.probable_starters || []).length" class="report-panel report-data-status" data-test="scouting-data-status">
        <header><p>Scouting coverage</p><h2>Pitcher matchup data</h2></header>
        <p>No probable opponent starter has been announced for this series yet. The following packet sections will populate automatically when a probable pitcher and pitch history arrive:</p>
        <div class="report-data-status__grid">
          <article><strong>Batter vs pitcher</strong><span>Waiting for probable starter</span></article>
          <article><strong>Batter vs pitch type</strong><span>Waiting for probable starter</span></article>
          <article><strong>Pitch usage</strong><span>Count · zone · batter handedness</span></article>
        </div>
      </section>

      <section
        v-for="starter in snapshot.probable_starters || []"
        :key="starter.player.id"
        class="report-panel report-starter"
      >
        <header>
          <div><p>Pitcher plan</p><h2>{{ starter.player.full_name }}</h2></div>
          <span>{{ starter.throws || '—' }}HP · {{ starter.sample_size }} pitches</span>
        </header>
        <div class="report-columns">
          <div>
            <h3>Repertoire</h3>
            <table>
              <thead><tr><th>Pitch</th><th>Usage</th><th>Velo</th><th>Movement</th><th>Evidence</th></tr></thead>
              <tbody>
                <tr v-for="pitch in starter.repertoire" :key="pitch.pitch_type">
                  <th>{{ pitch.pitch_name }}</th>
                  <td>{{ decimal(pitch.usage_percentage) }}%</td>
                  <td>{{ decimal(pitch.average_velocity) }} mph</td>
                  <td>{{ decimal(pitch.horizontal_break) }} / {{ decimal(pitch.vertical_break) }} in</td>
                  <td>
                    <RouterLink
                      v-for="item in pitch.evidence || []"
                      :key="item.pitch_id"
                      :to="{ name: 'game-summary', params: { id: item.game_id }, hash: `#pitch-${item.pitch_id}` }"
                    >Pitch →</RouterLink>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <aside>
            <h3>Handedness</h3>
            <article v-for="split in starter.handedness_splits" :key="split.batter_hand">
              <strong>vs {{ split.batter_hand }}HB</strong>
              <span>{{ split.plate_appearances }} PA · {{ decimal(split.strikeout_rate) }}% K · {{ decimal(split.whiff_rate) }}% whiff</span>
              <RouterLink
                v-if="split.evidence?.[0]"
                :to="{ name: 'game-summary', params: { id: split.evidence[0].game_id }, hash: `#plate-appearance-${split.evidence[0].plate_appearance_id}` }"
              >Supporting PA →</RouterLink>
            </article>
            <p v-if="!starter.handedness_splits?.length" class="report-callout">No batter-handedness pitch sample is available.</p>
            <h3>Recent changes</h3>
            <article v-for="change in starter.recent_changes" :key="change.key">
              <strong>{{ change.label }}</strong><span>{{ changeLabel(change) }}</span>
              <RouterLink
                v-if="change.evidence?.[0]"
                :to="{ name: 'game-summary', params: { id: change.evidence[0].game_id }, hash: `#pitch-${change.evidence[0].pitch_id}` }"
              >Supporting pitch →</RouterLink>
            </article>
          </aside>
        </div>
        <div class="report-tendency-grid">
          <section>
            <h3>Usage by count</h3>
            <table>
              <thead><tr><th>Count</th><th>Pitches</th><th>Usage</th><th>Primary pitch</th></tr></thead>
              <tbody v-if="starter.usage_by_count?.length">
                <tr v-for="count in starter.usage_by_count || []" :key="count.count">
                  <th>{{ count.count }}</th><td>{{ count.pitches }}</td><td>{{ decimal(count.percentage) }}%</td>
                  <td>{{ count.repertoire?.[0]?.pitch_name || '—' }}</td>
                </tr>
              </tbody><tbody v-else><tr><td colspan="4">No count-level pitch data is available.</td></tr></tbody>
            </table>
          </section>
          <section>
            <h3>First pitch</h3>
            <p class="report-callout">{{ starter.first_pitch_tendencies?.pitches || 0 }} tracked first pitches</p>
            <ul class="report-list">
              <li v-for="pitch in starter.first_pitch_tendencies?.repertoire || []" :key="pitch.pitch_type">
                <strong>{{ pitch.pitch_name }}</strong><span>{{ decimal(pitch.percentage) }}%</span>
              </li>
            </ul>
          </section>
          <section>
            <h3>Two-strike tendencies</h3>
            <p class="report-callout">{{ starter.two_strike_tendencies?.pitches || 0 }} tracked two-strike pitches</p>
            <ul class="report-list">
              <li v-for="pitch in starter.two_strike_tendencies?.repertoire || []" :key="pitch.pitch_type">
                <strong>{{ pitch.pitch_name }}</strong><span>{{ decimal(pitch.percentage) }}%</span>
              </li>
            </ul>
          </section>
          <section>
            <h3>Location zones</h3>
            <ul v-if="starter.location_zones?.length" class="report-list">
              <li v-for="zone in starter.location_zones || []" :key="zone.label">
                <strong>{{ zone.label }}</strong><span>{{ decimal(zone.percentage) }}%</span>
              </li>
            </ul><p v-else class="report-callout">No zone-level pitch data is available.</p>
          </section>
          <section>
            <h3>Put-away pitches</h3>
            <table>
              <thead><tr><th>Pitch</th><th>Ks</th><th>Rate</th></tr></thead>
              <tbody><tr v-for="pitch in starter.put_away_pitches || []" :key="pitch.pitch_type">
                <th>{{ pitch.pitch_name }}</th><td>{{ pitch.strikeouts }}</td><td>{{ decimal(pitch.strikeout_rate) }}%</td>
              </tr></tbody>
            </table>
          </section>
          <section>
            <h3>Times through order</h3>
            <table>
              <thead><tr><th>Pass</th><th>PA</th><th>K rate</th><th>wOBA</th></tr></thead>
              <tbody><tr v-for="pass in starter.times_through_order || []" :key="pass.order">
                <th>{{ pass.order }}</th><td>{{ pass.plate_appearances }}</td><td>{{ decimal(pass.strikeout_rate) }}%</td><td>{{ decimal(pass.woba, 3) }}</td>
              </tr></tbody>
            </table>
          </section>
          <section>
            <h3>Batter vs pitcher</h3>
            <table v-if="starter.batter_matchups?.length"><thead><tr><th>Batter</th><th>PA</th><th>Whiff</th><th>wOBA</th></tr></thead>
              <tbody><tr v-for="matchup in starter.batter_matchups" :key="matchup.batter.mlb_id"><th>{{ matchup.batter.full_name }}</th><td>{{ matchup.plate_appearances }}</td><td>{{ decimal(matchup.whiff_rate) }}%</td><td>{{ decimal(matchup.woba, 3) }}</td></tr></tbody>
            </table><p v-else class="report-callout">No batter-vs-pitcher history is available for this probable starter.</p>
          </section>
          <section>
            <h3>Batter vs pitch type</h3>
            <ul v-if="starter.batter_pitch_type_matchups?.length" class="report-list"><li v-for="matchup in starter.batter_pitch_type_matchups" :key="`${matchup.batter.mlb_id}-${matchup.pitch_type}`"><strong>{{ matchup.batter.full_name }} · {{ matchup.pitch_name }}</strong><span>{{ matchup.pitches }} pitches · {{ decimal(matchup.whiff_rate) }}% whiff</span></li></ul>
            <p v-else class="report-callout">No batter-vs-pitch-type history is available for this probable starter.</p>
          </section>
        </div>
        <section class="report-attack-plan" data-test="hitter-attack-plan">
          <h3>Evidence-backed hitter attack plan</h3>
          <article v-for="plan in starter.hitter_attack_plan || []" :key="plan.key">
            <strong>{{ plan.label }}</strong>
            <p>{{ plan.recommendation }}</p>
            <small>{{ plan.rationale }}</small>
            <RouterLink
              v-for="item in plan.evidence || []"
              :key="`${plan.key}-${item.pitch_id}`"
              :to="{ name: 'game-summary', params: { id: item.game_id }, hash: `#pitch-${item.pitch_id}` }"
            >Supporting pitch →</RouterLink>
          </article>
        </section>
      </section>
      <section class="report-panel" v-if="snapshot.bullpen">
        <header><p>Relief corps</p><h2>Bullpen availability</h2><span>{{ snapshot.bullpen.games_sampled }} games sampled</span></header>
        <table><thead><tr><th>Pitcher</th><th>Recent pitches</th><th>Last used</th><th>Status</th></tr></thead>
          <tbody><tr v-for="pitcher in snapshot.bullpen.pitchers || []" :key="pitcher.player.id"><th>{{ pitcher.player.full_name }}</th><td>{{ pitcher.pitches }}</td><td>{{ formatDate(pitcher.last_used_on) }}</td><td>{{ pitcher.available ? 'Available' : 'Rest / monitor' }}</td></tr></tbody>
        </table>
      </section>
    </template>
  </main>
</template>

<style scoped>
.report-shell { min-height: calc(100vh - 74px); padding: 2.5rem 1.25rem 5rem; background: radial-gradient(circle at 85% 0,rgba(24,77,116,.2),transparent 30%),linear-gradient(180deg,#f7f1e3,#ead8b6); }
.report-shell > * { width: min(1280px,calc(100vw - 2.5rem)); margin-inline: auto; }
.report-back { display: inline-block; width: auto; margin-bottom: 1rem; color: #6d2a25; font-weight: 800; text-decoration: none; }
.report-hero,.report-panel { border: 1px solid rgba(16,38,61,.13); border-radius: 24px; background: rgba(255,252,244,.94); box-shadow: 0 18px 45px rgba(64,43,20,.1); }
.report-hero { display: flex; justify-content: space-between; gap: 2rem; padding: 2rem; color: #fffaf0; background: #10263d; }
.report-hero p,.report-panel > header p { margin: 0 0 .3rem; color: #b79569; font-size: .7rem; font-weight: 900; letter-spacing: .1em; text-transform: uppercase; }
.report-hero h1,.report-panel h2 { font-family: 'Avenir Next Condensed',sans-serif; text-transform: uppercase; }
.report-hero h1 { font-size: clamp(2rem,5vw,4.5rem); line-height: .95; }
.report-hero span { color: #c8d3da; }
.report-stamp { align-self: center; padding: 1rem; border: 1px solid rgba(255,255,255,.16); border-radius: 16px; text-align: right; }
.report-stamp small,.report-stamp strong,.report-stamp span { display: block; }
.report-stamp small { color: #b79569; text-transform: uppercase; }
.report-stamp span { margin-top: .2rem; font-size: .7rem; }
.report-print { align-self: center; padding: .7rem 1rem; border: 1px solid rgba(255,255,255,.25); border-radius: 999px; color: #fffaf0; background: rgba(255,255,255,.08); font: inherit; font-weight: 900; cursor: pointer; }
.report-refresh { align-self: center; padding: .7rem 1rem; border: 1px solid #b79569; border-radius: 999px; color: #10263d; background: #f0d39b; font: inherit; font-weight: 900; cursor: pointer; }
.report-panel { margin-top: 1rem; padding: 1.4rem; }
.report-panel > header { display: flex; justify-content: space-between; gap: 1rem; align-items: end; margin-bottom: 1rem; }
.report-panel h2 { color: #10263d; font-size: 2rem; }
.report-series > div,.report-metrics { display: grid; grid-template-columns: repeat(auto-fit,minmax(180px,1fr)); gap: .7rem; }
.report-series article,.report-metrics div,.report-columns aside article { padding: .8rem; border-radius: 14px; background: rgba(16,38,61,.05); }
.report-lineup { margin-bottom: 1rem; }
.report-lineup ol { display: grid; grid-template-columns: repeat(auto-fit,minmax(210px,1fr)); gap: .45rem; padding: 0; list-style: none; }
.report-lineup li { display: flex; justify-content: space-between; gap: .5rem; padding: .55rem .7rem; border-radius: 10px; background: rgba(16,38,61,.05); }
.report-lineup small { color: #667680; }
.report-data-status > p { max-width: 62rem; color: #667680; }
.report-data-status__grid { display: grid; grid-template-columns: repeat(auto-fit,minmax(220px,1fr)); gap: .7rem; }
.report-data-status__grid article { display: grid; gap: .25rem; padding: .9rem; border-radius: 14px; background: rgba(16,38,61,.05); }
.report-data-status__grid span { color: #667680; font-size: .85rem; }
.report-series strong,.report-series span,.report-series small { display: block; }
.report-series span,.report-series small { margin-top: .2rem; color: #667680; }
.report-metrics dt { color: #71808c; font-size: .7rem; font-weight: 900; text-transform: uppercase; }
.report-metrics dd { margin-top: .25rem; color: #8d392e; font-size: 1.5rem; font-weight: 900; }
.report-columns { display: grid; grid-template-columns: minmax(0,1.7fr) minmax(260px,.7fr); gap: 1rem; }
.report-columns h3 { margin: .4rem 0 .6rem; color: #173652; font-size: .75rem; letter-spacing: .08em; text-transform: uppercase; }
table { width: 100%; border-collapse: collapse; font-size: .78rem; }
th,td { padding: .65rem; border-bottom: 1px solid rgba(16,38,61,.1); text-align: right; }
th:first-child { text-align: left; }
thead { color: #697784; background: #e7edf1; }
td a,.report-columns aside a { display: block; color: #8d392e; font-size: .68rem; font-weight: 850; }
.report-columns aside { display: grid; align-content: start; gap: .5rem; }
.report-columns aside article strong,.report-columns aside article span { display: block; }
.report-columns aside article span { margin: .2rem 0; color: #667680; font-size: .75rem; }
.report-tendency-grid { display: grid; grid-template-columns: repeat(2,minmax(0,1fr)); gap: 1rem; margin-top: 1.25rem; }
.report-tendency-grid section { min-width: 0; }
.report-tendency-grid h3,.report-attack-plan h3 { margin: .4rem 0 .6rem; color: #173652; font-size: .75rem; letter-spacing: .08em; text-transform: uppercase; }
.report-callout { margin: 0 0 .5rem; color: #667680; font-size: .78rem; }
.report-list { display: grid; gap: .35rem; margin: 0; padding: 0; list-style: none; }
.report-list li { display: flex; justify-content: space-between; gap: 1rem; padding: .55rem .65rem; border-radius: 10px; background: rgba(16,38,61,.05); font-size: .78rem; }
.report-list span { color: #8d392e; font-weight: 900; }
.report-attack-plan { margin-top: 1.25rem; padding-top: 1rem; border-top: 1px solid rgba(16,38,61,.1); }
.report-attack-plan article { display: grid; gap: .2rem; margin-top: .55rem; padding: .75rem; border-left: 4px solid #b79569; border-radius: 0 12px 12px 0; background: rgba(16,38,61,.04); }
.report-attack-plan p,.report-attack-plan small { margin: 0; color: #526572; font-size: .78rem; }
.report-attack-plan a { color: #8d392e; font-size: .7rem; font-weight: 900; }
.report-state { display: grid; min-height: 50vh; place-items: center; }
.report-state--error { color: #7d291f; }
@media (max-width: 760px) { .report-hero { flex-direction: column; } .report-stamp { align-self: stretch; text-align: left; } .report-columns,.report-tendency-grid { grid-template-columns: 1fr; } }
@media print { .report-shell { min-height: auto; padding: 0; background: #fff; } .report-shell > * { width: 100%; } .report-back,.report-print { display: none; } .report-hero,.report-panel { box-shadow: none; break-inside: avoid; } .report-hero { color: #10263d; background: #fff; } .report-hero h1,.report-hero span,.report-stamp strong,.report-stamp span { color: #10263d; } .report-stamp { border-color: #ccd5da; } }
</style>
