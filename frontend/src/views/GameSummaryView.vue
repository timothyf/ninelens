<script setup>
import { computed, nextTick, ref, toRef, watch } from 'vue'

import { useGameSummary } from '../composables/useGameSummary'
import { teamLogoUrl } from '../config'
import NotesPanel from '../components/NotesPanel.vue'

const props = defineProps({ gameId: { type: [String, Number], required: true } })
const { game, loading, error, refresh } = useGameSummary(toRef(props, 'gameId'))
const gameTabs = [
  { id: 'overview', label: 'Overview' },
  { id: 'box-score', label: 'Box Score' },
  { id: 'pitching', label: 'Pitching Analysis' },
  { id: 'batted-ball', label: 'Batted Ball' },
  { id: 'situational', label: 'Situational' },
  { id: 'play-by-play', label: 'Play-by-Play' },
]
const activeTab = ref('overview')

watch(() => props.gameId, () => { activeTab.value = 'overview' })
watch(
  () => game.value?.id,
  async () => {
    if (!window.location.hash) return

    activeTab.value = 'play-by-play'
    await nextTick()
    const target = document.querySelector(window.location.hash)
    const appearance = target?.closest('details')
    if (appearance) appearance.open = true
    await nextTick()
    target?.scrollIntoView({ block: 'center' })
  },
)

const innings = computed(() => game.value?.details.lineScore.innings || [])
const awayBatting = computed(() => game.value?.details.battingLines.filter((line) => !line.home) || [])
const homeBatting = computed(() => game.value?.details.battingLines.filter((line) => line.home) || [])
const awayPitching = computed(() => game.value?.details.pitchingLines.filter((line) => !line.home) || [])
const homePitching = computed(() => game.value?.details.pitchingLines.filter((line) => line.home) || [])
const topHitterEntries = computed(() => [
  { side: 'away', entry: game.value?.details.keyPerformers.topHitters.away },
  { side: 'home', entry: game.value?.details.keyPerformers.topHitters.home },
])
const pitchingAnalysisTeams = computed(() => [
  { team: game.value?.awayTeam, pitchers: game.value?.details.pitchingAnalysis.filter((entry) => !entry.home) || [] },
  { team: game.value?.homeTeam, pitchers: game.value?.details.pitchingAnalysis.filter((entry) => entry.home) || [] },
])
const playByPlayInnings = computed(() => {
  const groups = new Map()
  for (const appearance of game.value?.details.plateAppearances || []) {
    const half = String(appearance.halfInning || '').toLowerCase() === 'top' ? 'Top' : 'Bottom'
    const key = `${appearance.inning || 0}-${half}`
    if (!groups.has(key)) groups.set(key, { key, label: `${half} ${ordinal(appearance.inning)}`, appearances: [] })
    groups.get(key).appearances.push(appearance)
  }
  return [...groups.values()]
})
const hasKeyPerformers = computed(() => {
  const performers = game.value?.details.keyPerformers
  return Boolean(
    performers?.topHitters.away ||
    performers?.topHitters.home ||
    performers?.mostImpactfulPitcher ||
    performers?.powerHitters.length ||
    performers?.scorelessRelievers.length ||
    performers?.topRunProducers.length
  )
})

function formatDate(value) {
  if (!value) return 'Date unavailable'
  return new Intl.DateTimeFormat('en-US', {
    weekday: 'long', month: 'long', day: 'numeric', year: 'numeric',
  }).format(new Date(`${value}T12:00:00`))
}

function formatTime(value) {
  if (!value) return 'Time unavailable'
  return new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit' }).format(new Date(value))
}

function formatTimestamp(value) {
  if (!value) return 'Not synchronized'
  return new Intl.DateTimeFormat('en-US', {
    month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit',
  }).format(new Date(value))
}

function display(value) {
  return value === null || value === undefined || value === '' ? '—' : value
}

function teamLogo(team) {
  return team?.logo_url || (team?.mlb_id ? teamLogoUrl(team.mlb_id) : null)
}

function rate(value, places = 3, omitLeadingZero = false) {
  if (value === null || value === undefined || value === '') return '—'
  const number = Number(value)
  if (!Number.isFinite(number)) return '—'

  const formatted = number.toFixed(places)
  return omitLeadingZero ? formatted.replace(/^(-?)0\./, '$1.') : formatted
}

function gameState(currentGame) {
  const status = String(currentGame.status || '').toLowerCase()
  if (status.includes('final')) return 'Final'
  if (status.includes('live')) return currentGame.detailedStatus || 'Live'
  return currentGame.detailedStatus || humanize(status)
}

