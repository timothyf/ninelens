<script setup>
import { inject } from 'vue'
import PlayerCareerStatsPanel from './PlayerCareerStatsPanel.vue'
import PlayerAdvancedStatsPanel from './PlayerAdvancedStatsPanel.vue'
import PlayerDefensiveStatsPanel from './PlayerDefensiveStatsPanel.vue'
import PlayerSplitsPanel from './PlayerSplitsPanel.vue'
import ContextualBenchmarksPanel from './ContextualBenchmarksPanel.vue'
import RecentTeamHistoryCard from './RecentTeamHistoryCard.vue'
import RecentGameLogsCard from './RecentGameLogsCard.vue'

const {
  player, selectedProfileTab, profileTabs, selectAdjacentTab,
} = inject('player-profile-context')
</script>

<template>
  <div id="player-page-panel-overview" class="profile-page-content" role="tabpanel" aria-labelledby="player-page-tab-overview">
    <nav class="profile-tabs" aria-label="Player profile sections">
      <div role="tablist">
        <button
          v-for="(tab, index) in profileTabs"
          :id="`player-profile-tab-${tab.id}`"
          :key="tab.id"
          type="button"
          role="tab"
          :aria-controls="`player-profile-panel-${tab.id}`"
          :aria-selected="selectedProfileTab === tab.id"
          :tabindex="selectedProfileTab === tab.id ? 0 : -1"
          :data-test="`player-profile-tab-${tab.id}`"
          @click="selectedProfileTab = tab.id"
          @keydown="selectAdjacentTab($event, index)"
        >
          {{ tab.label }}
        </button>
      </div>
    </nav>

    <div class="profile-stat-tabs">
      <PlayerCareerStatsPanel v-if="selectedProfileTab === 'overview'" />
      <RecentGameLogsCard v-if="selectedProfileTab === 'overview'" />
      <PlayerAdvancedStatsPanel v-if="selectedProfileTab === 'advanced-stats'" />
      <PlayerDefensiveStatsPanel v-if="selectedProfileTab === 'defensive-stats'" />
      <PlayerSplitsPanel v-if="selectedProfileTab === 'splits'" />
    </div>

    <ContextualBenchmarksPanel />

    <div class="">
      <RecentTeamHistoryCard />
    </div>
  </div>
</template>
