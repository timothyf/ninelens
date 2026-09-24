<script setup>
import { computed } from 'vue'
import AddToWatchlistControl from '../../components/AddToWatchlistControl.vue'

const props = defineProps({
  player: { type: Object, required: true },
  initials: { type: String, required: true },
  headshotFailed: { type: Boolean, default: false },
  headerPositionLabel: { type: String, required: true },
  rosterLabel: { type: String, required: true },
  externalProfileLinks: { type: Array, default: () => [] },
  displayValue: { type: Function, required: true },
  formatDate: { type: Function, required: true },
})

const emit = defineEmits(['headshot-error', 'open-source'])

const teamThemes = {
  108: { primary: '#ba0021', secondary: '#003263', accent: '#ff5910' },
  109: { primary: '#a71930', secondary: '#2c2c2c', accent: '#e3d4ad' },
  110: { primary: '#df4601', secondary: '#27251f', accent: '#f5a623' },
  111: { primary: '#bd3039', secondary: '#0c2340', accent: '#c4ced4' },
  112: { primary: '#c41e3a', secondary: '#0c2340', accent: '#d4af37' },
  113: { primary: '#c6011f', secondary: '#000000', accent: '#ffffff' },
  114: { primary: '#003b70', secondary: '#e31937', accent: '#ffffff' },
  115: { primary: '#ba0021', secondary: '#003263', accent: '#ff5910' },
  116: { primary: '#0c2340', secondary: '#fa4616', accent: '#c4ced4' },
  117: { primary: '#002d62', secondary: '#d50032', accent: '#ffffff' },
  118: { primary: '#ce1141', secondary: '#000000', accent: '#ffffff' },
  119: { primary: '#005a9c', secondary: '#ef3340', accent: '#c4ced4' },
  120: { primary: '#041e42', secondary: '#ba0c2f', accent: '#ffffff' },
  121: { primary: '#002d72', secondary: '#ff5910', accent: '#ffffff' },
  133: { primary: '#003831', secondary: '#ffb81c', accent: '#ffffff' },
  134: { primary: '#27251f', secondary: '#ffb81c', accent: '#ffffff' },
  135: { primary: '#2f241d', secondary: '#ffc425', accent: '#ffffff' },
  136: { primary: '#0c2340', secondary: '#005c5c', accent: '#c4ced4' },
  137: { primary: '#fd5a1e', secondary: '#27251f', accent: '#ffffff' },
  138: { primary: '#c41e3a', secondary: '#0c2340', accent: '#ffcc00' },
  139: { primary: '#092c5c', secondary: '#8fbce6', accent: '#ffffff' },
  140: { primary: '#003278', secondary: '#c0111f', accent: '#ffffff' },
  141: { primary: '#134a8e', secondary: '#1d2d5c', accent: '#e8291c' },
  142: { primary: '#002b5c', secondary: '#d31145', accent: '#ffffff' },
  143: { primary: '#e81828', secondary: '#002d72', accent: '#ffffff' },
  144: { primary: '#ce1141', secondary: '#13274f', accent: '#eaaa00' },
  145: { primary: '#27251f', secondary: '#c4ced4', accent: '#ffffff' },
  146: { primary: '#00a3e0', secondary: '#ef3340', accent: '#000000' },
  147: { primary: '#0c2340', secondary: '#c4ced4', accent: '#ffffff' },
  158: { primary: '#005c5c', secondary: '#e87429', accent: '#ffffff' },
}

const teamThemeStyle = computed(() => {
  const teamId = Number(
    props.player.displayTeam?.mlbId
      || props.player.displayTeam?.mlb_id
      || props.player.team?.mlbId
      || props.player.team?.mlb_id,
  )
  const theme = teamThemes[teamId] || { primary: '#173652', secondary: '#315b7d', accent: '#e8b276' }

  return {
    '--profile-team-primary': theme.primary,
    '--profile-team-secondary': theme.secondary,
    '--profile-team-accent': theme.accent,
  }
})

const seasonStats = computed(() => Object.fromEntries(
  (props.player.seasonOverview?.stats || []).map((stat) => [stat.key, stat.value]),
))