function humanize(value) {
  return String(value || '').replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function signed(value) {
  if (value === null || value === undefined) return '—'
  return `${value > 0 ? '+' : ''}${value}`
}

function decision(entry) {
  if (!entry?.player) return '—'
  return `${entry.player.full_name} ${entry.decision || ''}`.trim()
}

function risp(value) {
  if (!value) return '—'
  return `${value.hits ?? 0}-${value.at_bats ?? 0}`
}

function boxScoreNoteText(note) {
  if (note.entries?.length) {
    return note.entries.map((entry) => {
      const name = entry.player?.full_name || 'Unknown player'
      const gameValue = entry.value && Number(entry.value) > 1 ? ` ${entry.value}` : ''
      const seasonValue = note.label === 'TB' || entry.season_value === null || entry.season_value === undefined || entry.season_value === ''
        ? '' : ` (${entry.season_value})`
      return `${name}${gameValue}${seasonValue}`
    }).join('; ')
  }
  return display(note.value)
}

function scoringPlayText(play) {
  const description = String(play.description || '')
  const playerName = String(play.batter?.full_name || '')
  if (!playerName || !description.toLowerCase().startsWith(playerName.toLowerCase())) return description

  return description.slice(playerName.length).replace(/^\s*[-—,:]?\s*/, '')
}

function percent(value) {
  return value === null || value === undefined ? '—' : `${Number(value).toFixed(1)}%`
}

function velocity(value) {
  return value === null || value === undefined ? '—' : `${Number(value).toFixed(1)} mph`
}

function angle(value) {
  return value === null || value === undefined ? '—' : `${Number(value).toFixed(1)}°`
}

function distribution(value) {
  if (!value || value.percentage === null || value.percentage === undefined) return '—'
  return `${value.count} (${Number(value.percentage).toFixed(1)}%)`
}

function teamRuns(entry) {
  return entry.home ? game.value?.homeScore : game.value?.awayScore
}

function situationRows(entry) {
  return [
    { label: 'Runners in scoring position', metrics: entry.situations.runnersInScoringPosition },
    { label: 'Two outs', metrics: entry.situations.twoOuts },
    { label: 'Bases loaded', metrics: entry.situations.basesLoaded },
    { label: 'Leadoff hitters', metrics: entry.situations.leadoffHitters },
    { label: 'Pinch hitters', metrics: entry.situations.pinchHitters },
    { label: 'High leverage', metrics: entry.situations.highLeverage },
  ]
}

function wpaPoints(value) {
  return value === null || value === undefined ? null : Math.abs(Number(value) * 100).toFixed(1)
}

function countLabel(pitch) {
  if (pitch.balls === null || pitch.balls === undefined || pitch.strikes === null || pitch.strikes === undefined) return '—'
  return `${pitch.balls}-${pitch.strikes}`
}

function distance(value) {
  return value === null || value === undefined ? '—' : `${Math.round(Number(value))} ft`
}

function timesThroughOrder(value) {
  const turns = value?.plateAppearances || []
  if (!turns.length) return '—'
  return turns.map((turn) => `${ordinal(turn.time)}: ${turn.battersFaced}`).join(' · ')
}

function ordinal(value) {
  const number = Number(value)
  const mod100 = number % 100
  if (mod100 >= 11 && mod100 <= 13) return `${number}th`
  return `${number}${({ 1: 'st', 2: 'nd', 3: 'rd' })[number % 10] || 'th'}`
}

function tabAvailable(tabId) {
  if (tabId === 'pitching') return Boolean(game.value?.details.pitchingAnalysis.length)
  if (tabId === 'batted-ball') return Boolean(game.value?.details.battedBallAnalysis.some((entry) => entry.battedBalls > 0))
  if (tabId === 'situational') {
    return Boolean(game.value?.details.situationalAnalysis.teams.some((entry) =>
      entry.battingOrderTrips.some((trip) => trip.plateAppearances > 0)))
  }
  if (tabId === 'play-by-play') return Boolean(game.value?.details.plateAppearances.length)
  return true
}

async function handleTabKey(event, index) {
  const availableTabs = gameTabs.filter((tab) => tabAvailable(tab.id))
  const currentIndex = availableTabs.findIndex((tab) => tab.id === gameTabs[index].id)
  let targetIndex
  if (event.key === 'ArrowRight') targetIndex = (currentIndex + 1) % availableTabs.length
  else if (event.key === 'ArrowLeft') targetIndex = (currentIndex - 1 + availableTabs.length) % availableTabs.length
  else if (event.key === 'Home') targetIndex = 0
  else if (event.key === 'End') targetIndex = availableTabs.length - 1
  else return

  event.preventDefault()
  activeTab.value = availableTabs[targetIndex].id
  await nextTick()
  document.getElementById(`game-tab-${activeTab.value}`)?.focus()
}
</script>

<template>
  <main class="game-summary-shell">
    <div v-if="loading" class="game-summary-state" data-test="game-summary-loading">Loading game summary…</div>
    <div v-else-if="error" class="game-summary-state game-summary-state--error" data-test="game-summary-error">
      <p>{{ error }}</p><button type="button" @click="refresh">Try again</button>
    </div>

    <template v-else-if="game">
      <section class="scoreboard" data-test="game-scoreboard">
        <header>
          <div><span>{{ gameState(game) }}</span><strong>{{ formatDate(game.officialDate) }}</strong></div>
          <p>
            {{ game.venueName || 'Venue unavailable' }} · {{ game.scheduledAt ? formatTime(game.scheduledAt) : 'Time unavailable' }}
            <small v-if="game.mlbId" class="scoreboard__mlb-id">MLB Game ID {{ game.mlbId }}</small>
          </p>
        </header>
        <div class="scoreboard__matchup">
          <RouterLink :to="{ name: 'team-profile', params: { id: game.awayTeam.id } }" class="scoreboard__team">
            <span>Away</span>
            <div class="scoreboard__team-name">
              <div v-if="teamLogo(game.awayTeam)" class="scoreboard__team-logo-badge">
                <img class="scoreboard__team-logo" :src="teamLogo(game.awayTeam)"
                  :alt="game.awayTeam.name + ' logo'" />
              </div>
              <strong>{{ game.awayTeam.name }}</strong>
            </div>
            <small>{{ game.awayTeam.abbreviation }}</small>
          </RouterLink>
          <div class="scoreboard__score"><strong>{{ display(game.awayScore) }}</strong><span>–</span><strong>{{
            display(game.homeScore) }}</strong></div>
          <RouterLink :to="{ name: 'team-profile', params: { id: game.homeTeam.id } }"
            class="scoreboard__team scoreboard__team--home">
            <span>Home</span>
            <div class="scoreboard__team-name">
              <div v-if="teamLogo(game.homeTeam)" class="scoreboard__team-logo-badge">
                <img class="scoreboard__team-logo" :src="teamLogo(game.homeTeam)"
                  :alt="game.homeTeam.name + ' logo'" />
              </div>
              <strong>{{ game.homeTeam.name }}</strong>
            </div>
            <small>{{ game.homeTeam.abbreviation }}</small>
          </RouterLink>
        </div>
      </section>

      <NotesPanel target-type="game" :target-id="game.id" title="Game notes" />

      <nav class="game-tabs" aria-label="Game summary sections">
        <div role="tablist" aria-label="Game summary views">
          <button v-for="(tab, index) in gameTabs" :id="`game-tab-${tab.id}`" :key="tab.id" type="button" role="tab"
            :aria-selected="activeTab === tab.id" :aria-controls="`game-panel-${tab.id}`"
            :tabindex="activeTab === tab.id ? 0 : -1" :disabled="!tabAvailable(tab.id)"
            :data-test="`game-tab-${tab.id}`" @click="activeTab = tab.id" @keydown="handleTabKey($event, index)">
            {{ tab.label }}
          </button>
        </div>
      </nav>

      <div id="game-panel-overview" v-if="activeTab === 'overview'" role="tabpanel" aria-labelledby="game-tab-overview"
        data-test="game-panel-overview">

        <section class="game-panel" data-test="line-score">
          <header class="game-panel__heading">
            <div>
              <p>Inning by inning</p>
              <h2>Line score</h2>
            </div><span v-if="game.details.lineScore.currentInningOrdinal">{{ game.details.lineScore.inningState }} {{
              game.details.lineScore.currentInningOrdinal }}</span>
          </header>
          <div class="box-table-wrap">
            <table class="line-score-table">
              <thead>
                <tr>
                  <th>Team</th>
                  <th v-for="inning in innings" :key="inning.number">{{ inning.number }}</th>
                  <th>R</th>
                  <th>H</th>
                  <th>E</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <th>
                    <RouterLink :to="{ name: 'team-profile', params: { id: game.awayTeam.id } }">{{
                      game.awayTeam.abbreviation }}</RouterLink>
                  </th>
                  <td v-for="inning in innings" :key="`away-${inning.number}`">{{ display(inning.away?.runs) }}</td>
                  <td><strong>{{ display(game.details.lineScore.totals.away?.runs) }}</strong></td>
                  <td>{{ display(game.details.lineScore.totals.away?.hits) }}</td>
                  <td>{{ display(game.details.lineScore.totals.away?.errors) }}</td>
                </tr>
                <tr>
                  <th>
                    <RouterLink :to="{ name: 'team-profile', params: { id: game.homeTeam.id } }">{{
                      game.homeTeam.abbreviation }}</RouterLink>
                  </th>
                  <td v-for="inning in innings" :key="`home-${inning.number}`">{{ display(inning.home?.runs) }}</td>
                  <td><strong>{{ display(game.details.lineScore.totals.home?.runs) }}</strong></td>
                  <td>{{ display(game.details.lineScore.totals.home?.hits) }}</td>
                  <td>{{ display(game.details.lineScore.totals.home?.errors) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <p v-if="!innings.length" class="game-panel__note">Inning-by-inning data has not been synchronized; available
            game totals are shown.</p>
        </section>

        <section class="game-insights" data-test="game-insights" aria-label="Game insights summary">
          <article class="game-insight game-insight--decisions">
            <span>Pitcher decisions</span>
            <dl>
              <div>
                <dt>W</dt>
                <dd>{{ decision(game.details.insights.decisions.winning_pitcher) }}</dd>
              </div>
              <div>
                <dt>L</dt>
                <dd>{{ decision(game.details.insights.decisions.losing_pitcher) }}</dd>
              </div>
              <div>
                <dt>S</dt>
                <dd>{{ decision(game.details.insights.decisions.save) }}</dd>
              </div>
            </dl>
          </article>
          <article class="game-insight">
            <span>Run differential</span>
            <dl>
              <div>
                <dt>{{ game.awayTeam.abbreviation }}</dt>
                <dd>{{ signed(game.details.insights.teams.away.run_differential) }}</dd>
              </div>
              <div>
                <dt>{{ game.homeTeam.abbreviation }}</dt>
                <dd>{{ signed(game.details.insights.teams.home.run_differential) }}</dd>
              </div>
            </dl>
          </article>
          <article class="game-insight">
            <span>Hits · Errors</span>
            <dl>
              <div>
                <dt>{{ game.awayTeam.abbreviation }}</dt>
                <dd>{{ display(game.details.insights.teams.away.hits) }} · {{
                  display(game.details.insights.teams.away.errors) }}</dd>
              </div>
              <div>
                <dt>{{ game.homeTeam.abbreviation }}</dt>
                <dd>{{ display(game.details.insights.teams.home.hits) }} · {{
                  display(game.details.insights.teams.home.errors) }}</dd>
              </div>
            </dl>
          </article>
          <article class="game-insight">
            <span>Walks · Strikeouts</span>
            <dl>
              <div>
                <dt>{{ game.awayTeam.abbreviation }}</dt>
                <dd>{{ display(game.details.insights.teams.away.walks) }} · {{
                  display(game.details.insights.teams.away.strikeouts) }}</dd>
              </div>
              <div>
                <dt>{{ game.homeTeam.abbreviation }}</dt>
                <dd>{{ display(game.details.insights.teams.home.walks) }} · {{
                  display(game.details.insights.teams.home.strikeouts) }}</dd>
              </div>
            </dl>
          </article>
          <article class="game-insight">
            <span>Home runs</span>
            <dl>
              <div>
                <dt>{{ game.awayTeam.abbreviation }}</dt>
                <dd>{{ display(game.details.insights.teams.away.home_runs) }}</dd>
              </div>
              <div>
                <dt>{{ game.homeTeam.abbreviation }}</dt>
                <dd>{{ display(game.details.insights.teams.home.home_runs) }}</dd>
              </div>
            </dl>
          </article>
          <article class="game-insight">
            <span>Left on base</span>
            <dl>
              <div>
                <dt>{{ game.awayTeam.abbreviation }}</dt>
                <dd>{{ display(game.details.insights.teams.away.left_on_base) }}</dd>
              </div>
              <div>
                <dt>{{ game.homeTeam.abbreviation }}</dt>
                <dd>{{ display(game.details.insights.teams.home.left_on_base) }}</dd>
              </div>
            </dl>
          </article>
          <article class="game-insight">
            <span>RISP</span>
            <dl>
              <div>
                <dt>{{ game.awayTeam.abbreviation }}</dt>
                <dd>{{ risp(game.details.insights.teams.away.runners_in_scoring_position) }}</dd>
              </div>
              <div>
                <dt>{{ game.homeTeam.abbreviation }}</dt>
                <dd>{{ risp(game.details.insights.teams.home.runners_in_scoring_position) }}</dd>
              </div>
            </dl>
          </article>
        </section>

        <section v-if="hasKeyPerformers" class="game-panel key-performers" data-test="key-performers">
          <header class="game-panel__heading">
            <div>
              <p>Game impact</p>
              <h2>Key performers</h2>
            </div>
            <span>Automatically selected from the box score</span>
          </header>
          <div class="performer-grid">
            <article class="performer-card performer-card--wide">
              <span>Top hitter by team</span>
              <div class="performer-card__team-list">
                <div v-for="item in topHitterEntries" :key="item.side">
                  <small>{{ item.entry?.team?.abbreviation || '—' }}</small>
                  <template v-if="item.entry?.player">
                    <RouterLink :to="{ name: 'player-profile', params: { id: item.entry.player.id } }">{{
                      item.entry.player.full_name }}</RouterLink>
                    <p>{{ item.entry.summary }}</p>
                  </template>
                  <strong v-else>Not available</strong>
                </div>
              </div>
            </article>

            <article class="performer-card">
              <span>Most impactful pitcher</span>
              <template v-if="game.details.keyPerformers.mostImpactfulPitcher?.player">
                <RouterLink
                  :to="{ name: 'player-profile', params: { id: game.details.keyPerformers.mostImpactfulPitcher.player.id } }">
                  {{ game.details.keyPerformers.mostImpactfulPitcher.player.full_name }}
                </RouterLink>
                <p>{{ game.details.keyPerformers.mostImpactfulPitcher.summary }}</p>
              </template>
              <strong v-else>Not available</strong>
            </article>

            <article class="performer-card">
              <span>Home runs & multiple XBH</span>
              <ul v-if="game.details.keyPerformers.powerHitters.length">
                <li v-for="entry in game.details.keyPerformers.powerHitters" :key="entry.player.id">
                  <RouterLink :to="{ name: 'player-profile', params: { id: entry.player.id } }">{{
                    entry.player.full_name }}
                  </RouterLink>
                  <small>{{ entry.summary }}</small>
                </li>
              </ul>
              <strong v-else>None</strong>
            </article>

            <article class="performer-card">
              <span>Scoreless relief</span>
              <ul v-if="game.details.keyPerformers.scorelessRelievers.length">
                <li v-for="entry in game.details.keyPerformers.scorelessRelievers" :key="entry.player.id">
                  <RouterLink :to="{ name: 'player-profile', params: { id: entry.player.id } }">{{
                    entry.player.full_name }}
                  </RouterLink>
                  <small>{{ entry.summary }}</small>
                </li>
              </ul>
              <strong v-else>None</strong>
            </article>

            <article class="performer-card">
              <span>Most runs produced</span>
              <ul v-if="game.details.keyPerformers.topRunProducers.length">
                <li v-for="entry in game.details.keyPerformers.topRunProducers" :key="entry.player.id">
                  <RouterLink :to="{ name: 'player-profile', params: { id: entry.player.id } }">{{
                    entry.player.full_name }}
                  </RouterLink>
                  <small>{{ entry.summary }}</small>
                </li>
              </ul>
              <strong v-else>None</strong>
            </article>
          </div>
        </section>

        <section v-if="game.details.scoringPlays.length" class="game-panel scoring-timeline"
          data-test="scoring-play-timeline">
          <header class="game-panel__heading">
            <div>
              <p>How the game unfolded</p>
              <h2>Scoring plays</h2>
            </div>
            <span>{{ game.details.scoringPlays.length }} {{ game.details.scoringPlays.length === 1 ? 'scoring play' : 'scoringplays' }}</span>
          </header>
          <ol class="scoring-timeline__list">
            <li v-for="play in game.details.scoringPlays" :key="play.id">
              <div class="scoring-timeline__marker"><span></span></div>
              <div class="scoring-timeline__play">
                <span>{{ play.inningLabel }}</span>
                <p>
                  <RouterLink v-if="play.batter" :to="{ name: 'player-profile', params: { id: play.batter.id } }">{{
                    play.batter.full_name }}</RouterLink>
                  <span v-if="play.batter"> — </span>{{ scoringPlayText(play) }}
                </p>
              </div>
              <div class="scoring-timeline__score"
                :aria-label="`${game.awayTeam.name} ${play.awayScore}, ${game.homeTeam.name} ${play.homeScore}`">
                <span>{{ game.awayTeam.abbreviation }} <strong>{{ play.awayScore }}</strong></span>
                <span>{{ game.homeTeam.abbreviation }} <strong>{{ play.homeScore }}</strong></span>
              </div>
            </li>
          </ol>
        </section>

      </div>

      <div id="game-panel-pitching" v-if="activeTab === 'pitching'" role="tabpanel" aria-labelledby="game-tab-pitching"
        data-test="game-panel-pitching">
        <section v-if="game.details.pitchingAnalysis.length" class="game-panel pitching-analysis"
          data-test="pitching-analysis">
          <header class="game-panel__heading">
            <div>
              <p>Pitch-level performance</p>
              <h2>Pitching analysis</h2>
            </div>
            <span>{{ game.details.pitchingAnalysis.length }} pitchers used</span>
          </header>
          <div v-for="section in pitchingAnalysisTeams" :key="section.team.id" class="pitching-analysis__team">
            <h3>{{ section.team.name }}</h3>
            <div class="pitcher-analysis-list">
              <article v-for="pitcher in section.pitchers" :key="pitcher.player.id" class="pitcher-analysis-card">
                <header>
                  <div>
                    <RouterLink :to="{ name: 'player-profile', params: { id: pitcher.player.id } }">{{
                      pitcher.player.full_name }}</RouterLink>
                    <span>{{ pitcher.starter ? 'Starter' : 'Reliever' }} · {{ display(pitcher.inningsPitched) }} IP<span
                        v-if="pitcher.decision"> · {{ pitcher.decision }}</span></span>
                  </div>
                  <small v-if="!pitcher.pitchDataAvailable">Pitch-level data unavailable</small>
                </header>
                <dl class="pitcher-metrics">
                  <div>
                    <dt>Pitches</dt>
                    <dd>{{ display(pitcher.pitchCount) }}<small
                        v-if="pitcher.analyzedPitchCount !== pitcher.pitchCount">{{
                          pitcher.analyzedPitchCount }} linked</small></dd>
                  </div>
                  <div>
                    <dt>Strike%</dt>
                    <dd>{{ percent(pitcher.strikePercentage) }}<small v-if="pitcher.strikeCount !== null">{{
                        pitcher.strikeCount }}/{{ pitcher.pitchCount }}</small></dd>
                  </div>
                  <div>
                    <dt>First-pitch strike%</dt>
                    <dd>{{ percent(pitcher.firstPitchStrikePercentage) }}<small>{{ pitcher.firstPitchStrikes }}/{{
                      pitcher.firstPitchOpportunities }}</small></dd>
                  </div>
                  <div>
                    <dt>Whiff%</dt>
                    <dd>{{ percent(pitcher.whiffPercentage) }}<small>{{ pitcher.whiffs }}/{{ pitcher.swings }}
                        swings</small>
                    </dd>
                  </div>
                  <div>
                    <dt>CSW%</dt>
                    <dd>{{ percent(pitcher.cswPercentage) }}<small>{{ pitcher.cswCount }}/{{ pitcher.analyzedPitchCount
                        }}</small></dd>
                  </div>
                  <div>
                    <dt>Average velocity</dt>
                    <dd>{{ velocity(pitcher.averageVelocity) }}</dd>
                  </div>
                  <div>
                    <dt>Maximum velocity</dt>
                    <dd>{{ velocity(pitcher.maximumVelocity) }}</dd>
                  </div>
                  <div>
                    <dt>Chase%</dt>
                    <dd>{{ percent(pitcher.chasePercentage) }}<small>{{ pitcher.chases }}/{{ pitcher.chaseOpportunities
                        }}</small></dd>
                  </div>
                  <div>
                    <dt>Batters faced</dt>
                    <dd>{{ display(pitcher.battersFaced) }}</dd>
                  </div>
                  <div class="pitcher-metrics__wide">
                    <dt>Times through order</dt>
                    <dd>{{ timesThroughOrder(pitcher.timesThroughOrder) }}</dd>
                  </div>
                </dl>
                <div class="pitch-usage">
                  <h4>Pitch arsenal</h4>
                  <div v-if="pitcher.pitchUsage.length" class="box-table-wrap">
                    <table>
                      <thead>
                        <tr>
                          <th>Pitch</th>
                          <th>Usage</th>
                          <th>Avg velo</th>
                          <th>Max velo</th>
                          <th>Whiff%</th>
                          <th>CSW%</th>
                          <th>Avg EV</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="usage in pitcher.pitchUsage" :key="usage.pitchType">
                          <th><strong>{{ usage.pitchType }}</strong><small>{{ usage.pitchName }}</small></th>
                          <td>{{ percent(usage.percentage) }}<small>{{ usage.count }} pitches</small></td>
                          <td>{{ velocity(usage.averageVelocity) }}</td>
                          <td>{{ velocity(usage.maximumVelocity) }}</td>
                          <td>{{ percent(usage.whiffPercentage) }}<small>{{ usage.whiffs }}/{{ usage.swings }}
                              swings</small>
                          </td>
                          <td>{{ percent(usage.cswPercentage) }}<small>{{ usage.cswCount }}/{{ usage.count }}
                              pitches</small>
                          </td>
                          <td>{{ velocity(usage.averageExitVelocity) }}<small>{{ usage.battedBalls }} tracked
                              BBE</small></td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                  <p v-else>No linked pitches are available for usage analysis.</p>
                </div>
              </article>
            </div>
          </div>
        </section>
      </div>

      <div id="game-panel-batted-ball" v-if="activeTab === 'batted-ball'" role="tabpanel"
        aria-labelledby="game-tab-batted-ball" data-test="game-panel-batted-ball">
        <section class="game-panel batted-ball-analysis" data-test="batted-ball-analysis">
          <header class="game-panel__heading">
            <div>
              <p>Quality of contact</p>
              <h2>Batted-ball analysis</h2>
            </div>
            <span>Top three hitters by tracked balls in play</span>
          </header>
          <p class="batted-ball-analysis__note">
            Contact metrics help compare the game’s final score with the underlying quality of contact. Popups are
            included
            with fly balls.
          </p>

          <article v-for="entry in game.details.battedBallAnalysis" :key="entry.team.id" class="batted-ball-team">
            <header>
              <div><span>{{ entry.home ? 'Home' : 'Away' }}</span>
                <h3>{{ entry.team.name }}</h3>
              </div>
              <strong>{{ display(teamRuns(entry)) }} runs · {{ entry.battedBalls }} tracked BBE</strong>
            </header>
            <dl class="contact-metrics">
              <div>
                <dt>Average exit velocity</dt>
                <dd>{{ velocity(entry.averageExitVelocity) }}</dd>
              </div>
              <div>
                <dt>Maximum exit velocity</dt>
                <dd>{{ velocity(entry.maximumExitVelocity) }}</dd>
              </div>
              <div>
                <dt>Hard-hit rate</dt>
                <dd>{{ percent(entry.hardHitPercentage) }}<small>{{ entry.hardHitCount }}/{{ entry.battedBalls
                    }}</small></dd>
              </div>
              <div>
                <dt>Launch angle</dt>
                <dd>{{ angle(entry.averageLaunchAngle) }}</dd>
              </div>
              <div>
                <dt>Expected wOBA</dt>
                <dd>{{ rate(entry.estimatedWoba, 3, true) }}</dd>
              </div>
              <div>
                <dt>Barrels</dt>
                <dd>{{ entry.barrelCount }}<small>{{ percent(entry.barrelPercentage) }}</small></dd>
              </div>
            </dl>
            <div class="contact-distribution" aria-label="Batted-ball distribution">
              <div><span>Ground balls</span><strong>{{ distribution(entry.distribution.groundBall) }}</strong><i
                  :style="{ width: `${entry.distribution.groundBall.percentage || 0}%` }"></i></div>
              <div><span>Line drives</span><strong>{{ distribution(entry.distribution.lineDrive) }}</strong><i
                  :style="{ width: `${entry.distribution.lineDrive.percentage || 0}%` }"></i></div>
              <div><span>Fly balls</span><strong>{{ distribution(entry.distribution.flyBall) }}</strong><i
                  :style="{ width: `${entry.distribution.flyBall.percentage || 0}%` }"></i></div>
            </div>

            <div class="batted-ball-leaders">
              <h4>Leading hitters</h4>
              <div class="box-table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>Hitter</th>
                      <th>BBE</th>
                      <th>Avg EV</th>
                      <th>Max EV</th>
                      <th>Hard-hit</th>
                      <th>Launch angle</th>
                      <th>xwOBA</th>
                      <th>Barrels</th>
                      <th>GB</th>
                      <th>LD</th>
                      <th>FB</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="leader in entry.leaders" :key="leader.player.id">
                      <th>
                        <RouterLink :to="{ name: 'player-profile', params: { id: leader.player.id } }">{{
                          leader.player.full_name }}</RouterLink>
                      </th>
                      <td>{{ leader.battedBalls }}</td>
                      <td>{{ velocity(leader.averageExitVelocity) }}</td>
                      <td>{{ velocity(leader.maximumExitVelocity) }}</td>
                      <td>{{ percent(leader.hardHitPercentage) }}</td>
                      <td>{{ angle(leader.averageLaunchAngle) }}</td>
                      <td>{{ rate(leader.estimatedWoba, 3, true) }}</td>
                      <td>{{ leader.barrelCount }}</td>
                      <td>{{ distribution(leader.distribution.groundBall) }}</td>
                      <td>{{ distribution(leader.distribution.lineDrive) }}</td>
                      <td>{{ distribution(leader.distribution.flyBall) }}</td>
                    </tr>
                    <tr v-if="!entry.leaders.length">
                      <td colspan="11">No hitter-level contact data is available.</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </article>
        </section>
      </div>

      <div id="game-panel-situational" v-if="activeTab === 'situational'" role="tabpanel"
        aria-labelledby="game-tab-situational" data-test="game-panel-situational">
        <section class="game-panel situational-analysis" data-test="situational-analysis">
          <header class="game-panel__heading">
            <div>
              <p>Pressure and game context</p>
              <h2>Situational performance</h2>
            </div>
            <span>Results from completed plate appearances</span>
          </header>

          <article v-if="game.details.situationalAnalysis.turningPoint" class="turning-point" data-test="turning-point">
            <div>
              <span>Turning point · {{ game.details.situationalAnalysis.turningPoint.inningLabel }}</span>
              <p>
                <RouterLink v-if="game.details.situationalAnalysis.turningPoint.batter"
                  :to="{ name: 'player-profile', params: { id: game.details.situationalAnalysis.turningPoint.batter.id } }">
                  {{
                    game.details.situationalAnalysis.turningPoint.batter.full_name }}</RouterLink>
                <span v-if="game.details.situationalAnalysis.turningPoint.batter"> — </span>
                {{ scoringPlayText(game.details.situationalAnalysis.turningPoint) }}
              </p>
            </div>
            <div class="turning-point__impact">
              <strong>{{ game.awayTeam.abbreviation }} {{
                display(game.details.situationalAnalysis.turningPoint.awayScore) }}
                · {{ game.homeTeam.abbreviation }} {{ display(game.details.situationalAnalysis.turningPoint.homeScore)
                }}</strong>
              <small v-if="wpaPoints(game.details.situationalAnalysis.turningPoint.homeWinProbabilityChange)">
                {{ wpaPoints(game.details.situationalAnalysis.turningPoint.homeWinProbabilityChange) }} WPA points
                toward {{
                  game.details.situationalAnalysis.turningPoint.benefitingTeam?.abbreviation }}
              </small>
              <small v-else>{{ game.details.situationalAnalysis.turningPoint.runsScored }}-run scoring play</small>
            </div>
          </article>

          <p class="situational-analysis__note">{{ game.details.situationalAnalysis.highLeverageDefinition }}</p>

          <article v-for="entry in game.details.situationalAnalysis.teams" :key="entry.team.id"
            class="situational-team">
            <header><span>{{ entry.home ? 'Home' : 'Away' }}</span>
              <h3>{{ entry.team.name }}</h3>
            </header>
            <div class="box-table-wrap">
              <table class="situational-table">
                <thead>
                  <tr>
                    <th>Situation</th>
                    <th>PA</th>
                    <th>H-AB</th>
                    <th>AVG</th>
                    <th>OBP</th>
                    <th>BB</th>
                    <th>SO</th>
                    <th>RBI</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="row in situationRows(entry)" :key="row.label">
                    <th>{{ row.label }}</th>
                    <td>{{ row.metrics.plateAppearances }}</td>
                    <td>{{ row.metrics.hits }}-{{ row.metrics.atBats }}</td>
                    <td>{{ rate(row.metrics.battingAverage, 3, true) }}</td>
                    <td>{{ rate(row.metrics.onBasePercentage, 3, true) }}</td>
                    <td>{{ row.metrics.walks }}</td>
                    <td>{{ row.metrics.strikeouts }}</td>
                    <td>{{ row.metrics.runsBattedIn }}</td>
                  </tr>
                </tbody>
              </table>
            </div>

            <h4>Performance by batting-order trip</h4>
            <div class="box-table-wrap">
              <table class="situational-table situational-table--trips">
                <thead>
                  <tr>
                    <th>Trip</th>
                    <th>PA</th>
                    <th>H-AB</th>
                    <th>AVG</th>
                    <th>OBP</th>
                    <th>BB</th>
                    <th>SO</th>
                    <th>RBI</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="trip in entry.battingOrderTrips" :key="trip.trip">
                    <th>{{ ordinal(trip.trip) }} trip</th>
                    <td>{{ trip.plateAppearances }}</td>
                    <td>{{ trip.hits }}-{{ trip.atBats }}</td>
                    <td>{{ rate(trip.battingAverage, 3, true) }}</td>
                    <td>{{ rate(trip.onBasePercentage, 3, true) }}</td>
                    <td>{{ trip.walks }}</td>
                    <td>{{ trip.strikeouts }}</td>
                    <td>{{ trip.runsBattedIn }}</td>
                  </tr>
                  <tr v-if="!entry.battingOrderTrips.length">
                    <td colspan="8">No plate-appearance data is available.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </article>
        </section>
      </div>

      <div id="game-panel-play-by-play" v-if="activeTab === 'play-by-play'" role="tabpanel"
        aria-labelledby="game-tab-play-by-play" data-test="game-panel-play-by-play">
        <section class="game-panel play-by-play" data-test="play-by-play">
          <header class="game-panel__heading">
            <div>
              <p>Every plate appearance</p>
              <h2>Play-by-play</h2>
            </div>
            <span>{{ game.details.plateAppearances.length }} plate appearances</span>
          </header>
          <p class="play-by-play__note">Select a plate appearance to view every pitch. The count is shown before each
            pitch.
          </p>

          <section v-for="inning in playByPlayInnings" :key="inning.key" class="play-inning">
            <header>
              <h3>{{ inning.label }}</h3><span>{{ inning.appearances.length }} {{ inning.appearances.length === 1 ?
                'plate appearance' : 'plate appearances' }}</span>
            </header>
            <div class="play-inning__appearances">
              <details v-for="appearance in inning.appearances" :id="`plate-appearance-${appearance.id}`"
                :key="appearance.id" class="plate-appearance" data-test="plate-appearance">
                <summary>
                  <div class="plate-appearance__matchup">
                    <span>#{{ appearance.plateAppearanceNumber }}</span>
                    <strong>
                      <RouterLink v-if="appearance.batter"
                        :to="{ name: 'player-profile', params: { id: appearance.batter.id } }">{{
                          appearance.batter.full_name
                        }}</RouterLink>
                      <span v-else>Unknown batter</span>
                    </strong>
                    <small v-if="appearance.pitcher">
                      vs. <RouterLink :to="{ name: 'player-profile', params: { id: appearance.pitcher.id } }">{{
                        appearance.pitcher.full_name }}</RouterLink>
                    </small>
                  </div>
                  <div class="plate-appearance__result">
                    <strong>{{ appearance.event || humanize(appearance.eventType) || 'Result unavailable' }}</strong>
                    <small>{{ appearance.description }}</small>
                  </div>
                  <div class="plate-appearance__score">
                    <span>{{ game.awayTeam.abbreviation }} <strong>{{ display(appearance.awayScore) }}</strong></span>
                    <span>{{ game.homeTeam.abbreviation }} <strong>{{ display(appearance.homeScore) }}</strong></span>
                  </div>
                </summary>
                <div class="plate-appearance__pitches">
                  <NotesPanel target-type="plate_appearance" :target-id="appearance.id" title="Plate appearance notes"
                    lazy compact />
                  <div v-if="appearance.pitches.length" class="box-table-wrap">
                    <table class="pitch-sequence-table">
                      <thead>
                        <tr>
                          <th>#</th>
                          <th>Count</th>
                          <th>Pitch</th>
                          <th>Velocity</th>
                          <th>Result</th>
                          <th>Exit velo</th>
                          <th>Launch</th>
                          <th>Distance</th>
                          <th>xwOBA</th>
                          <th>Notes</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="pitch in appearance.pitches" :id="pitch.id ? `pitch-${pitch.id}` : undefined"
                          :key="pitch.id || pitch.pitchNumber">
                          <td>{{ pitch.pitchNumber }}</td>
                          <td>{{ countLabel(pitch) }}</td>
                          <th><strong>{{ pitch.pitchName || pitch.pitchType || 'Unknown' }}</strong><small
                              v-if="pitch.pitchName && pitch.pitchType">{{ pitch.pitchType }}</small></th>
                          <td>{{ velocity(pitch.releaseSpeed) }}</td>
                          <td>{{ humanize(pitch.description) }}</td>
                          <td>{{ velocity(pitch.launchSpeed) }}</td>
                          <td>{{ angle(pitch.launchAngle) }}</td>
                          <td>{{ distance(pitch.hitDistance) }}</td>
                          <td>{{ rate(pitch.estimatedWoba, 3, true) }}</td>
                          <td>
                            <NotesPanel target-type="pitch" :target-id="pitch.id" title="Pitch notes" lazy compact />
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                  <p v-else>Pitch details are not available for this plate appearance.</p>
                </div>
              </details>
            </div>
          </section>
        </section>
      </div>

      <div id="game-panel-box-score" v-if="activeTab === 'box-score'" role="tabpanel"
        aria-labelledby="game-tab-box-score" data-test="game-panel-box-score">
        <section class="game-panel" data-test="box-score">
          <header class="game-panel__heading">
            <div>
              <p>Player results</p>
              <h2>Box score</h2>
            </div><span>Synced {{ formatTimestamp(game.details.lastSyncedAt) }}</span>
          </header>
          <template
            v-if="game.details.synchronized && (game.details.battingLines.length || game.details.pitchingLines.length)">
            <div
              v-for="section in [{ team: game.awayTeam, batting: awayBatting, pitching: awayPitching, notes: game.details.boxScoreNotes?.away }, { team: game.homeTeam, batting: homeBatting, pitching: homePitching, notes: game.details.boxScoreNotes?.home }]"
              :key="section.team.id" class="team-box">
              <h3>{{ section.team.name }}</h3>
              <h4>Batting</h4>
              <div class="box-table-wrap">
                <table class="box-score-table">
                  <thead>
                    <tr>
                      <th>Player</th>
                      <th>AB</th>
                      <th>R</th>
                      <th>H</th>
                      <th>2B</th>
                      <th>3B</th>
                      <th>HR</th>
                      <th>RBI</th>
                      <th>BB</th>
                      <th>SO</th>
                      <th>AVG</th>
                      <th>OPS</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="line in section.batting" :key="line.id">
                      <th>
                        <RouterLink v-if="line.player" :to="{ name: 'player-profile', params: { id: line.player.id } }">
                          {{ line.player.full_name }}</RouterLink><span v-else>Unknown player</span><small>{{
                          line.position || '' }}</small>
                      </th>
                      <td>{{ display(line.at_bats) }}</td>
                      <td>{{ display(line.runs) }}</td>
                      <td>{{ display(line.hits) }}</td>
                      <td>{{ display(line.doubles) }}</td>
                      <td>{{ display(line.triples) }}</td>
                      <td>{{ display(line.home_runs) }}</td>
                      <td>{{ display(line.runs_batted_in) }}</td>
                      <td>{{ display(line.walks) }}</td>
                      <td>{{ display(line.strikeouts) }}</td>
                      <td>{{ rate(line.batting_average, 3, true) }}</td>
                      <td>{{ rate(line.ops, 3, true) }}</td>
                    </tr>
                    <tr v-if="!section.batting.length">
                      <td colspan="12">No batting lines stored.</td>
                    </tr>
                  </tbody>
                </table>
              </div>
              <div v-if="section.notes" class="box-score-notes" data-test="box-score-notes">
                <div v-for="noteSection in [{ title: 'Batting', items: section.notes.batting }, { title: 'Baserunning', items: section.notes.baserunning }, { title: 'Fielding', items: section.notes.fielding }]"
                  :key="noteSection.title" v-show="noteSection.items?.length" class="box-score-notes__section">
                  <h4>{{ noteSection.title }}</h4>
                  <dl>
                    <template v-for="note in noteSection.items" :key="note.label">
                      <dt>{{ note.label }}</dt>
                      <dd>{{ boxScoreNoteText(note) }}</dd>
                    </template>
                  </dl>
                </div>
              </div>
              <h4>Pitching</h4>
              <div class="box-table-wrap">
                <table class="box-score-table box-score-table--pitching">
                  <thead>
                    <tr>
                      <th>Pitcher</th>
                      <th>IP</th>
                      <th>H</th>
                      <th>R</th>
                      <th>ER</th>
                      <th>BB</th>
                      <th>SO</th>
                      <th>HR</th>
                      <th>P-S</th>
                      <th>ERA</th>
                      <th>WHIP</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="line in section.pitching" :key="line.id">
                      <th>
                        <RouterLink v-if="line.player" :to="{ name: 'player-profile', params: { id: line.player.id } }">
                          {{ line.player.full_name }}</RouterLink><span v-else>Unknown pitcher</span><small
                          v-if="line.decision">{{ line.decision }}</small>
                      </th>
                      <td>{{ display(line.innings_pitched) }}</td>
                      <td>{{ display(line.hits) }}</td>
                      <td>{{ display(line.runs) }}</td>
                      <td>{{ display(line.earned_runs) }}</td>
                      <td>{{ display(line.walks) }}</td>
                      <td>{{ display(line.strikeouts) }}</td>
                      <td>{{ display(line.home_runs) }}</td>
                      <td>{{ display(line.pitches) }}-{{ display(line.strikes) }}</td>
                      <td>{{ rate(line.era, 2) }}</td>
                      <td>{{ rate(line.whip, 2) }}</td>
                    </tr>
                    <tr v-if="!section.pitching.length">
                      <td colspan="11">No pitching lines stored.</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
            <div v-if="game.details.gameNotes?.length" class="game-box-score-notes" data-test="game-box-score-notes">
              <dl>
                <template v-for="note in game.details.gameNotes" :key="note.label">
                  <dt>{{ note.label }}:</dt>
                  <dd>{{ note.value }}</dd>
                </template>
              </dl>
            </div>
          </template>
          <div v-else class="game-summary-empty">
            <strong>Box score not available</strong>
            <p>Run the game-details synchronization from Admin to retrieve player batting and pitching lines.</p>
          </div>
        </section>
      </div>
    </template>
  </main>
</template>

<style scoped>
.game-summary-shell {
  width: min(1320px, calc(100% - 2.5rem));
  margin: 0 auto;
  padding: 2.4rem 0 5rem;
  color: #10263d;
}

.game-summary-state {
  padding: 2rem;
  border: 1px solid rgba(16, 38, 61, .1);
  border-radius: 22px;
  background: rgba(255, 252, 245, .9);
  font-weight: 800;
}

.game-summary-state--error {
  display: flex;
  justify-content: space-between;
  color: #8f2d24;
}

.game-summary-state button {
  padding: .6rem .9rem;
  border: 0;
  border-radius: 10px;
  color: #fff;
  background: #10263d;
  font-weight: 800;
}

.scoreboard {
  overflow: hidden;
  border-radius: 28px;
  color: #fffaf0;
  background: linear-gradient(125deg, #10263d, #183e5b 70%, #8f2d24 150%);
  box-shadow: 0 24px 60px rgba(16, 38, 61, .17);
}

.scoreboard>header {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  padding: 1.1rem 1.5rem;
  border-bottom: 1px solid rgba(255, 255, 255, .12);
}

.scoreboard>header div {
  display: flex;
  gap: .75rem;
  align-items: center;
}

.scoreboard>header span {
  color: #e8b276;
  font-size: .72rem;
  font-weight: 900;
  letter-spacing: .1em;
  text-transform: uppercase;
}

.scoreboard>header strong,
.scoreboard>header p {
  color: #cbd6dd;
  font-size: .78rem;
}

.scoreboard__mlb-id {
  display: block;
  margin-top: .2rem;
  color: rgba(203, 214, 221, .62);
  font-size: .68rem;
  letter-spacing: .04em;
}

.scoreboard__matchup {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
  gap: clamp(1rem, 4vw, 4rem);
  align-items: center;
  padding: clamp(1.5rem, 5vw, 3.4rem);
}

.scoreboard__team {
  display: grid;
  color: inherit;
  text-decoration: none;
}

.scoreboard__team--home {
  text-align: right;
}

.scoreboard__team span {
  color: #e8b276;
  font-size: .67rem;
  font-weight: 900;
  letter-spacing: .12em;
  text-transform: uppercase;
}

.scoreboard__team-name {
  display: flex;
  gap: clamp(.65rem, 1.5vw, 1.1rem);
  align-items: center;
  margin: .25rem 0;
}

.scoreboard__team--home .scoreboard__team-name {
  flex-direction: row-reverse;
}

.scoreboard__team-logo-badge {
  display: grid;
  width: 85px;
  flex: 0 0 auto;
  box-sizing: border-box;
  place-items: center;
  padding: 6px;
  border: 1px solid rgba(255, 255, 255, .72);
  border-radius: clamp(11px, 1.5vw, 18px);
  background: #fffaf0;
  box-shadow: 0 7px 16px rgba(0, 0, 0, .24), inset 0 0 0 1px rgba(16, 38, 61, .08);
}

.scoreboard__team-logo {
  width: 70px;
  object-fit: contain;
  filter: drop-shadow(0 1px 1px rgba(16, 38, 61, .2));
}

.scoreboard__team strong {
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: clamp(1.8rem, 4vw, 3.6rem);
  line-height: .95;
  text-transform: uppercase;
}

.scoreboard__team small {
  color: #c6d2d9;
  font-weight: 800;
}

.scoreboard__score {
  display: flex;
  gap: clamp(.5rem, 2vw, 1.2rem);
  align-items: center;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: clamp(2.8rem, 7vw, 6rem);
  line-height: 1;
}

.scoreboard__score span {
  color: #7890a1;
  font-size: .5em;
}

.game-tabs {
  position: sticky;
  z-index: 8;
  top: .5rem;
  margin-top: 1rem;
  padding: .35rem;
  border: 1px solid rgba(16, 38, 61, .1);
  border-radius: 15px;
  background: rgba(247, 246, 241, .94);
  box-shadow: 0 8px 24px rgba(16, 38, 61, .08);
  backdrop-filter: blur(10px);
}

.game-tabs [role='tablist'] {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: .35rem;
}

.game-tabs button {
  min-height: 42px;
  padding: .65rem .85rem;
  border: 0;
  border-radius: 11px;
  color: #65747e;
  background: transparent;
  font-size: .72rem;
  font-weight: 900;
  letter-spacing: .06em;
  text-transform: uppercase;
  cursor: pointer;
}

.game-tabs button[aria-selected='true'] {
  color: #fffaf0;
  background: #173652;
  box-shadow: 0 5px 14px rgba(16, 38, 61, .18);
}

.game-tabs button:focus-visible {
  outline: 3px solid rgba(169, 54, 39, .32);
  outline-offset: 2px;
}

.game-tabs button:disabled {
  opacity: .42;
  cursor: not-allowed;
}

[role='tabpanel'] {
  scroll-margin-top: 5rem;
}

.game-insights {
  display: grid;
  grid-template-columns: minmax(230px, 1.5fr) repeat(6, minmax(145px, 1fr));
  gap: .65rem;
  margin-top: .8rem;
  overflow-x: auto;
  padding-bottom: .2rem;
}

.game-insight {
  min-width: 145px;
  padding: .8rem .85rem;
  border: 1px solid rgba(16, 38, 61, .1);
  border-radius: 15px;
  background: rgba(255, 252, 245, .88);
  box-shadow: 0 8px 22px rgba(73, 52, 24, .05);
}

.game-insight>span {
  display: block;
  margin-bottom: .45rem;
  color: #78838b;
  font-size: .58rem;
  font-weight: 900;
  letter-spacing: .08em;
  text-transform: uppercase;
}

.game-insight dl {
  display: grid;
  gap: .3rem;
  margin: 0;
}

.game-insight dl div {
  display: flex;
  justify-content: space-between;
  gap: .5rem;
  align-items: baseline;
}

.game-insight dt {
  color: #a93627;
  font-size: .62rem;
  font-weight: 900;
}

.game-insight dd {
  margin: 0;
  color: #173652;
  font-family: 'SFMono-Regular', Menlo, monospace;
  font-size: .7rem;
  font-weight: 800;
  text-align: right;
}

.game-insight--decisions dd {
  overflow: hidden;
  font-family: inherit;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.game-panel {
  margin-top: 1.2rem;
  padding: clamp(1rem, 3vw, 1.6rem);
  border: 1px solid rgba(16, 38, 61, .1);
  border-radius: 24px;
  background: rgba(255, 252, 245, .88);
  box-shadow: 0 14px 38px rgba(73, 52, 24, .065);
}

.game-panel__heading {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: end;
  margin-bottom: 1rem;
}

.game-panel__heading p {
  color: #a93627;
  font-size: .67rem;
  font-weight: 900;
  letter-spacing: .13em;
  text-transform: uppercase;
}

.game-panel__heading h2 {
  margin-top: .15rem;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 2.4rem;
  line-height: 1;
  text-transform: uppercase;
}

.game-panel__heading>span {
  color: #6e7a83;
  font-size: .72rem;
}

.performer-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: .75rem;
}

.performer-card {
  min-width: 0;
  padding: 1rem;
  border: 1px solid rgba(16, 38, 61, .09);
  border-radius: 16px;
  background: rgba(255, 255, 255, .58);
}

.performer-card--wide {
  grid-column: span 2;
}

.performer-card>span {
  display: block;
  margin-bottom: .7rem;
  color: #a93627;
  font-size: .62rem;
  font-weight: 900;
  letter-spacing: .09em;
  text-transform: uppercase;
}

.performer-card a {
  color: #173652;
  font-weight: 900;
  text-decoration: none;
}

.performer-card p,
.performer-card li small {
  display: block;
  margin-top: .18rem;
  color: #6d7880;
  font-size: .68rem;
}

.performer-card>strong {
  color: #7b858c;
  font-size: .78rem;
}

.performer-card ul {
  display: grid;
  gap: .65rem;
  margin: 0;
  padding: 0;
  list-style: none;
}

.performer-card__team-list {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: .75rem;
}

.performer-card__team-list>div {
  min-width: 0;
}

.performer-card__team-list small {
  display: block;
  margin-bottom: .2rem;
  color: #7b858c;
  font-size: .61rem;
  font-weight: 900;
}

.scoring-timeline__list {
  margin: 0;
  padding: 0;
  list-style: none;
}

.scoring-timeline__list li {
  display: grid;
  grid-template-columns: 22px minmax(0, 1fr) auto;
  gap: .8rem;
  align-items: center;
}

.scoring-timeline__list li+li {
  margin-top: .15rem;
}

.scoring-timeline__marker {
  align-self: stretch;
  position: relative;
  display: grid;
  place-items: center;
}

.scoring-timeline__marker::before {
  position: absolute;
  inset: 0 auto;
  width: 2px;
  content: '';
  background: rgba(169, 54, 39, .22);
}

.scoring-timeline__marker span {
  position: relative;
  z-index: 1;
  width: 11px;
  height: 11px;
  border: 3px solid #fffaf0;
  border-radius: 50%;
  background: #a93627;
  box-shadow: 0 0 0 1px #a93627;
}

.scoring-timeline__play {
  padding: .8rem 0;
}

.scoring-timeline__play>span {
  color: #a93627;
  font-size: .62rem;
  font-weight: 900;
  letter-spacing: .08em;
  text-transform: uppercase;
}

.scoring-timeline__play p {
  margin-top: .2rem;
  color: #53636e;
  font-size: .8rem;
  line-height: 1.4;
}

.scoring-timeline__play a {
  color: #173652;
  font-weight: 900;
  text-decoration: none;
}

.scoring-timeline__score {
  display: flex;
  gap: .45rem;
  padding: .45rem .55rem;
  border-radius: 10px;
  background: rgba(16, 38, 61, .055);
  color: #667680;
  font-family: 'SFMono-Regular', Menlo, monospace;
  font-size: .68rem;
  font-weight: 800;
}

.scoring-timeline__score strong {
  color: #173652;
}

.pitching-analysis__team+.pitching-analysis__team {
  margin-top: 1.5rem;
  padding-top: 1.3rem;
  border-top: 2px solid rgba(16, 38, 61, .08);
}

.pitching-analysis__team>h3 {
  margin-bottom: .7rem;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.65rem;
  text-transform: uppercase;
}

.pitcher-analysis-list {
  display: grid;
  gap: .8rem;
}

.pitcher-analysis-card {
  padding: 1rem;
  border: 1px solid rgba(16, 38, 61, .09);
  border-radius: 17px;
  background: rgba(255, 255, 255, .56);
}

.pitcher-analysis-card>header {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: start;
  margin-bottom: .85rem;
}

.pitcher-analysis-card>header a {
  display: block;
  color: #173652;
  font-size: 1rem;
  font-weight: 900;
  text-decoration: none;
}

.pitcher-analysis-card>header span,
.pitcher-analysis-card>header small {
  color: #748089;
  font-size: .68rem;
}

.pitcher-metrics {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: .55rem;
  margin: 0;
}

.pitcher-metrics>div {
  min-width: 0;
  padding: .65rem;
  border-radius: 11px;
  background: rgba(16, 38, 61, .045);
}

.pitcher-metrics dt {
  color: #7b858c;
  font-size: .57rem;
  font-weight: 900;
  letter-spacing: .06em;
  text-transform: uppercase;
}

.pitcher-metrics dd {
  margin: .25rem 0 0;
  color: #173652;
  font-family: 'SFMono-Regular', Menlo, monospace;
  font-size: .75rem;
  font-weight: 900;
}

.pitcher-metrics dd small {
  display: block;
  margin-top: .15rem;
  color: #81909a;
  font-family: inherit;
  font-size: .58rem;
  font-weight: 700;
}

.pitcher-metrics__wide {
  grid-column: span 2;
}

.pitch-usage {
  margin-top: .8rem;
}

.pitch-usage h4 {
  margin-bottom: .4rem;
  color: #a93627;
  font-size: .62rem;
  letter-spacing: .1em;
  text-transform: uppercase;
}

.pitch-usage table {
  min-width: 780px;
}

.pitch-usage tbody th small {
  display: block;
  margin-top: .1rem;
  color: #7b858c;
  font-size: .58rem;
}

.pitch-usage tbody td small {
  display: block;
  margin-top: .1rem;
  color: #84919a;
  font-family: inherit;
  font-size: .56rem;
}

.pitch-usage>p {
  color: #7b858c;
  font-size: .7rem;
}

.batted-ball-analysis__note {
  margin: -.25rem 0 1rem;
  color: #6f7a82;
  font-size: .72rem;
  line-height: 1.5;
}

.batted-ball-team {
  padding: 1rem;
  border: 1px solid rgba(16, 38, 61, .09);
  border-radius: 18px;
  background: rgba(255, 255, 255, .55);
}

.batted-ball-team+.batted-ball-team {
  margin-top: 1rem;
}

.batted-ball-team>header {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: end;
  margin-bottom: .8rem;
}

.batted-ball-team>header span {
  color: #a93627;
  font-size: .58rem;
  font-weight: 900;
  letter-spacing: .1em;
  text-transform: uppercase;
}

.batted-ball-team>header h3 {
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.8rem;
  line-height: 1;
  text-transform: uppercase;
}

.batted-ball-team>header strong {
  color: #65747e;
  font-size: .68rem;
}

.contact-metrics {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: .55rem;
  margin: 0;
}

.contact-metrics>div {
  min-width: 0;
  padding: .7rem;
  border-radius: 11px;
  background: rgba(16, 38, 61, .045);
}

.contact-metrics dt {
  color: #7b858c;
  font-size: .56rem;
  font-weight: 900;
  letter-spacing: .055em;
  text-transform: uppercase;
}

.contact-metrics dd {
  margin: .25rem 0 0;
  color: #173652;
  font-family: 'SFMono-Regular', Menlo, monospace;
  font-size: .75rem;
  font-weight: 900;
}

.contact-metrics dd small {
  display: block;
  margin-top: .12rem;
  color: #84919a;
  font-size: .57rem;
}

.contact-distribution {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: .55rem;
  margin-top: .65rem;
}

.contact-distribution>div {
  position: relative;
  overflow: hidden;
  display: flex;
  justify-content: space-between;
  gap: .5rem;
  padding: .65rem .7rem;
  border-radius: 10px;
  background: rgba(16, 38, 61, .045);
}

.contact-distribution span,
.contact-distribution strong {
  position: relative;
  z-index: 1;
  font-size: .63rem;
}

.contact-distribution span {
  color: #687781;
  font-weight: 800;
}

.contact-distribution strong {
  color: #173652;
  font-family: 'SFMono-Regular', Menlo, monospace;
}

.contact-distribution i {
  position: absolute;
  inset: auto auto 0 0;
  height: 3px;
  background: #a93627;
}

.batted-ball-leaders {
  margin-top: .9rem;
}

.batted-ball-leaders h4 {
  margin-bottom: .4rem;
  color: #a93627;
  font-size: .62rem;
  letter-spacing: .1em;
  text-transform: uppercase;
}

.batted-ball-leaders table {
  min-width: 1040px;
}

.turning-point {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: center;
  padding: 1rem;
  border: 1px solid rgba(169, 54, 39, .2);
  border-radius: 17px;
  background: linear-gradient(120deg, rgba(169, 54, 39, .09), rgba(232, 178, 118, .13));
}

.turning-point>div>span {
  color: #a93627;
  font-size: .62rem;
  font-weight: 900;
  letter-spacing: .1em;
  text-transform: uppercase;
}

.turning-point p {
  margin-top: .25rem;
  color: #52616c;
  font-size: .8rem;
}

.turning-point a {
  color: #173652;
  font-weight: 900;
  text-decoration: none;
}

.turning-point__impact {
  flex: 0 0 auto;
  text-align: right;
}

.turning-point__impact strong,
.turning-point__impact small {
  display: block;
}

.turning-point__impact strong {
  color: #173652;
  font-family: 'SFMono-Regular', Menlo, monospace;
  font-size: .76rem;
}

.turning-point__impact small {
  margin-top: .2rem;
  color: #a93627;
  font-size: .62rem;
  font-weight: 800;
}

.situational-analysis__note {
  margin: .7rem 0 1rem;
  color: #6f7a82;
  font-size: .68rem;
}

.situational-team {
  padding: 1rem;
  border: 1px solid rgba(16, 38, 61, .09);
  border-radius: 18px;
  background: rgba(255, 255, 255, .55);
}

.situational-team+.situational-team {
  margin-top: 1rem;
}

.situational-team>header {
  margin-bottom: .6rem;
}

.situational-team>header span {
  color: #a93627;
  font-size: .58rem;
  font-weight: 900;
  letter-spacing: .1em;
  text-transform: uppercase;
}

.situational-team>header h3 {
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.8rem;
  line-height: 1;
  text-transform: uppercase;
}

.situational-team h4 {
  margin: .9rem 0 .4rem;
  color: #a93627;
  font-size: .62rem;
  letter-spacing: .1em;
  text-transform: uppercase;
}

.situational-table {
  min-width: 680px;
}

.situational-table tbody th {
  color: #173652;
}

.play-by-play__note {
  margin: -.25rem 0 1rem;
  color: #6f7a82;
  font-size: .7rem;
}

.play-inning+.play-inning {
  margin-top: 1.2rem;
}

.play-inning>header {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: baseline;
  margin-bottom: .45rem;
  padding: 0 .2rem;
}

.play-inning>header h3 {
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.55rem;
  text-transform: uppercase;
}

.play-inning>header span {
  color: #78838b;
  font-size: .65rem;
}

.play-inning__appearances {
  display: grid;
  gap: .45rem;
}

.plate-appearance {
  overflow: hidden;
  border: 1px solid rgba(16, 38, 61, .1);
  border-radius: 14px;
  background: rgba(255, 255, 255, .58);
}

.plate-appearance summary {
  display: grid;
  grid-template-columns: minmax(190px, .8fr) minmax(260px, 1.5fr) auto;
  gap: 1rem;
  align-items: center;
  padding: .8rem 1rem;
  cursor: pointer;
  list-style-position: inside;
}

.plate-appearance summary::marker {
  color: #a93627;
}

.plate-appearance[open] summary {
  border-bottom: 1px solid rgba(16, 38, 61, .09);
  background: rgba(16, 38, 61, .035);
}

.plate-appearance__matchup {
  display: grid;
  min-width: 0;
}

.plate-appearance__matchup>span {
  color: #a93627;
  font-size: .56rem;
  font-weight: 900;
}

.plate-appearance__matchup a {
  color: #173652;
  text-decoration: none;
}

.plate-appearance__matchup small {
  overflow: hidden;
  color: #78838b;
  font-size: .62rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.plate-appearance__result {
  min-width: 0;
}

.plate-appearance__result strong,
.plate-appearance__result small {
  display: block;
}

.plate-appearance__result strong {
  color: #173652;
  font-size: .76rem;
}

.plate-appearance__result small {
  overflow: hidden;
  margin-top: .1rem;
  color: #6e7a83;
  font-size: .63rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.plate-appearance__score {
  display: flex;
  gap: .45rem;
  color: #687781;
  font-family: 'SFMono-Regular', Menlo, monospace;
  font-size: .67rem;
}

.plate-appearance__score strong {
  color: #173652;
}

.plate-appearance__pitches {
  padding: .75rem;
}

.plate-appearance__pitches>p {
  color: #78838b;
  font-size: .68rem;
  text-align: center;
}

.pitch-sequence-table {
  min-width: 900px;
}

.pitch-sequence-table tbody th small {
  display: block;
  color: #84919a;
  font-size: .56rem;
}

.box-table-wrap {
  overflow-x: auto;
  border: 1px solid rgba(16, 38, 61, .09);
  border-radius: 14px;
}

table {
  width: 100%;
  border-collapse: collapse;
  background: rgba(255, 255, 255, .6);
}

th,
td {
  padding: .65rem .72rem;
  border-bottom: 1px solid rgba(16, 38, 61, .075);
  text-align: right;
  white-space: nowrap;
}

thead th {
  color: #687781;
  background: rgba(16, 38, 61, .045);
  font-size: .64rem;
  letter-spacing: .05em;
  text-transform: uppercase;
}

tbody th:first-child,
thead th:first-child {
  text-align: left;
}

tbody td {
  color: #52616c;
  font-family: 'SFMono-Regular', Menlo, monospace;
  font-size: .72rem;
}

tbody tr:last-child th,
tbody tr:last-child td {
  border-bottom: 0;
}

table a {
  color: #173652;
  font-weight: 900;
  text-decoration: none;
}

.line-score-table {
  min-width: 600px;
}

.line-score-table th:first-child {
  position: sticky;
  left: 0;
  min-width: 95px;
  background: #f7f6f1;
}

.game-panel__note {
  margin-top: .65rem;
  color: #6f7a82;
  font-size: .72rem;
}

.team-box+.team-box {
  margin-top: 1.8rem;
  padding-top: 1.5rem;
  border-top: 2px solid rgba(16, 38, 61, .1);
}

.team-box h3 {
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.8rem;
  text-transform: uppercase;
}

.team-box h4 {
  margin: .85rem 0 .4rem;
  color: #6b7780;
  font-size: .68rem;
  letter-spacing: .11em;
  text-transform: uppercase;
}

.box-score-table {
  min-width: 900px;
}

.box-score-table--pitching {
  min-width: 800px;
}

.box-score-table tbody th {
  min-width: 190px;
}

.box-score-table tbody th small {
  display: inline;
  color: #7b858c;
  font-size: .61rem;
  font-weight: 700;
  margin-left: 10px;
}

.box-score-notes {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1.5rem;
  margin-top: 1.15rem;
  padding: 1rem 1.1rem;
  border: 1px solid rgba(16, 38, 61, .09);
  border-radius: 14px;
  background: rgba(231, 237, 241, .38);
}

.box-score-notes__section h4 {
  margin-top: 0;
}

.box-score-notes dl {
  display: grid;
  grid-template-columns: max-content minmax(0, 1fr);
  gap: .45rem .75rem;
  margin: 0;
  font-size: .82rem;
}

.box-score-notes dt {
  color: #10263d;
  font-weight: 850;
}

.box-score-notes dd {
  margin: 0;
  color: #68747c;
}

.game-box-score-notes {
  margin-top: 1.8rem;
  padding: 1.1rem 1.2rem;
  border-top: 1px solid rgba(16, 38, 61, .12);
}

.game-box-score-notes dl {
  display: grid;
  grid-template-columns: max-content minmax(0, 1fr);
  gap: .45rem .75rem;
  margin: 0;
  font-size: .82rem;
}

.game-box-score-notes dt {
  color: #10263d;
  font-weight: 850;
}

.game-box-score-notes dd {
  margin: 0;
  color: #68747c;
}

@media (max-width: 720px) {
  .box-score-notes {
    grid-template-columns: 1fr;
  }
}

.game-summary-empty {
  padding: 2rem;
  border-radius: 16px;
  color: #65727b;
  background: rgba(231, 237, 241, .58);
  text-align: center;
}

.game-summary-empty strong {
  display: block;
  margin-bottom: .35rem;
  color: #173652;
}

@media (max-width: 700px) {
  .game-summary-shell {
    width: calc(100% - 1.4rem);
    padding-top: 1rem;
  }

  .scoreboard>header,
  .game-panel__heading {
    align-items: flex-start;
    flex-direction: column;
  }

  .scoreboard__matchup {
    grid-template-columns: 1fr auto 1fr;
    gap: .6rem;
    padding: 1.3rem .9rem;
  }

  .scoreboard__team-name {
    gap: .4rem;
  }

  .scoreboard__team-logo-badge {
    width: 60px;
    padding: 5px;
    border-radius: 10px;
  }

  .scoreboard__team-logo {
    width: 45px;
  }

  .scoreboard__team strong {
    font-size: 1.35rem;
  }

  .scoreboard__score {
    font-size: 2.4rem;
  }

  .game-tabs {
    top: .25rem;
  }

  .game-tabs [role='tablist'] {
    grid-template-columns: repeat(6, minmax(120px, 1fr));
    overflow-x: auto;
  }

  .game-tabs button {
    padding-inline: .35rem;
    font-size: .62rem;
    letter-spacing: .03em;
  }

  .performer-grid {
    grid-template-columns: 1fr;
  }

  .performer-card--wide {
    grid-column: auto;
  }

  .scoring-timeline__list li {
    grid-template-columns: 18px minmax(0, 1fr);
  }

  .scoring-timeline__score {
    grid-column: 2;
    justify-self: start;
    margin-bottom: .65rem;
  }

  .pitcher-metrics {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .pitcher-metrics__wide {
    grid-column: span 2;
  }

  .batted-ball-team>header {
    align-items: flex-start;
    flex-direction: column;
  }

  .contact-metrics {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .contact-distribution {
    grid-template-columns: 1fr;
  }

  .turning-point {
    align-items: flex-start;
    flex-direction: column;
  }

  .turning-point__impact {
    text-align: left;
  }

  .plate-appearance summary {
    grid-template-columns: 1fr auto;
    gap: .55rem;
  }

  .plate-appearance__result {
    grid-column: 1 / -1;
    grid-row: 2;
  }
}
</style>
