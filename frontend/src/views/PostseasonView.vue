<script setup>
import { onMounted } from 'vue'
import { RouterLink } from 'vue-router'

import { usePostseason } from '../composables/usePostseason'

const { postseason, loading, error, load } = usePostseason()

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
        <div class="postseason-hero__badge">{{ postseason.playoff_teams.length }} teams<br><small>in the field</small></div>
      </section>

      <section class="postseason-panel" data-test="postseason-teams">
        <header><div><p>Playoff field</p><h2>Teams</h2></div><span>{{ postseason.playoff_teams.length }} clubs</span></header>
        <div class="postseason-team-grid">
          <RouterLink v-for="entry in postseason.playoff_teams" :key="entry.team.id" :to="{ name: 'team-profile', params: { id: entry.team.id } }" class="postseason-team">
            <strong>{{ entry.team.abbreviation }}</strong><span>{{ entry.team.name }}</span><b>{{ entry.wins }}–{{ entry.losses }}</b>
          </RouterLink>
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

      <section class="postseason-panel postseason-bracket-panel" data-test="postseason-bracket">
        <header><div><p>Road to the championship</p><h2>Playoff tree</h2></div></header>
        <div class="postseason-bracket">
          <div v-for="round in postseason.rounds" :key="round.key" class="postseason-round">
            <h3>{{ round.name }}</h3>
            <div class="postseason-series-list">
              <article v-for="series in round.series" :key="series.key" class="postseason-series">
                <h4>{{ series.name }}</h4>
                <div v-for="team in series.teams" :key="team.id" class="postseason-series__team"><span>{{ team.abbreviation }}</span><b>{{ team.name }}</b></div>
                <div class="postseason-series__games">
                  <RouterLink v-for="game in series.games" :key="game.id" :to="{ name: 'game-summary', params: { id: game.id } }">G{{ game.series_game_number || game.official_date }} · {{ game.away_score ?? '—' }}–{{ game.home_score ?? '—' }}</RouterLink>
                </div>
              </article>
            </div>
          </div>
        </div>
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
@media (max-width:760px) { .postseason-shell { width:calc(100% - 1.4rem); padding-top:1rem; }.postseason-hero { align-items:stretch; flex-direction:column; }.postseason-game { grid-template-columns:1fr 1fr; }.postseason-game time,.postseason-game small { grid-column:1 / -1; } }
</style>
