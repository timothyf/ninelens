<script setup>
import { computed, ref } from 'vue'

import GameScheduleCard from '../components/GameScheduleCard.vue'
import { teamLogoUrl } from '../config'
import { useHomeDashboard } from '../composables/useHomeDashboard'
import nineLensLogo from '../assets/ninelens_logo_v2.png'

const selectedLeague = ref('all')
const { dashboard, loading, error, refresh } = useHomeDashboard(selectedLeague)

const briefingDate = computed(() => formatDate(dashboard.value.as_of, { weekday: 'long', month: 'long', day: 'numeric' }))
const lastUpdatedAt = computed(() => {
  const values = Object.values(dashboard.value.freshness || {}).filter(Boolean)
  return values.sort().at(-1) || null
})
const leaderSections = computed(() => [
  { key: 'batting', label: 'Batting', leaders: dashboard.value.leaders.filter((leader) => leader.category === 'batting') },
  { key: 'pitching', label: 'Pitching', leaders: dashboard.value.leaders.filter((leader) => leader.category === 'pitching') },
])

function formatDate(value, options = { month: 'short', day: 'numeric' }) {
  if (!value) return 'Today'
  const date = new Date(`${value}T12:00:00`)
  return new Intl.DateTimeFormat('en-US', options).format(date)
}

function formatTimestamp(value) {
  if (!value) return 'Not available'
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }).format(new Date(value))
}

function leaderValue(leader, value) {
  const number = Number(value)
  if (!Number.isFinite(number)) return '—'
  if (leader.key === 'avg') return number.toFixed(3).replace(/^0\./, '.')
  if (leader.key === 'ops') return number.toFixed(3)
  if (leader.key === 'ERA') return number.toFixed(2)
  if (['battingWAR', 'pitchingWAR'].includes(leader.key)) return number.toFixed(1)
  return Math.round(number).toLocaleString()
}

function teamLogo(team) {
  return team?.logo_url || (team?.mlb_id ? teamLogoUrl(team.mlb_id) : null)
}

function record(entry, recent = false) {
  const wins = recent ? entry.recent_wins : entry.wins
  const losses = recent ? entry.recent_losses : entry.losses
  const ties = recent ? entry.recent_ties : entry.ties
  return [wins, losses, ...(Number(ties || 0) > 0 ? [ties] : [])].join('-')
}

function recordLast30(entry) {
  return [entry.recent_30_wins, entry.recent_30_losses, ...(Number(entry.recent_30_ties || 0) > 0 ? [entry.recent_30_ties] : [])].join('-')
}

function signed(value) {
  const number = Number(value || 0)
  return `${number > 0 ? '+' : ''}${number}`
}
</script>

