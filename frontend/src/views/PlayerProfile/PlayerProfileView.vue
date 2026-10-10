<script setup>
import { computed, inject, provide, reactive, ref, watch } from 'vue'
import { routeLocationKey, routerKey } from 'vue-router'

import PlayerTrendChart from '../../components/PlayerTrendChart.vue'
import SavedAnalysisControls from '../../components/SavedAnalysisControls.vue'
import PlayerOverviewView from './PlayerProfileOverviewView.vue'
import PlayerPerformanceTrendsView from './PlayerPerformanceTrendsView.vue'
import PlayerBattedBallProfileView from './PlayerBattedBallProfileView.vue'
import PlayerPitchArsenalView from './PlayerPitchArsenalView.vue'
import PlayerAnalysisPeriodControls from './PlayerAnalysisPeriodControls.vue'
import PlayerNotesView from './PlayerNotesView.vue'
import SimilarPlayersPanel from './SimilarPlayersPanel.vue'
import PlayerProfileHeader from './PlayerProfileHeader.vue'
import PlayerProfilePageTabs from './PlayerProfilePageTabs.vue'
import PlayerDataSourcesModal from './PlayerDataSourcesModal.vue'
import { usePlayerProfile } from '../../composables/usePlayerProfile'
import { usePlayerProfileAnalysis } from '../../composables/usePlayerProfileAnalysis'
import { usePlayerAnalysisFilters } from '../../composables/usePlayerAnalysisFilters'
import { formatBaseballStatValue } from '../../utils/baseballStatFormatting'
import { frontendConfig } from '../../config'
import { useAuth } from '../../composables/useAuth'

const props = defineProps({
  playerId: {
    type: [String, Number],
    required: true,
  },
})

const route = inject(routeLocationKey, { query: {}, fullPath: `/players/${props.playerId}` })
const router = inject(routerKey, { replace: () => {}, push: () => {} })
const playerId = computed(() => props.playerId)
const { user } = useAuth()
const canAccessNotes = computed(() => Boolean(user.value))
const profileTabs = [
  { id: 'overview', label: 'Basic Stats' },
  { id: 'advanced-stats', label: 'Advanced Stats' },
  { id: 'defensive-stats', label: 'Defensive Stats' },
  { id: 'splits', label: 'Splits' },
  { id: 'postseason', label: 'Postseason' },
]
const basePageTabIds = ['overview', 'performance-trends', 'batted-ball-profile', 'similar-players', 'pitch-arsenal']
const pageTabIds = computed(() => canAccessNotes.value ? [...basePageTabIds, 'notes'] : basePageTabIds)
const selectedPageTab = ref(pageTabIds.value.includes(route.query.view) ? route.query.view : 'overview')
const selectedProfileTab = ref(profileTabs.some((tab) => tab.id === route.query.tab) ? route.query.tab : 'overview')
const {
  analysisOptions, customStartDate, customEndDate, rangePresets, savedAnalysisState,
  savedAnalysisUrl, selectPreset, applyCustomRange, updateWindow, openSavedAnalysis,
} = usePlayerAnalysisFilters({ playerId, route, router, selectedPageTab })
const tabAnalysisOptions = reactive({
  'batted-ball-profile': { range: 'season', paWindow: 50, pitchWindow: 100, startDate: null, endDate: null },
  'pitch-arsenal': { range: 'season', paWindow: 50, pitchWindow: 100, startDate: null, endDate: null },
})
const { player, loading, error, sectionLoading, loadSection, reloadSection, refresh } = usePlayerProfile(playerId, analysisOptions)
const {
  careerTableRows, advancedTableRows, trendCharts, comparisonMetrics, selectedBatterSplit,
  batterSplitDimension, batterSplitMetrics, selectedPitcherSplit, pitcherSplitDimension,
  pitcherSplitMetrics, showBattingIndicators, showPitchingIndicators, trendEventTone,
  trendEventLabel, trendEventTitle, trendEventValue, benchmarkPeriodLabel,
  contextualMetricLabel, contextualValue, peerAverage, peerLabel, percentileStyle,
  signedContextualValue, batterSplitValue, pitcherSplitValue, advancedStatValue, similarityValue,
} = usePlayerProfileAnalysis(player, formatDate)
const headshotFailed = ref(false)
const sourceModalOpen = ref(false)
const sourceModalTrigger = ref(null)