const isPitcher = computed(() => (
  props.player.positions?.primary?.position_type === 'pitcher'
    || props.player.pitchIndicators?.primaryRole === 'pitcher'
))

const summaryMetrics = computed(() => {
  const stats = seasonStats.value
  const metric = (keys, label, { decimals = null, testKey = null } = {}) => {
    const key = Array.isArray(keys) ? keys.find((candidate) => stats[candidate] !== undefined) : keys
    const rawValue = stats[key]
    const numberValue = Number(rawValue)
    const value = decimals !== null && Number.isFinite(numberValue)
      ? numberValue.toFixed(decimals)
      : props.displayValue(rawValue)
    return { label, value, testKey }
  }

  return isPitcher.value
    ? [
        metric(['ERA', 'era'], 'ERA', { decimals: 2 }),
        metric(['strikeOuts', 'strikeouts', 'SO'], 'Strikeouts', { decimals: 0, testKey: 'strikeouts' }),
        metric(['whip', 'WHIP'], 'WHIP'),
        metric('WAR', 'WAR', { decimals: 1, testKey: 'war' }),
      ]
    : [
        metric('ops', `${props.player.seasonOverview?.season || 'Season'} OPS`),
        metric('homeRuns', 'Home runs', { decimals: 0, testKey: 'home-runs' }),
        metric('WAR', 'WAR', { decimals: 1, testKey: 'war' }),
        metric(['gamesPlayed', 'G'], 'Games played', { decimals: 0, testKey: 'games-played' }),
      ]
})

const summaryInsight = computed(() => {
  const event = props.player.trendEvents?.events?.[0]
  if (event?.eventType === 'velocity_loss') {
    return trendInsight('Velocity', event, 'mph', 'worth watching')
  }
  if (event?.eventType === 'chase_rate_movement') {
    return trendInsight('Chase rate', event, 'pts', 'shaping his results')
  }
  if (event?.eventType === 'pitch_mix_change') {
    return trendInsight('Pitch mix', event, 'pts', 'shaping his current profile')
  }
  return isPitcher.value
    ? 'A quick view of current results, role, and recent performance.'
    : 'A quick view of current production, role, and recent performance.'
})

function trendInsight(label, event, unit, suffix) {
  const change = Number(event.changeValue)
  const current = Number(event.currentValue)
  const baseline = Number(event.baselineValue)
  const hasChange = Number.isFinite(change)
  const direction = change > 0 ? 'rose' : change < 0 ? 'fell' : 'changed'
  const changeLabel = hasChange ? `${Math.abs(change).toFixed(1)} ${unit}` : 'in a measurable way'
  const comparison = Number.isFinite(current) && Number.isFinite(baseline)
    ? ` (${baseline.toFixed(1)} to ${current.toFixed(1)})`
    : ''
  const sample = event.sampleSize ? ` across ${event.sampleSize} observations` : ''
  return `${label} ${direction} ${changeLabel}${comparison}${sample}, ${suffix}.`
}

const lastSeason = computed(() => {
  if (props.player.profile?.active !== false) return null

  const careerLastSeason = Number(props.player.careerOverview?.lastSeason)
  if (Number.isInteger(careerLastSeason) && careerLastSeason > 0) return careerLastSeason

  const year = String(props.player.profile?.lastPlayedDate || '').match(/^(\d{4})/)
  return year ? Number(year[1]) : null
})

const currentSalary = computed(() => {
  const amount = Number(props.player.currentSalary)
  return Number.isFinite(amount) && amount > 0
    ? new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(amount)
    : props.displayValue(props.player.currentSalary)
})
</script>

