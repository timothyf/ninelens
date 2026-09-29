<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { useStandings } from '../composables/useStandings'

const route = useRoute()
const router = useRouter()
const requestedSeason = computed(() => positiveYear(route.query.season))
const selectedLeague = computed(() => ['american', 'national'].includes(route.query.league) ? route.query.league : 'american')
const { standings, loading, error, refresh } = useStandings(requestedSeason)

const selectedSeason = computed(() => requestedSeason.value || standings.value.season)
const currentLeague = computed(() => standings.value.leagues.find((league) => league.key === selectedLeague.value) || { divisions: [] })

function positiveYear(value) {
  const year = Number(value)
  return Number.isInteger(year) && year > 1800 ? year : null
}

function updateQuery(updates) {
  router.push({ name: 'standings', query: { ...route.query, ...updates } })
}

function selectSeason(value) {
  const season = positiveYear(value)
  if (season) updateQuery({ season: String(season) })
}

function formatPercentage(value) {
  const number = Number(value || 0)
  return number.toFixed(3).replace(/^0/, '')
}

function formatGamesBack(value) {
  return Number(value) === 0 ? '—' : Number(value).toFixed(1).replace(/\.0$/, '')
}

function signed(value) {
  const number = Number(value || 0)
  return `${number > 0 ? '+' : ''}${number}`
}

function formatDate(value) {
  if (!value) return 'No final games stored'
  return `Through ${new Intl.DateTimeFormat('en-US', { month: 'long', day: 'numeric', year: 'numeric' }).format(new Date(`${value}T12:00:00`))}`
}

function formatOdds(value) {
  const number = Number(value || 0)
  if (number > 0 && number < 0.1) return '<0.1%'
  if (number > 99.9 && number < 100) return '>99.9%'
  return `${number.toFixed(1)}%`
}
</script>