watch(
  () => [
    route.query.view,
    route.query.tab,
  ],
  ([view, tab]) => {
    selectedPageTab.value = pageTabIds.value.includes(view) ? view : 'overview'
    selectedProfileTab.value = profileTabs.some((entry) => entry.id === tab) ? tab : 'overview'
  },
)

watch(canAccessNotes, (hasAccess) => {
  if (hasAccess && route.query.view === 'notes') selectedPageTab.value = 'notes'
  if (!hasAccess && selectedPageTab.value === 'notes') selectedPageTab.value = 'overview'
})

watch(
  () => player.value?.profile?.headshotUrl,
  () => {
    headshotFailed.value = false
  },
)

watch(
  selectedProfileTab,
  (tab) => {
    if (tab === 'advanced-stats') void loadSection('advanced_stats')
    if (tab === 'defensive-stats') void loadSection('defensive_stats')
    if (tab === 'splits') void loadSection('splits')
    if (tab === 'postseason') void loadSection('postseason')
  },
  { immediate: true },
)

watch(
  selectedPageTab,
  (tab) => {
    if (tab === 'similar-players') void loadSection('similar_players')
    if (tab === 'batted-ball-profile' || tab === 'pitch-arsenal') {
      void reloadSection('analytics', tabAnalysisOptions[tab])
    }
  },
  { immediate: true },
)

function updateTabAnalysisPeriod(tab, options) {
  tabAnalysisOptions[tab] = options
  if (selectedPageTab.value === tab) void reloadSection('analytics', options)
}

const initials = computed(() =>
  [player.value?.firstName, player.value?.lastName]
    .filter(Boolean)
    .map((name) => name.charAt(0))
    .join(''),
)

const rosterLabel = computed(() => {
  const membership = player.value?.currentMembership
  if (!membership) return 'Roster status unavailable'
  return membership.sourceStatusDescription || titleize(membership.rosterStatus)
})

function teamHistoryLabel(membership) {
  if (!membership.current) return 'Organization tenure'

  return membership.sourceStatusDescription || titleize(membership.rosterStatus)
}

const headerPositionLabel = computed(() => {
  const position = player.value?.positions?.primary
  const parts = []
  if (position?.abbreviation) parts.push(position.abbreviation)
  if (position?.name) parts.push(position.name)
  if (player.value?.currentMembership?.jerseyNumber) parts.push(`#${player.value.currentMembership.jerseyNumber}`)
  return parts.length ? parts.join(' - ') : 'Position unavailable'
})

const savantStatsMode = computed(() => {
  const positionType = player.value?.positions?.primary?.position_type
  const primaryRole = player.value?.pitchIndicators?.primaryRole
  return positionType === 'pitcher' || (!positionType && primaryRole === 'pitcher')
    ? 'statcast-r-pitching-mlb'
    : 'statcast-r-hitting-mlb'
})

const careerRangeLabel = computed(() => {
  const career = player.value?.careerOverview
  if (!career?.firstSeason) return 'No seasons stored'

  const range = career.firstSeason === career.lastSeason
    ? String(career.firstSeason)
    : `${career.firstSeason}–${career.lastSeason}`
  const seasonLabel = career.seasonCount === 1 ? 'season' : 'seasons'
  return `${range} · ${career.seasonCount} ${seasonLabel}`
})