<template>
  <main class="home-shell">
    <section class="home-hero">
      <div class="home-hero__brand">
        <img :src="nineLensLogo" alt="NineLens Baseball" />
        <div class="home-hero__baseball" aria-hidden="true"><span>Baseball Intelligence</span></div>
      </div>
      <div class="home-hero__copy">
        <h1>Baseball intelligence,<br /> brought into focus.</h1>
        <p>
          Track today’s slate, scan the league’s top performers, and move directly into the player and team analysis
          behind the numbers.
        </p>
        <div class="home-hero__tools">
          <div class="home-actions">
            <RouterLink class="home-button" :to="{ name: 'stat-explorer' }">Explore league stats</RouterLink>
            <RouterLink class="home-button home-button--secondary" :to="{ name: 'teams' }">Browse all teams</RouterLink>
          </div>
          <aside class="home-hero__signal" aria-label="NineLens quick start">
            <span>Start with a name</span>
            <strong>Find any player from the search bar above.</strong>
            <small>Jump from season totals into career history, rolling trends, pitch-level analysis, and contextual
              benchmarks.</small>
          </aside>
        </div>
      </div>
    </section>

    <div v-if="loading" class="home-state" data-test="home-loading">
      <span aria-hidden="true"></span>
      Building today’s briefing…
    </div>
    <div v-else-if="error" class="home-state home-state--error" data-test="home-error">
      <p>{{ error }}</p>
      <button type="button" @click="refresh">Try again</button>
    </div>

    <template v-else>
      <section class="home-panel slate-panel" data-test="today-games">
        <header class="home-heading">
          <div>
            <p class="home-eyebrow">{{ dashboard.games.some((game) => game.upcoming) ? 'Upcoming game' : 'Today’s slate' }}</p>
            <h2>Games around the league</h2>
          </div>
          <span>{{ dashboard.games.length }} {{ dashboard.games.length === 1 ? 'game' : 'games' }}</span>
        </header>
        <div v-if="dashboard.games.length" class="game-grid">
          <GameScheduleCard v-for="game in dashboard.games" :key="game.id" :game="game" />
        </div>
        <p v-else class="home-empty">No games are scheduled for {{ briefingDate }}.</p>
      </section>

      <section class="home-panel" data-test="home-leaders">
        <header class="home-heading">
          <div>
            <p class="home-eyebrow">At the top</p>
            <h2>{{ dashboard.season }} league leaders</h2>
          </div>
          <label class="leader-league-filter">League<select v-model="selectedLeague" :disabled="loading" data-test="leader-league-select">
            <option value="all">All MLB</option>
            <option value="american">American League</option>
            <option value="national">National League</option>
          </select></label>
          <RouterLink :to="{ name: 'stat-explorer' }">Open Stat Explorer →</RouterLink>
        </header>
        <div v-for="section in leaderSections" :key="section.key" class="leader-section" :data-test="`leader-section-${section.key}`">
          <header class="leader-section__heading"><h3>{{ section.label }}</h3></header>
          <div class="leader-grid">
            <article v-for="leader in section.leaders" :key="leader.key" class="leader-card">
              <header>
                <h3>{{ leader.label }}</h3><small v-if="leader.qualifier">{{ leader.qualifier }}</small>
              </header>
              <ol v-if="leader.entries.length">
                <li v-for="entry in leader.entries" :key="entry.player.id">
                  <span>{{ entry.rank }}</span>
                  <RouterLink :to="{ name: 'player-profile', params: { id: entry.player.id } }">
                    <strong>{{ entry.player.full_name }}</strong><small>{{ entry.team.abbreviation }}</small>
                  </RouterLink>
                  <b>{{ leaderValue(leader, entry.value) }}</b>
                </li>
              </ol>
              <p v-else>No qualified leaders available.</p>
            </article>
          </div>
        </div>
      </section>

      <section class="home-panel" data-test="league-pulse">
        <header class="home-heading">
          <div>
            <p class="home-eyebrow">League pulse</p>
            <h2>Teams setting the pace</h2>
          </div>
          <RouterLink :to="{ name: 'teams' }">View team directory →</RouterLink>
        </header>
        <div class="pulse-grid">
          <article>
            <h3>Best records</h3>
            <ol>
              <li v-for="entry in dashboard.team_pulse.best_records" :key="entry.team.id">
                <RouterLink :to="{ name: 'team-profile', params: { id: entry.team.id } }"><img v-if="teamLogo(entry.team)" class="pulse-team-logo" :src="teamLogo(entry.team)" :alt="`${entry.team.name} logo`" /><span v-else class="pulse-team-abbreviation">{{ entry.team.abbreviation }}</span>{{ entry.team.name }}</RouterLink>
                <strong>{{ record(entry) }}</strong>
              </li>
            </ol>
          </article>
          <article>
            <h3>Run differential</h3>
            <ol>
              <li v-for="entry in dashboard.team_pulse.run_differential" :key="entry.team.id">
                <RouterLink :to="{ name: 'team-profile', params: { id: entry.team.id } }"><img v-if="teamLogo(entry.team)" class="pulse-team-logo" :src="teamLogo(entry.team)" :alt="`${entry.team.name} logo`" /><span v-else class="pulse-team-abbreviation">{{ entry.team.abbreviation }}</span>{{ entry.team.name }}</RouterLink>
                <strong>{{ signed(entry.run_differential) }}</strong>
              </li>
            </ol>
          </article>
          <article>
            <h3>Last {{ dashboard.team_pulse.recent_form[0]?.recent_games || 10 }} games</h3>
            <ol>
              <li v-for="entry in dashboard.team_pulse.recent_form" :key="entry.team.id">
                <RouterLink :to="{ name: 'team-profile', params: { id: entry.team.id } }"><img v-if="teamLogo(entry.team)" class="pulse-team-logo" :src="teamLogo(entry.team)" :alt="`${entry.team.name} logo`" /><span v-else class="pulse-team-abbreviation">{{ entry.team.abbreviation }}</span>{{ entry.team.name }}</RouterLink>
                <strong>{{ record(entry, true) }}</strong>
              </li>
            </ol>
          </article>
          <article>
            <h3>Last 30 games</h3>
            <ol>
              <li v-for="entry in dashboard.team_pulse.last_30_form" :key="entry.team.id">
                <RouterLink :to="{ name: 'team-profile', params: { id: entry.team.id } }"><img v-if="teamLogo(entry.team)" class="pulse-team-logo" :src="teamLogo(entry.team)" :alt="`${entry.team.name} logo`" /><span v-else class="pulse-team-abbreviation">{{ entry.team.abbreviation }}</span>{{ entry.team.name }}</RouterLink>
                <strong>{{ recordLast30(entry) }}</strong>
              </li>
            </ol>
            <p v-if="!dashboard.team_pulse.last_30_form?.length" class="home-empty">No recent team results available.
            </p>
          </article>
        </div>
      </section>

      <section class="quick-grid" aria-label="Explore NineLens">
        <RouterLink :to="{ name: 'stat-explorer' }"><span>01</span><strong>Stat Explorer</strong><small>Filter and
            compare batting, pitching, and Statcast data.</small></RouterLink>
        <RouterLink :to="{ name: 'teams' }"><span>02</span><strong>Team Profiles</strong><small>Review records,
            rankings, recent form, schedules, and rosters.</small></RouterLink>
        <div><span>03</span><strong>Player Profiles</strong><small>Use player search to open career rates, trends, and
            benchmarks.</small></div>
      </section>

      <footer class="home-freshness">
        <span>NineLens data briefing</span>
        <small>Latest stored update {{ formatTimestamp(lastUpdatedAt) }}</small>
      </footer>
    </template>
  </main>
