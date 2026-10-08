<script setup>
import { computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'

import { usePostseason } from '../composables/usePostseason'
import { teamLogoUrl } from '../config'

const { postseason, loading, error, load } = usePostseason()

const alRounds = computed(() => roundsFor('AL'))
const nlRounds = computed(() => roundsFor('NL').reverse())
const worldSeries = computed(() => postseason.value.rounds.find((round) => round.key === 'world-series')?.series?.[0] || null)

onMounted(load)

function teamName(game, side) {
  return game[`${side}_team`]?.abbreviation || game[`${side}_team`]?.name || 'TBD'
}

function score(game, side) {
  const value = game[`${side}_score`]
  return value === null || value === undefined ? '—' : value
}

function gameLabel(game) {
  return game.detailed_status || (game.status === 'final' ? 'Final' : 'Upcoming')
}

function teamLogo(team) {
  return team?.logo_url || (team?.mlb_id ? teamLogoUrl(team.mlb_id) : null)
}

function seriesRecord(series, team) {
  let wins = 0
  let losses = 0
  for (const game of series.games || []) {
    if (game.status !== 'final') continue
    const homeScore = Number(game.home_score)
    const awayScore = Number(game.away_score)
    if (!Number.isFinite(homeScore) || !Number.isFinite(awayScore)) continue
    const teamWon = game.home_team?.id === team.id ? homeScore > awayScore : awayScore > homeScore
    teamWon ? wins++ : losses++
  }
  return `${wins}–${losses}`
}

function seriesState(series) {
  const finalGames = (series.games || []).filter((game) => game.status === 'final').length
  return finalGames ? `${finalGames} game${finalGames === 1 ? '' : 's'} played` : 'Series pending'
}

function roundsFor(league) {
  return (postseason.value.rounds || [])
    .filter((round) => round.key !== 'world-series')
    .map((round) => ({ ...round, series: round.series.filter((series) => series.name.startsWith(league)) }))
    .filter((round) => round.series.length)
}
</script>

<template>
  <main class="postseason-shell">
    <section v-if="loading" class="postseason-state">Loading postseason…</section>
    <section v-else-if="error" class="postseason-state postseason-state--error">
      <p>{{ error }}</p><button type="button" @click="load">Try again</button>
    </section>
    <section v-else-if="!postseason.active" class="postseason-state">
      <p>The postseason page will appear when the current season reaches the playoffs.</p>
    </section>
    <template v-else>
      <section class="postseason-hero">
        <div><p>October baseball</p><h1>{{ postseason.season }} postseason</h1><span>Every series, result, and next game in one bracket.</span></div>
      </section>

      <section class="postseason-panel postseason-bracket-panel" data-test="postseason-bracket">
        <header><div><p>Road to the championship</p><h2>Playoff tree</h2></div><span>{{ postseason.rounds.length }} rounds</span></header>
        <div class="postseason-bracket" aria-label="MLB postseason playoff tree">
          <div class="postseason-bracket__side postseason-bracket__side--al">
            <div class="postseason-bracket__league-label">American League</div>
            <div v-for="round in alRounds" :key="round.key" class="postseason-round" :class="'postseason-round--' + round.key">
              <div class="postseason-round__heading"><span>{{ round.name }}</span><small>{{ round.series.length }}</small></div>
              <div class="postseason-series-list">
                <article v-for="series in round.series" :key="series.key" class="postseason-series">
                  <div class="postseason-series__heading"><h3>{{ series.name }}</h3><small>{{ seriesState(series) }}</small></div>
                  <RouterLink v-for="team in series.teams" :key="team.id" :to="{ name: 'team-profile', params: { id: team.id } }" class="postseason-series__team">
                    <img v-if="teamLogo(team)" :src="teamLogo(team)" :alt="team.name + ' logo'" />
                    <span><b>{{ team.abbreviation }}</b><small>{{ team.name }}</small></span>
                    <strong>{{ seriesRecord(series, team) }}</strong>
                  </RouterLink>
                  <div class="postseason-series__games"><RouterLink v-for="game in series.games" :key="game.id" :to="{ name: 'game-summary', params: { id: game.id } }">G{{ game.series_game_number || game.official_date }} · {{ game.away_score ?? '—' }}–{{ game.home_score ?? '—' }}</RouterLink></div>
                </article>
              </div>
            </div>
          </div>
          <div class="postseason-bracket__championship">
            <span>Championship</span><strong>World Series</strong><small>Every game leads here</small><div aria-hidden="true">◆</div>
            <template v-if="worldSeries">
              <RouterLink v-for="team in worldSeries.teams" :key="team.id" :to="{ name: 'team-profile', params: { id: team.id } }" class="postseason-series__team">
                <img v-if="teamLogo(team)" :src="teamLogo(team)" :alt="team.name + ' logo'" /><span><b>{{ team.abbreviation }}</b></span><strong>{{ seriesRecord(worldSeries, team) }}</strong>
              </RouterLink>
            </template>
          </div>
          <div class="postseason-bracket__side postseason-bracket__side--nl">
            <div class="postseason-bracket__league-label">National League</div>
            <div v-for="round in nlRounds" :key="round.key" class="postseason-round" :class="'postseason-round--' + round.key">
              <div class="postseason-round__heading"><span>{{ round.name }}</span><small>{{ round.series.length }}</small></div>
              <div class="postseason-series-list">
                <article v-for="series in round.series" :key="series.key" class="postseason-series">
                  <div class="postseason-series__heading"><h3>{{ series.name }}</h3><small>{{ seriesState(series) }}</small></div>
                  <RouterLink v-for="team in series.teams" :key="team.id" :to="{ name: 'team-profile', params: { id: team.id } }" class="postseason-series__team">
                    <img v-if="teamLogo(team)" :src="teamLogo(team)" :alt="team.name + ' logo'" /><span><b>{{ team.abbreviation }}</b><small>{{ team.name }}</small></span><strong>{{ seriesRecord(series, team) }}</strong>
                  </RouterLink>
                  <div class="postseason-series__games"><RouterLink v-for="game in series.games" :key="game.id" :to="{ name: 'game-summary', params: { id: game.id } }">G{{ game.series_game_number || game.official_date }} · {{ game.away_score ?? '—' }}–{{ game.home_score ?? '—' }}</RouterLink></div>
                </article>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section class="postseason-panel" data-test="postseason-upcoming">
        <header><div><p>Next on the diamond</p><h2>Upcoming games</h2></div><span>{{ postseason.upcoming_games.length }}</span></header>
        <div v-if="postseason.upcoming_games.length" class="postseason-game-list">
          <RouterLink v-for="game in postseason.upcoming_games" :key="game.id" :to="{ name: 'game-summary', params: { id: game.id } }" class="postseason-game">
            <time>{{ game.official_date }}</time><span>{{ teamName(game, 'away') }} <b>{{ score(game, 'away') }}</b></span><span>{{ teamName(game, 'home') }} <b>{{ score(game, 'home') }}</b></span><small>{{ gameLabel(game) }}</small>
          </RouterLink>
        </div>
        <p v-else class="postseason-empty">No upcoming games are stored.</p>
      </section>

      <section class="postseason-panel" data-test="postseason-results">
        <header><div><p>Completed games</p><h2>Results</h2></div><span>{{ postseason.game_results.length }}</span></header>
        <div class="postseason-results"><RouterLink v-for="game in postseason.game_results" :key="game.id" :to="{ name: 'game-summary', params: { id: game.id } }">{{ game.official_date }} · {{ teamName(game, 'away') }} {{ score(game, 'away') }} — {{ teamName(game, 'home') }} {{ score(game, 'home') }}</RouterLink></div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.postseason-shell { width: min(1440px, calc(100% - 2.5rem)); margin: 0 auto; padding: 2.4rem 0 5rem; color: #10263d; }
.postseason-hero { display:flex; justify-content:space-between; gap:2rem; align-items:center; padding:clamp(1.4rem,4vw,2.5rem); border-radius:28px; color:#fffaf0; background:linear-gradient(125deg,#10263d 0%,#183e5b 56%,#a93627 145%); box-shadow:0 24px 70px rgba(16,38,61,.18); }
.postseason-hero p,.postseason-panel header p { margin:0; color:#a93627; font-size:.7rem; font-weight:900; letter-spacing:.16em; text-transform:uppercase; }.postseason-hero p { color:#e8b276; }.postseason-hero h1 { margin:.35rem 0 .55rem; font-family:'Avenir Next Condensed',sans-serif; font-size:clamp(2.7rem,6vw,5.2rem); line-height:.9; text-transform:uppercase; }.postseason-hero span { color:#d8e1e7; }.postseason-hero__badge { min-width:130px; padding:1rem; border:1px solid rgba(255,255,255,.25); border-radius:18px; color:#e8b276; font-size:1.5rem; font-weight:900; text-align:center; }.postseason-hero__badge small { color:#fffaf0; font-size:.7rem; text-transform:uppercase; }
.postseason-panel { margin-top:1.25rem; padding:clamp(1.1rem,3vw,1.65rem); border:1px solid rgba(16,38,61,.1); border-radius:25px; background:rgba(255,252,245,.86); box-shadow:0 14px 38px rgba(73,52,24,.065); }.postseason-panel > header { display:flex; justify-content:space-between; gap:1rem; align-items:end; margin-bottom:1rem; }.postseason-panel h2 { margin:.2rem 0 0; font-family:'Avenir Next Condensed',sans-serif; font-size:clamp(1.8rem,4vw,2.7rem); line-height:1; text-transform:uppercase; }.postseason-panel header > span { color:#62707a; font-size:.77rem; font-weight:800; }.postseason-team-grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(220px,1fr)); gap:.65rem; }.postseason-team,.postseason-game,.postseason-results a { display:grid; grid-template-columns:auto 1fr auto; gap:.65rem; align-items:center; padding:.75rem; border:1px solid rgba(16,38,61,.1); border-radius:13px; color:#10263d; background:#fff; text-decoration:none; }.postseason-team:hover,.postseason-game:hover,.postseason-results a:hover { border-color:#a93627; }.postseason-team strong { display:grid; width:38px; height:38px; place-items:center; border-radius:50%; color:#fff; background:#183e5b; }.postseason-team span { font-weight:800; }.postseason-team b { color:#a93627; }.postseason-game-list,.postseason-results { display:grid; gap:.55rem; }.postseason-game { grid-template-columns:auto 1fr 1fr auto; }.postseason-game time,.postseason-game small { color:#687782; font-size:.72rem; }.postseason-game span { font-weight:800; }.postseason-game span b { float:right; color:#a93627; }.postseason-results a { grid-template-columns:1fr; font-weight:800; }.postseason-bracket { display:grid; grid-template-columns:repeat(4,minmax(220px,1fr)); gap:1rem; overflow-x:auto; padding-bottom:.5rem; }.postseason-round { min-width:220px; }.postseason-round h3 { margin:0 0 .7rem; color:#a93627; font-size:.75rem; letter-spacing:.1em; text-transform:uppercase; }.postseason-series-list { display:grid; gap:1.4rem; }.postseason-series { position:relative; padding:.8rem; border:1px solid rgba(16,38,61,.14); border-radius:14px; background:#fff; }.postseason-series h4 { margin:0 0 .6rem; font-size:.75rem; }.postseason-series__team { display:flex; justify-content:space-between; gap:.5rem; padding:.34rem 0; border-top:1px solid rgba(16,38,61,.08); font-size:.77rem; }.postseason-series__team span { color:#a93627; font-weight:900; }.postseason-series__games { display:grid; gap:.25rem; margin-top:.55rem; }.postseason-series__games a { color:#60717d; font-size:.68rem; text-decoration:none; }.postseason-state { padding:3rem; border-radius:20px; color:#62707a; background:rgba(231,237,241,.65); text-align:center; }.postseason-state--error { color:#8f2d24; }.postseason-state button { padding:.6rem .9rem; border:0; border-radius:10px; color:white; background:#10263d; font-weight:800; }
.postseason-bracket-panel { overflow:hidden; background:linear-gradient(145deg,rgba(255,252,245,.96),rgba(232,239,243,.82)); }
.postseason-bracket { grid-template-columns:repeat(4,minmax(190px,1fr)) minmax(155px,.7fr); gap:0; min-width:930px; padding:1rem 0 .8rem; }
.postseason-round { position:relative; min-width:190px; padding:0 .7rem; }
.postseason-round:not(:last-of-type)::after { position:absolute; top:50%; right:-1px; width:1.4rem; height:2px; background:#bdc8cf; content:''; }
.postseason-round__heading { display:flex; justify-content:space-between; align-items:baseline; min-height:2.1rem; padding:0 .15rem .55rem; border-bottom:2px solid #c7d0d5; color:#a93627; font-size:.74rem; font-weight:900; letter-spacing:.12em; text-transform:uppercase; }
.postseason-round__heading small { color:#77858d; font-size:.58rem; letter-spacing:.02em; text-transform:none; }
.postseason-series-list { display:flex; flex-direction:column; justify-content:space-around; gap:1.1rem; min-height:470px; padding:.9rem 0; }
.postseason-series { position:relative; padding:.7rem; border-radius:15px; background:rgba(255,255,255,.94); box-shadow:0 8px 18px rgba(16,38,61,.08); }
.postseason-series::after { position:absolute; top:50%; right:-.7rem; width:.7rem; height:2px; background:#bdc8cf; content:''; }
.postseason-series__heading { display:flex; justify-content:space-between; gap:.4rem; align-items:baseline; margin-bottom:.4rem; }
.postseason-series__heading h3 { margin:0; color:#10263d; font-size:.66rem; line-height:1.1; text-transform:uppercase; }
.postseason-series__heading small { color:#77858d; font-size:.54rem; white-space:nowrap; }
.postseason-series__team { display:grid; grid-template-columns:25px 1fr auto; gap:.45rem; align-items:center; padding:.42rem 0; color:#10263d; text-decoration:none; }
.postseason-series__team img { width:24px; height:24px; object-fit:contain; }
.postseason-series__team span { display:grid; gap:.08rem; min-width:0; }
.postseason-series__team b { font-size:.72rem; }
.postseason-series__team small { overflow:hidden; color:#73818a; font-size:.56rem; text-overflow:ellipsis; white-space:nowrap; }
.postseason-series__team strong { color:#a93627; font-size:.72rem; }
.postseason-series__games { margin-top:.45rem; padding-top:.4rem; border-top:1px solid rgba(16,38,61,.09); }
.postseason-series__games a { overflow:hidden; color:#60717d; font-size:.58rem; text-decoration:none; text-overflow:ellipsis; white-space:nowrap; }
.postseason-bracket__championship { display:flex; flex-direction:column; justify-content:center; align-items:center; gap:.35rem; min-width:155px; margin:.9rem .7rem; border:1px solid rgba(169,54,39,.25); border-radius:18px; color:#10263d; background:linear-gradient(160deg,#fff,#f3e6d7); text-align:center; }
.postseason-bracket__championship span { color:#a93627; font-size:.6rem; font-weight:900; letter-spacing:.15em; text-transform:uppercase; }
.postseason-bracket__championship strong { font-family:'Avenir Next Condensed',sans-serif; font-size:1.35rem; line-height:.95; text-transform:uppercase; }
.postseason-bracket__championship small { color:#6e7b83; font-size:.6rem; }
.postseason-bracket__championship div { color:#c58b2a; font-size:2rem; line-height:1; }
.postseason-bracket { grid-template-columns:minmax(0,1fr) 190px minmax(0,1fr); min-width:1120px; align-items:stretch; }
.postseason-bracket__side { position:relative; display:grid; grid-template-columns:repeat(3,minmax(170px,1fr)); min-width:0; }
.postseason-bracket__league-label { grid-column:1 / -1; padding:0 .8rem .55rem; border-bottom:2px solid #c7d0d5; color:#10263d; font-size:.72rem; font-weight:900; letter-spacing:.14em; text-align:center; text-transform:uppercase; }
.postseason-bracket__side--al .postseason-round:not(:last-child)::after { right:-.7rem; }
.postseason-bracket__side--nl .postseason-round:not(:last-child)::after { right:auto; left:-.7rem; }
.postseason-bracket__side--nl .postseason-round { order:initial; }
.postseason-bracket__championship { align-self:stretch; }
@media (max-width:760px) { .postseason-shell { width:calc(100% - 1.4rem); padding-top:1rem; }.postseason-hero { align-items:stretch; flex-direction:column; }.postseason-game { grid-template-columns:1fr 1fr; }.postseason-game time,.postseason-game small { grid-column:1 / -1; }.postseason-bracket-panel { padding-right:.7rem; padding-left:.7rem; }.postseason-bracket { min-width:930px; } }
</style>