const externalProfileLinks = computed(() => {
  const fullName = player.value?.fullName
  const mlbId = player.value?.mlbId
  if (!fullName || !mlbId) return []

  const slug = fullName
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
  const encodedName = encodeURIComponent(fullName)
  const baseballReferenceId = player.value?.externalIds?.baseballReference
  const fangraphsId = player.value?.externalIds?.fangraphs

  return [
    {
      key: 'baseball-savant',
      label: 'Baseball Savant',
      href: `${frontendConfig.externalUrls.baseballSavantPlayerBaseUrl}/${slug}-${mlbId}?stats=${savantStatsMode.value}`,
    },
    { key: 'mlb', label: 'MLB.com', href: `${frontendConfig.externalUrls.mlbPlayerBaseUrl}/${slug}-${mlbId}` },
    {
      key: 'baseball-reference',
      label: 'Baseball Reference',
      href: baseballReferenceId
        ? `${frontendConfig.externalUrls.baseballReferenceBaseUrl}/${baseballReferenceId.charAt(0)}/${baseballReferenceId}.shtml`
        : `${frontendConfig.externalUrls.baseballReferenceSearchUrl}?search=${encodedName}`,
    },
    {
      key: 'fangraphs',
      label: 'FanGraphs',
      href: fangraphsId
        ? `${frontendConfig.externalUrls.fangraphsBaseUrl}/${slug}/${fangraphsId}/stats`
        : `${frontendConfig.externalUrls.fangraphsLegacyUrl}?lastname=${encodedName}`,
    },
  ]
})

const pitcherWalkRate = computed(() => {
  const stats = player.value?.seasonOverview?.stats || []
  const walks = Number(stats.find((stat) => ['baseOnBalls', 'BB'].includes(stat.key))?.value)
  const inningsText = stats.find((stat) => ['inningsPitched', 'IP'].includes(stat.key))?.value
  if (!Number.isFinite(walks) || inningsText === null || inningsText === undefined) return null

  const inningsParts = String(inningsText).split('.')
  const innings = Number(inningsParts[0]) + (Number(inningsParts[1] || 0) / 3)
  return innings > 0 ? `${((walks * 9) / innings).toFixed(2)} BB/9` : null
})

const pitchingMetrics = computed(() => [
  ['Pitches', player.value?.pitchIndicators.pitching.pitch_count],
  ['Games', player.value?.pitchIndicators.pitching.game_count],
  ['Walk rate', pitcherWalkRate.value],
  ['Avg velo', withUnit(player.value?.pitchIndicators.pitching.average_velocity, ' mph')],
  ['Max velo', withUnit(player.value?.pitchIndicators.pitching.max_velocity, ' mph')],
  ['Avg spin', withUnit(player.value?.pitchIndicators.pitching.average_spin_rate, ' rpm')],
  ['Strike rate', withUnit(player.value?.pitchIndicators.pitching.strike_percentage, '%')],
])

const battingMetrics = computed(() => [
  ['Pitches seen', player.value?.pitchIndicators.batting.pitches_seen],
  ['Games', player.value?.pitchIndicators.batting.game_count],
  ['Batted balls', player.value?.pitchIndicators.batting.batted_ball_count],
  ['Avg exit velo', withUnit(player.value?.pitchIndicators.batting.average_exit_velocity, ' mph')],
  ['Max exit velo', withUnit(player.value?.pitchIndicators.batting.max_exit_velocity, ' mph')],
  ['Hard-hit rate', withUnit(player.value?.pitchIndicators.batting.hard_hit_percentage, '%')],
])

function selectAdjacentTab(event, index) {
  if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return
  event.preventDefault()

  let nextIndex = index
  if (event.key === 'ArrowRight') nextIndex = (index + 1) % profileTabs.length
  if (event.key === 'ArrowLeft') nextIndex = (index - 1 + profileTabs.length) % profileTabs.length
  if (event.key === 'Home') nextIndex = 0
  if (event.key === 'End') nextIndex = profileTabs.length - 1
  selectedProfileTab.value = profileTabs[nextIndex].id
  event.currentTarget.closest('[role="tablist"]')?.querySelectorAll('[role="tab"]')?.[nextIndex]?.focus()
}