</template>

<style scoped>
.home-shell {
  width: min(1440px, calc(100% - 2.5rem));
  margin: 0 auto;
  padding: 2.4rem 0 5rem;
  color: #10263d;
}

.home-hero {
  position: relative;
  display: grid;
  grid-template-columns: minmax(330px, .95fr) minmax(0, 1.45fr);
  gap: clamp(2rem, 5vw, 5rem);
  align-items: center;
  min-height: 510px;
  padding: clamp(2rem, 3vw, 4rem);
  overflow: hidden;
  border-radius: 30px;
  color: #fffaf0;
  background: linear-gradient(115deg, #0d293f 0%, #17435f 58%, #413542 130%);
  box-shadow: 0 24px 70px rgba(16, 38, 61, .18);
}

.home-hero::after {
  position: absolute;
  right: -90px;
  bottom: -165px;
  width: 390px;
  height: 390px;
  border: 45px solid rgba(255, 250, 240, .045);
  border-radius: 50%;
  content: '';
}

.home-hero__brand,
.home-hero__copy {
  position: relative;
  z-index: 1;
  min-width: 0;
}

.home-hero__brand {
  display: grid;
  place-items: center;
  margin-top: -40px;
}

.home-hero__brand img {
  display: block;
  object-fit: contain;
  width: min(34vw, 500px);
  filter:
    drop-shadow(0 6px 8px rgba(0, 0, 0, 0.9))
    drop-shadow(0 0 4px rgba(90, 180, 235, 0.65));
}

.home-hero__baseball {
  display: grid;
  grid-template-columns: minmax(30px, 1fr) auto minmax(30px, 1fr);
  gap: clamp(.75rem, 2vw, 1.25rem);
  align-items: center;
  width: min(93%, 490px);
  margin-top: .25rem;
  color: #fffaf0;
  display: none;
}

.home-hero__baseball::before,
.home-hero__baseball::after {
  height: 2px;
  background: linear-gradient(90deg, transparent, #fffaf0 32%, #fffaf0);
  content: '';
}

.home-hero__baseball::after {
  transform: scaleX(-1);
}

.home-hero__baseball span {
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: clamp(.78rem, 1.15vw, 1.05rem);
  font-weight: 900;
  letter-spacing: .55em;
  line-height: 1;
  text-transform: uppercase;
}

.home-eyebrow {
  margin: 0;
  color: #a93627;
  font-size: .71rem;
  font-weight: 900;
  letter-spacing: .16em;
  text-transform: uppercase;
}

.home-hero h1 {
  max-width: 850px;
  margin: 0 0 1.1rem;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 60px;
  line-height: .96;
  letter-spacing: -.025em;
  font-size: clamp(2.65rem, 14vw, 4rem);
}

.home-hero__copy>p {
  max-width: 820px;
  color: #f0f2f3;
  font-size: clamp(1rem, 1.5vw, 1.25rem);
  font-weight: 750;
  line-height: 1.55;
}

.home-hero__tools {
  display: grid;
  grid-template-columns: minmax(180px, .65fr) minmax(280px, 1fr);
  gap: clamp(1rem, 3vw, 2.5rem);
  align-items: start;
  margin-top: 1.7rem;
}

.home-actions {
  display: flex;
  flex-direction: column;
  gap: .8rem;
  align-items: flex-start;
  margin-top: 10px;
}

.home-button {
  min-width: 190px;
  padding: .85rem 1.15rem;
  border-radius: 12px;
  color: #10263d;
  background: #fffaf0;
  font-weight: 900;
  text-align: center;
  text-decoration: none;
}

.home-button--secondary {
  color: #fffaf0;
  border: 1px solid rgba(255, 255, 255, .28);
  background: rgba(255, 255, 255, .08);
}

.home-hero__signal {
  position: relative;
  z-index: 1;
  padding: 1.25rem;
  border: 1px solid rgba(255, 255, 255, .16);
  border-radius: 20px;
  background: rgba(7, 23, 37, .38);
  backdrop-filter: blur(8px);
}

.home-hero__signal span,
.home-hero__signal strong,
.home-hero__signal small {
  display: block;
}

.home-hero__signal span {
  color: #e8b276;
  font-size: .68rem;
  font-weight: 900;
  letter-spacing: .13em;
  text-transform: uppercase;
}

.home-hero__signal strong {
  margin: .45rem 0;
  font-size: 1.25rem;
  line-height: 1.2;
}

.home-hero__signal small {
  color: #c5d0d8;
  line-height: 1.5;
}

.home-state,
.home-panel {
  margin-top: 1.25rem;
  border: 1px solid rgba(16, 38, 61, .1);
  border-radius: 25px;
  background: rgba(255, 252, 245, .86);
  box-shadow: 0 14px 38px rgba(73, 52, 24, .065);
}

.home-state {
  display: flex;
  gap: .7rem;
  align-items: center;
  padding: 1.5rem;
  font-weight: 800;
}

.home-state>span {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: #a93627;
  animation: pulse .8s infinite alternate;
}

.home-state--error {
  justify-content: space-between;
  color: #8f2d24;
}

.home-state button {
  padding: .6rem .9rem;
  border: 0;
  border-radius: 10px;
  color: white;
  background: #10263d;
  font-weight: 800;
}

.home-panel {
  padding: clamp(1.1rem, 3vw, 1.65rem);
}

.home-heading {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: end;
  margin-bottom: 1rem;
}

.home-heading h2 {
  margin-top: .2rem;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: clamp(1.8rem, 4vw, 2.7rem);
  line-height: 1;
  text-transform: uppercase;
}

.home-heading>span,
.home-heading>a {
  color: #62707a;
  font-size: .77rem;
  font-weight: 800;
  text-decoration: none;
}

.home-heading>a:hover {
  color: #a93627;
}

.leader-league-filter {
  display: flex;
  align-items: center;
  gap: .45rem;
  color: #62707a;
  font-size: .7rem;
  font-weight: 800;
  text-transform: uppercase;
}

.leader-league-filter select {
  padding: .45rem .6rem;
  border: 1px solid rgba(16, 38, 61, .18);
  border-radius: 8px;
  color: #10263d;
  background: #fffaf0;
  font: inherit;
  text-transform: none;
}

.game-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(275px, 1fr));
  gap: .8rem;
}