<template>
  <section class="profile-hero" :style="teamThemeStyle">
    <svg class="profile-hero__pattern" viewBox="0 0 720 360" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
      <path d="M455 24 696 180 455 336 214 180Z" />
      <path d="m455 74 164 106-164 106-164-106Z" />
      <circle cx="455" cy="180" r="32" />
      <path d="M455 38v284M313 180h284" />
    </svg>

    <p class="profile-hero__title">Player profile <span>MLB ID: {{ player.mlbId }}</span></p>

    <div
      class="profile-portrait"
      :class="{ 'profile-portrait--photo': player.profile?.headshotUrl && !headshotFailed }"
    >
      <img
        v-if="player.profile?.headshotUrl && !headshotFailed"
        :src="player.profile.headshotUrl"
        :alt="`${player.fullName} headshot`"
        @error="emit('headshot-error')"
      />
      <span v-else>{{ initials }}</span>
    </div>

    <div class="profile-identity">
      <h1>{{ player.fullName }}</h1>
      <div class="profile-summary-line">
        <p class="profile-teamline">
          <strong>
            <RouterLink
              v-if="player.displayTeam?.id || player.currentMembership?.team?.id || player.team?.id"
              :to="{ name: 'team-profile', params: { id: player.displayTeam?.id || player.currentMembership?.team?.id || player.team?.id } }"
            >
              {{ player.displayTeam?.name || player.currentMembership?.team?.name || player.team?.name }}
            </RouterLink>
            <template v-else>Team unavailable</template>
          </strong>
          <span>{{ headerPositionLabel }}</span>
        </p>
        <div class="profile-status" :class="{ 'profile-status--injured': player.currentMembership?.injured }">
          {{ rosterLabel }}
        </div>
      </div>
      <nav class="profile-primary-actions" aria-label="Player actions">
        <AddToWatchlistControl :player-id="player.id" :player-name="player.fullName" />
        <RouterLink
          class="compare-player-link"
          :to="{ name: 'player-comparison', query: { left: player.id } }"
          data-test="compare-player-link"
        >
          Compare player
          <span aria-hidden="true">⇄</span>
        </RouterLink>
      </nav>
    </div>

    <dl class="profile-bio">
      <div>
        <dt>Bats/Throws</dt>
        <dd>{{ displayValue(player.profile?.bats) }}/{{ displayValue(player.profile?.throws) }}</dd>
      </div>
      <div>
        <dt>Age</dt>
        <dd>{{ displayValue(player.profile?.age) }}</dd>
      </div>
      <div>
        <dt>MLB debut</dt>
        <dd>{{ formatDate(player.profile?.mlbDebutDate) }}</dd>
      </div>
      <div>
        <dt>Born</dt>
        <dd>{{ formatDate(player.profile?.birthDate) }}</dd>
      </div>
      <div data-test="player-salary">
        <dt>Salary</dt>
        <dd>{{ currentSalary }}</dd>
      </div>
      <div v-if="lastSeason" data-test="player-last-season">
        <dt>Last season</dt>
        <dd>{{ lastSeason }}</dd>
      </div>
      <div v-else class="profile-bio__empty" aria-hidden="true"></div>
    </dl>

    <div class="profile-summary-strip" aria-label="Season summary">
      <div
        v-for="summaryMetric in summaryMetrics"
        :key="summaryMetric.label"
        class="profile-summary-metric"
        :data-test="summaryMetric.testKey ? `summary-metric-${summaryMetric.testKey}` : undefined"
      >
        <span>{{ summaryMetric.label }}</span>
        <strong>{{ summaryMetric.value }}</strong>
      </div>
      <p class="profile-summary-insight">{{ summaryInsight }}</p>
    </div>

    <div class="profile-hero__footer">
      <div class="profile-explore-links">
        <span class="profile-explore-links__label">Explore this player</span>
      <nav class="external-profile-links" aria-label="External player profiles">
        <a
          v-for="link in externalProfileLinks"
          :key="link.key"
          :href="link.href"
          target="_blank"
          rel="noopener noreferrer"
          :data-test="`external-profile-${link.key}`"
        >
          {{ link.label }}
          <span aria-hidden="true">↗</span>
        </a>
      </nav>
      </div>

      <button
        type="button"
        class="profile-provenance-link"
        data-test="player-data-provenance-link"
        @click="emit('open-source', $event.currentTarget)"
      >
        Data sources & freshness
        <span aria-hidden="true">i</span>
      </button>
    </div>
  </section>
</template>