function titleize(value) {
  return String(value || '')
    .replaceAll('_', ' ')
    .replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function withUnit(value, unit) {
  return value === null || value === undefined ? null : `${value}${unit}`
}

function displayValue(value) {
  return value === null || value === undefined || value === '' ? '—' : value
}

function formatDate(value) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' }).format(
    new Date(`${value}T12:00:00`),
  )
}

function openSourceModal(trigger) {
  sourceModalTrigger.value = trigger || null
  sourceModalOpen.value = true
}

function closeSourceModal() {
  sourceModalOpen.value = false
}

provide('player-profile-context', {
  player, selectedProfileTab, profileTabs, sectionLoading, reloadSection,
  canAccessNotes,
  defensiveStats: computed(() => player.value?.defensiveStats || { season: null, seasons: [], positions: [], fieldingPercentage: null, defensiveRunsSaved: null, outsAboveAverage: null }),
  careerTableRows, titleize, careerRangeLabel,
  formatBaseballStatValue, advancedTableRows, advancedStatValue, showBattingIndicators, batterSplitDimension,
  batterSplitMetrics, batterSplitValue, selectedBatterSplit, showPitchingIndicators, pitcherSplitDimension,
  pitcherSplitMetrics, pitcherSplitValue, selectedPitcherSplit, formatDate, similarityValue,
  contextualMetricLabel, contextualValue, peerAverage, peerLabel, percentileStyle, signedContextualValue,
  benchmarkPeriodLabel, battingMetrics, pitchingMetrics, teamHistoryLabel, displayValue, SavedAnalysisControls,
  PlayerAnalysisPeriodControls, tabAnalysisOptions, updateTabAnalysisPeriod,
  savedAnalysisState, savedAnalysisUrl, openSavedAnalysis, analysisOptions, rangePresets, selectPreset,
  customStartDate, customEndDate, applyCustomRange, updateWindow, trendEventTone, trendEventLabel,
  trendEventTitle, trendEventValue, comparisonMetrics, trendCharts, PlayerTrendChart, selectAdjacentTab,
})
</script>

<template>
  <main class="profile-shell">
    <div v-if="loading" class="profile-state" data-test="profile-loading">
      <span class="loading-ball" aria-hidden="true"></span>
      <strong>Building player profile…</strong>
    </div>

    <div v-else-if="error" class="profile-state profile-state--error" data-test="profile-error">
      <p>{{ error }}</p>
      <button type="button" class="profile-button" @click="refresh">Try again</button>
    </div>

    <template v-else-if="player">
      <PlayerProfileHeader
        :player="player"
        :initials="initials"
        :headshot-failed="headshotFailed"
        :header-position-label="headerPositionLabel"
        :roster-label="rosterLabel"
        :external-profile-links="externalProfileLinks"
        :display-value="displayValue"
        :format-date="formatDate"
        @headshot-error="headshotFailed = true"
        @open-source="openSourceModal"
      />

      <PlayerProfilePageTabs
        :active-tab="selectedPageTab"
        @tab-change="selectedPageTab = $event"
      />

      <PlayerOverviewView v-if="selectedPageTab === 'overview'" />

      <PlayerPerformanceTrendsView v-if="selectedPageTab === 'performance-trends'" />

      <PlayerBattedBallProfileView v-if="selectedPageTab === 'batted-ball-profile'" />

      <PlayerPitchArsenalView v-if="selectedPageTab === 'pitch-arsenal' && player?.pitchIndicators?.primaryRole === 'pitcher'" />

      <PlayerNotesView v-if="selectedPageTab === 'notes' && canAccessNotes" />

      <section
        v-if="selectedPageTab === 'similar-players'"
        id="player-page-panel-similar-players"
        class="profile-page-content"
        role="tabpanel"
        aria-labelledby="player-page-tab-similar-players"
      >
        <SimilarPlayersPanel />
      </section>

      <PlayerDataSourcesModal
        :open="sourceModalOpen"
        :player="player"
        :return-focus-el="sourceModalTrigger"
        @close="closeSourceModal"
      />
    </template>
  </main>
</template>

<style src="../../styles/player-profile.css"></style>