.leader-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: .8rem;
}

.leader-section + .leader-section {
  margin-top: 1.4rem;
}

.leader-section__heading {
  display: flex;
  align-items: center;
  gap: .7rem;
  margin-bottom: .65rem;
}

.leader-section__heading::after {
  flex: 1;
  height: 1px;
  content: '';
  background: rgba(16, 38, 61, .16);
}

.leader-section__heading h3 {
  color: #a93627;
  font-size: .75rem;
  letter-spacing: .14em;
  text-transform: uppercase;
}

.leader-card {
  padding: .75rem .85rem;
  border-radius: 18px;
  background: #10263d;
  color: #fffaf0;
}

.leader-card>header {
  display: flex;
  justify-content: space-between;
  gap: .4rem;
  align-items: baseline;
}

.leader-card h3 {
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.15rem;
  text-transform: uppercase;
}

.leader-card>header small {
  color: #9fb0bc;
  font-size: .61rem;
  text-transform: uppercase;
}

.leader-card ol {
  margin: .45rem 0 0;
  padding: 0;
  list-style: none;
}

.leader-card li {
  display: grid;
  grid-template-columns: 20px minmax(0, 1fr) auto;
  gap: .55rem;
  align-items: center;
  padding: .42rem 0;
  border-top: 1px solid rgba(255, 255, 255, .11);
}