<template>
  <main class="standings-shell">
    <section class="standings-hero">
      <div><p>League table</p><h1>MLB standings</h1><span>Division races calculated from NineLens's stored final regular-season games.</span></div>
      <label>
        <span>Season</span>
        <select :value="selectedSeason" data-test="standings-season" :disabled="loading" @change="selectSeason($event.target.value)">
          <option v-for="season in standings.available_seasons" :key="season" :value="season">{{ season }}</option>
        </select>
      </label>
    </section>

    <nav class="standings-tabs" role="tablist" aria-label="League standings">
      <button
        v-for="league in standings.leagues"
        :key="league.key"
        type="button"
        role="tab"
        :aria-selected="selectedLeague === league.key"
        :class="{ 'is-selected': selectedLeague === league.key }"
        :data-test="`standings-league-${league.key}`"
        @click="updateQuery({ league: league.key })"
      >{{ league.name }}</button>
    </nav>

    <div v-if="loading && !standings.leagues.length" class="standings-state" data-test="standings-loading">Calculating standings…</div>
    <div v-else-if="error" class="standings-state standings-state--error" data-test="standings-error">
      <p>{{ error }}</p><button type="button" @click="refresh">Try again</button>
    </div>
    <template v-else>
      <header class="standings-heading">
        <div><p>{{ currentLeague.name }}</p><h2>{{ selectedSeason }} standings</h2></div>
        <div class="standings-season-status" :class="{ 'is-final': standings.season_status === 'final' }">
          <strong>{{ standings.season_status === 'final' ? 'FINAL' : 'IN PROGRESS' }}</strong>
          <span>{{ formatDate(standings.as_of) }}</span>
        </div>
      </header>
      <aside v-if="standings.playoff_odds" class="projection-note" data-test="playoff-odds-note">
        <strong>NineLens playoff projections</strong>
        <span>{{ standings.playoff_odds.simulations.toLocaleString() }} simulations · {{ standings.playoff_odds.remaining_games }} scheduled games remaining</span>
      </aside>
      <div class="standings-divisions" data-test="standings-divisions">
        <section v-for="division in currentLeague.divisions" :key="division.key" class="standings-card" :data-test="`standings-${division.key}`">
          <header><h3>{{ division.name }}</h3><span>{{ division.teams.length }} teams</span></header>
          <div class="standings-table-wrap">
            <table>
              <thead><tr><th scope="col">Team</th><th scope="col">W</th><th scope="col">L</th><th scope="col">PCT</th><th scope="col">GB</th><th scope="col">DIFF</th><th scope="col">PLAYOFF%</th></tr></thead>
              <tbody>
                <tr v-for="row in division.teams" :key="row.team.id">
                  <td>
                    <span>{{ row.rank }}</span>
                    <RouterLink :to="{ name: 'team-profile', params: { id: row.team.id } }">
                      <img :src="row.team.logo_url" alt="" />
                      <b>{{ row.team.abbreviation }}</b><strong>{{ row.team.name }}</strong>
                    </RouterLink>
                  </td>
                  <td>{{ row.wins }}</td><td>{{ row.losses }}</td><td>{{ formatPercentage(row.winning_percentage) }}</td><td>{{ formatGamesBack(row.games_back) }}</td><td :class="{ positive: row.run_differential > 0, negative: row.run_differential < 0 }">{{ signed(row.run_differential) }}</td><td class="playoff-odds">{{ formatOdds(row.playoff_odds?.playoffs) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <p v-if="!division.teams.length">No teams are stored for this division.</p>
        </section>
      </div>

      <section class="wild-card-card" data-test="wild-card-standings">
        <header>
          <div><p>{{ standings.season_status === 'final' ? 'Postseason standings' : 'Postseason race' }}</p><h3>{{ currentLeague.name }} Wild Card</h3></div>
          <span>Top 3 qualify</span>
        </header>
        <div class="standings-table-wrap">
          <table>
            <thead><tr><th scope="col">Team</th><th scope="col">DIV</th><th scope="col">W</th><th scope="col">L</th><th scope="col">PCT</th><th scope="col">WCGB</th><th scope="col">DIFF</th><th scope="col">PLAYOFF%</th></tr></thead>
            <tbody>
              <tr
                v-for="row in currentLeague.wild_card?.teams || []"
                :key="row.team.id"
                :class="{ 'is-wild-card': row.wild_card_position, 'is-cut-line': row.rank === 3 }"
              >
                <td>
                  <span>{{ row.wild_card_position ? `WC${row.wild_card_position}` : row.rank }}</span>
                  <RouterLink :to="{ name: 'team-profile', params: { id: row.team.id } }">
                    <img :src="row.team.logo_url" alt="" />
                    <b>{{ row.team.abbreviation }}</b><strong>{{ row.team.name }}</strong>
                  </RouterLink>
                </td>
                <td>{{ row.division?.name?.replace(/^(AL|NL) /, '') }}</td>
                <td>{{ row.wins }}</td><td>{{ row.losses }}</td><td>{{ formatPercentage(row.winning_percentage) }}</td>
                <td>{{ row.wild_card_position ? 'IN' : formatGamesBack(row.wild_card_games_back) }}</td>
                <td :class="{ positive: row.run_differential > 0, negative: row.run_differential < 0 }">{{ signed(row.run_differential) }}</td>
                <td class="playoff-odds">{{ formatOdds(row.playoff_odds?.playoffs) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p v-if="!currentLeague.wild_card?.teams?.length">No Wild Card standings are available for this league.</p>
      </section>
    </template>
  </main>
</template>

<style scoped>
.standings-shell { width: min(1440px, calc(100% - 2.5rem)); margin: 0 auto; padding: 2.4rem 0 5rem; color: #10263d; }
.standings-hero { display: flex; justify-content: space-between; gap: 2rem; align-items: end; padding: clamp(1.5rem,4vw,2.6rem); border-radius: 30px; color: #fffaf0; background: linear-gradient(125deg,#10263d,#183e5b 65%,#8f2d24 150%); box-shadow: 0 24px 70px rgba(16,38,61,.18); }
.standings-hero p,.standings-heading p { color: #e8b276; font-size: .7rem; font-weight: 900; letter-spacing: .15em; text-transform: uppercase; }
.standings-hero h1 { margin: .3rem 0 .55rem; font-family: 'Avenir Next Condensed',sans-serif; font-size: clamp(3rem,7vw,5.8rem); line-height: .88; text-transform: uppercase; }
.standings-hero > div > span { color: #d4dee5; }
.standings-hero label { display: grid; gap: .35rem; }
.standings-hero label span { color: #e8b276; font-size: .65rem; font-weight: 900; letter-spacing: .1em; text-transform: uppercase; }
.standings-hero select { min-width: 130px; padding: .7rem .9rem; border: 1px solid rgba(255,255,255,.25); border-radius: 11px; color: #fffaf0; background: #183e5b; font: inherit; font-weight: 850; }
.standings-tabs { display: flex; gap: .45rem; margin: 1rem 0; padding: .3rem; border: 1px solid #d9d7ce; border-radius: 16px; background: rgba(255,250,240,.76); }
.standings-tabs button { flex: 1; padding: .75rem 1rem; border: 0; border-radius: 12px; color: #5b6871; background: transparent; font: inherit; font-size: .78rem; font-weight: 900; text-transform: uppercase; cursor: pointer; }
.standings-tabs button.is-selected { color: #fffaf0; background: #10263d; }
.standings-heading { display: flex; justify-content: space-between; align-items: end; margin: 1.2rem .2rem .8rem; }
.standings-heading p { color: #a93627; }
.standings-heading h2 { font-family: 'Avenir Next Condensed',sans-serif; font-size: 2.5rem; line-height: 1; text-transform: uppercase; }
.standings-heading > span { color: #697680; font-size: .75rem; }
.standings-season-status { display: grid; gap: .2rem; justify-items: end; }
.standings-season-status strong { color: #697680; font-size: .72rem; letter-spacing: .12em; }
.standings-season-status.is-final strong { color: #176044; }
.standings-season-status span { color: #697680; font-size: .75rem; }
.standings-divisions { display: grid; grid-template-columns: repeat(3,minmax(0,1fr)); gap: .9rem; }
.standings-card { min-width: 0; overflow: hidden; border: 1px solid #d9d7ce; border-radius: 20px; background: rgba(255,255,255,.76); }
.standings-card > header { display: flex; justify-content: space-between; padding: 1rem 1.1rem; color: #fffaf0; background: #10263d; }
.standings-card h3 { font-family: 'Avenir Next Condensed',sans-serif; font-size: 1.4rem; text-transform: uppercase; }
.standings-card header span { color: #aebcc6; font-size: .68rem; }
.standings-table-wrap { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; }
th,td { padding: .7rem .45rem; border-bottom: 1px solid #ebe8df; text-align: right; }
th { color: #748089; font-size: .62rem; letter-spacing: .06em; }
th:first-child,td:first-child { text-align: left; }
td { font-size: .78rem; font-weight: 750; }
td:first-child { display: flex; gap: .35rem; align-items: center; min-width: 155px; }
td:first-child > span { width: 14px; color: #879198; font-size: .65rem; text-align: center; }
td a { display: grid; grid-template-columns: 26px 34px minmax(0,1fr); gap: .35rem; align-items: center; min-width: 0; color: #10263d; text-decoration: none; }
td img { width: 24px; height: 24px; object-fit: contain; }
td a b { font-size: .68rem; }
td a strong { overflow: hidden; font-size: .72rem; text-overflow: ellipsis; white-space: nowrap; }
.positive { color: #176044; }.negative { color: #9c382c; }
.playoff-odds { color: #176044; font-weight: 950; }
.projection-note { display: flex; justify-content: space-between; gap: 1rem; margin: 0 0 .8rem; padding: .7rem 1rem; border: 1px solid #d7e4dc; border-radius: 12px; color: #315844; background: rgba(231,243,235,.72); font-size: .72rem; }
.projection-note span { color: #607269; }
.standings-card > p,.standings-state { padding: 1.5rem; color: #697680; text-align: center; }
.wild-card-card { margin-top: 1rem; overflow: hidden; border: 1px solid #d9d7ce; border-radius: 20px; background: rgba(255,255,255,.8); }
.wild-card-card > header { display: flex; justify-content: space-between; gap: 1rem; align-items: end; padding: 1rem 1.15rem; color: #fffaf0; background: linear-gradient(110deg,#10263d,#1d4d73); }
.wild-card-card header p { color: #e8b276; font-size: .65rem; font-weight: 900; letter-spacing: .13em; text-transform: uppercase; }
.wild-card-card h3 { margin-top: .12rem; font-family: 'Avenir Next Condensed',sans-serif; font-size: 1.65rem; text-transform: uppercase; }
.wild-card-card header span { color: #c5d1d9; font-size: .7rem; font-weight: 800; }
.wild-card-card table td:first-child { min-width: 190px; }
.wild-card-card tr.is-wild-card { background: rgba(220,239,229,.48); }
.wild-card-card tr.is-cut-line td { border-bottom: 3px solid #a93627; }
.wild-card-card td:first-child > span { width: 28px; color: #a93627; font-weight: 900; }
.wild-card-card > p { padding: 1.4rem; color: #697680; text-align: center; }
.standings-state { border-radius: 18px; background: rgba(255,250,240,.76); }
.standings-state--error { color: #8f2d24; }.standings-state button { margin-top: .7rem; padding: .6rem .9rem; border: 0; border-radius: 9px; color: white; background: #10263d; }
@media (max-width: 1100px) { .standings-divisions { grid-template-columns: 1fr; } }
@media (max-width: 650px) { .standings-shell { width: calc(100% - 1.4rem); padding-top: 1rem; } .standings-hero { align-items: stretch; flex-direction: column; } .standings-heading,.projection-note { align-items: flex-start; flex-direction: column; gap: .35rem; } }
</style>