.leader-card li>span {
  color: #e8b276;
  font-weight: 900;
}

.leader-card li a {
  display: flex;
  align-items: baseline;
  gap: .35rem;
  min-width: 0;
  color: inherit;
  text-decoration: none;
}

.leader-card li a strong,
.leader-card li a small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.leader-card li a strong {
  min-width: 0;
  font-size: .76rem;
}

.leader-card li a small {
  flex: 0 0 auto;
  color: #9fb0bc;
  font-size: .58rem;
}

.leader-card li>b {
  color: #e8b276;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.1rem;
}

.leader-card>p {
  margin-top: 1rem;
  color: #aab7c0;
  font-size: .78rem;
}

.pulse-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: .8rem;
}

.pulse-grid>article {
  padding: 1rem;
  border: 1px solid rgba(16, 38, 61, .1);
  border-radius: 18px;
  background: rgba(255, 255, 255, .67);
}

.pulse-grid h3 {
  margin-bottom: .5rem;
  color: #a93627;
  font-size: .75rem;
  letter-spacing: .1em;
  text-transform: uppercase;
}

.pulse-grid ol {
  margin: 0;
  padding: 0;
  list-style: none;
}

.pulse-grid li {
  display: flex;
  justify-content: space-between;
  gap: .7rem;
  align-items: center;
  padding: .62rem 0;
  border-top: 1px solid rgba(16, 38, 61, .08);
}

.pulse-grid li a {
  display: flex;
  min-width: 0;
  gap: .55rem;
  align-items: center;
  overflow: hidden;
  color: #344c60;
  font-size: .8rem;
  font-weight: 700;
  text-decoration: none;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.pulse-team-logo {
  display: block;
  width: 28px;
  height: 28px;
  flex: 0 0 28px;
  object-fit: contain;
}

.pulse-team-abbreviation {
  flex: 0 0 auto;
  color: #526779;
  font-size: .7rem;
  font-weight: 800;
}

.pulse-grid li strong {
  white-space: nowrap;
}

.quick-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: .8rem;
  margin-top: 1.25rem;
}

.quick-grid>* {
  display: grid;
  padding: 1.1rem;
  border: 1px solid rgba(16, 38, 61, .1);
  border-radius: 18px;
  color: #10263d;
  background: rgba(255, 252, 245, .75);
  text-decoration: none;
}

.quick-grid span {
  color: #a93627;
  font-size: .67rem;
  font-weight: 900;
}

.quick-grid strong {
  margin: .3rem 0;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.25rem;
  text-transform: uppercase;
}

.quick-grid small {
  color: #68757e;
  line-height: 1.45;
}

.home-empty {
  padding: 1rem;
  border-radius: 14px;
  color: #68757e;
  background: rgba(231, 237, 241, .65);
}

.home-freshness {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem .2rem 0;
  color: #697680;
  font-size: .7rem;
}

.home-freshness span {
  font-weight: 900;
  letter-spacing: .1em;
  text-transform: uppercase;
}

@keyframes pulse {
  to {
    opacity: .25;
    transform: scale(.8);
  }
}

@media (max-width: 1100px) {
  .leader-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .home-hero {
    grid-template-columns: minmax(260px, .7fr) minmax(0, 1.3fr);
    min-height: 460px;
    gap: 2rem;
  }

  .home-hero__tools {
    grid-template-columns: 1fr;
  }

  .home-actions {
    flex-direction: row;
    flex-wrap: wrap;
  }
}

@media (max-width: 800px) {
  .home-shell {
    width: min(100% - 1.2rem, 1440px);
    padding-top: 1rem;
  }

  .home-hero {
    grid-template-columns: 1fr;
    min-height: auto;
    padding: 1.8rem;
    border-radius: 22px;
    text-align: center;
  }

  .home-hero__baseball {
    width: min(68vw, 335px);
  }

  .home-hero__copy>p {
    margin-inline: auto;
  }

  .home-actions {
    justify-content: center;
  }

  .home-hero__signal {
    text-align: left;
  }

  .home-heading {
    align-items: flex-start;
    flex-direction: column;
  }

  .pulse-grid,
  .quick-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 520px) {
  .leader-grid {
    grid-template-columns: 1fr;
  }

  .home-hero {
    padding: 1.25rem;
  }

  .home-actions {
    align-items: stretch;
    flex-direction: column;
    width: 100%;
  }

  .home-button {
    width: 100%;
    min-width: 0;
  }

  .home-freshness {
    flex-direction: column;
  }
}
</style>
