<script setup>
import { computed, ref, watch } from 'vue'

import { formatCount, formatDate, formatTimestamp } from '../../utils/adminFormatting'
import {
  analyticsRefreshClass,
  analyticsRefreshMessage,
  analyticsRefreshProcessing,
  deferredAnalyticsRefreshAvailable,
  failureRows,
  failureText,
  workerErrorRows,
  workerPoolMessage,
} from '../../utils/gameDetailsTaskPresentation'
import AdminSyncProgress from './AdminSyncProgress.vue'
import AdminTaskCard from './AdminTaskCard.vue'

const props = defineProps({
  options: { type: Object, required: true },
  metrics: { type: Object, required: true },
  task: { type: Object, default: null },
  active: { type: Boolean, default: false },
  starting: { type: Boolean, default: false },
  anyActionRunning: { type: Boolean, default: false },
  runningTask: { type: String, default: '' },
  error: { type: String, default: '' },
  autoSyncEnabled: { type: Boolean, default: null },
  autoSyncIntervalMinutes: { type: Number, default: null },
  autoSyncLoading: { type: Boolean, default: false },
  autoSyncSaving: { type: Boolean, default: false },
  autoSyncError: { type: String, default: '' },
})
const emit = defineEmits(['submit', 'cancel-active', 'refresh-analytics', 'toggle-auto-sync', 'save-auto-sync-interval'])
const syncButton = ref(null)
const draftIntervalMinutes = ref(null)
watch(() => props.autoSyncIntervalMinutes, (value) => { draftIntervalMinutes.value = value }, { immediate: true })
const intervalValid = computed(() => Number.isInteger(draftIntervalMinutes.value) && draftIntervalMinutes.value >= 5 && draftIntervalMinutes.value <= 1440)
const intervalChanged = computed(() => draftIntervalMinutes.value !== props.autoSyncIntervalMinutes)

function saveInterval() {
  if (intervalValid.value && intervalChanged.value && !props.autoSyncSaving) {
    emit('save-auto-sync-interval', draftIntervalMinutes.value)
  }
}

defineExpose({
  focusSyncButton: () => syncButton.value?.focus(),
})

</script>

<template>
  <AdminTaskCard
    source="Box scores & live feeds"
    title="MLB game detail synchronization"
    command="mlb_game_details:sync"
    description="Downloads player game lines, batting orders, substitutions, plate appearances, and links matching Statcast pitches."
    data-test="game-details-sync-form"
    @submit.prevent="emit('submit')"
  >
    <div class="data-coverage" data-test="game-details-coverage">
      <span>Currently stored</span>
      <dl v-if="metrics.synchronizedGameCount">
        <div><dt>Games synchronized</dt><dd>{{ formatCount(metrics.synchronizedGameCount) }}</dd></div>
        <div><dt>Game-date span</dt><dd>{{ formatDate(metrics.earliestGameDate) }}–{{ formatDate(metrics.latestGameDate) }}</dd></div>
      </dl>
      <p v-else>No game box scores or live feeds have been synchronized.</p>
      <small>{{ formatCount(metrics.plateAppearanceCount) }} plate appearances · {{ formatCount(metrics.linkedPitchCount) }} linked pitches</small>
    </div>
    <div class="game-details-auto-sync" data-test="game-details-auto-sync">
      <div>
        <strong>Automatic game-detail synchronization</strong>
        <p>Run in production for today's stored games. Turning this off does not cancel a task already in progress.</p>
      </div>
      <button
        type="button"
        role="switch"
        aria-label="Automatic game-detail synchronization"
        :aria-checked="Boolean(autoSyncEnabled)"
        :disabled="autoSyncEnabled === null || autoSyncLoading || autoSyncSaving"
        data-test="game-details-auto-sync-switch"
        @click="emit('toggle-auto-sync')"
      >{{ autoSyncSaving ? 'Saving…' : autoSyncEnabled ? 'On' : 'Off' }}</button>
    </div>
    <div class="game-details-auto-sync-interval">
      <label for="game-details-auto-sync-interval">Interval (minutes)</label>
      <input
        id="game-details-auto-sync-interval"
        v-model.number="draftIntervalMinutes"
        type="number"
        min="5"
        max="1440"
        step="1"
        :disabled="autoSyncIntervalMinutes === null || autoSyncLoading || autoSyncSaving"
        data-test="game-details-auto-sync-interval"
        @keydown.enter.prevent="saveInterval"
      />
      <button
        type="button"
        :disabled="!intervalValid || !intervalChanged || autoSyncLoading || autoSyncSaving"
        data-test="game-details-auto-sync-save-interval"
        @click="saveInterval"
      >{{ autoSyncSaving ? 'Saving…' : 'Save interval' }}</button>
      <small>5 minutes to 24 hours. A new interval takes effect on the next scheduler check.</small>
    </div>
    <p v-if="autoSyncError" class="admin-message admin-message--error" role="alert">{{ autoSyncError }}</p>
    <div class="admin-fields admin-fields--three">
      <label><span>Start date</span><input v-model="options.startDate" type="date" :disabled="Boolean(options.mlbGameId)" /></label>
      <label><span>End date</span><input v-model="options.endDate" type="date" :disabled="Boolean(options.mlbGameId)" /></label>
      <label><span>MLB game ID (optional)</span><input v-model="options.mlbGameId" type="number" min="1" placeholder="823443" /></label>
    </div>
    <button ref="syncButton" class="admin-button" type="submit" :disabled="anyActionRunning">
      {{ starting ? 'Starting synchronization…' : active ? 'Synchronization in progress…' : 'Synchronize game details' }}
    </button>

    <p v-if="task" class="game-details-last-run" data-test="game-details-last-run">
      {{ task.initiatedBy ? `Started by ${task.initiatedBy.name || task.initiatedBy.email}` : 'Automatic run' }} ·
      {{ formatTimestamp(task.createdAt) }} · {{ task.status }}
    </p>
    <AdminSyncProgress
      v-if="task"
      :task="task"
      :active="active"
      test-id="game-details-progress"
      aria-label="Game detail synchronization"
      @cancel="emit('cancel-active')"
    >
      <p v-if="analyticsRefreshProcessing(task)" class="sync-progress__notice" data-test="game-details-analytics-refresh-processing">Game detail synchronization is complete. Daily analytics refresh is now processing.</p>
      <p v-if="analyticsRefreshMessage(task)" :class="analyticsRefreshClass(task)" data-test="game-details-analytics-refresh">{{ analyticsRefreshMessage(task) }}</p>
      <button v-if="deferredAnalyticsRefreshAvailable(task)" type="button" class="admin-button admin-button--secondary" data-test="game-details-run-deferred-analytics-refresh" :disabled="anyActionRunning" @click="emit('refresh-analytics')">
        {{ runningTask === 'daily_analytics_refresh' ? 'Refreshing daily analytics…' : 'Run daily analytics refresh for this range' }}
      </button>
      <p v-if="workerPoolMessage(task)" class="sync-progress__notice" data-test="game-details-worker-pool-summary">{{ workerPoolMessage(task) }}</p>
      <div v-if="failureRows(task).length" class="sync-progress__failure-block" data-test="game-details-failure-details">
        <p class="sync-progress__error">Failure details</p>
        <ul class="sync-progress__failure-list"><li v-for="(entry, index) in failureRows(task)" :key="`${entry.mlbId || 'worker'}-${index}`">{{ failureText(entry) }}</li></ul>
      </div>
      <div v-if="workerErrorRows(task).length" class="sync-progress__failure-block" data-test="game-details-worker-errors">
        <p class="sync-progress__error">Worker errors</p>
        <ul class="sync-progress__failure-list"><li v-for="(message, index) in workerErrorRows(task)" :key="`worker-error-${index}`">{{ message }}</li></ul>
      </div>
    </AdminSyncProgress>
    <p v-if="error" class="admin-message admin-message--error" role="alert">{{ error }}</p>
  </AdminTaskCard>
</template>

<style scoped>
.game-details-auto-sync { display: flex; align-items: center; justify-content: space-between; gap: 1rem; margin: 1rem 0; padding: .9rem; border: 1px solid rgba(23,96,135,.2); border-radius: 12px; background: rgba(231,237,241,.55); }
.game-details-auto-sync strong { color: #10263d; font-size: .85rem; }
.game-details-auto-sync p { margin: .3rem 0 0; color: #53616b; font-size: .76rem; line-height: 1.4; }
.game-details-auto-sync button { min-width: 3.5rem; padding: .45rem .7rem; border: 0; border-radius: 999px; color: #fff; background: #20543c; font: inherit; font-weight: 800; cursor: pointer; }
.game-details-auto-sync button[aria-checked="false"] { background: #697784; }
.game-details-auto-sync button:disabled { opacity: .6; cursor: not-allowed; }
.game-details-auto-sync-interval { display: flex; align-items: center; flex-wrap: wrap; gap: .5rem; margin: -.25rem 0 1rem; color: #53616b; font-size: .76rem; }
.game-details-auto-sync-interval label { font-weight: 800; }
.game-details-auto-sync-interval input { width: 5.5rem; padding: .4rem; border: 1px solid rgba(16,38,61,.2); border-radius: 8px; background: #fffdf7; font: inherit; }
.game-details-auto-sync-interval button { padding: .45rem .7rem; border: 0; border-radius: 8px; color: #fff; background: #20543c; font: inherit; font-weight: 800; cursor: pointer; }
.game-details-auto-sync-interval button:disabled { opacity: .5; cursor: not-allowed; }
.game-details-auto-sync-interval small { flex-basis: 100%; color: #697784; }
.game-details-last-run { margin: .8rem 0 0; color: #53616b; font-size: .76rem; }
</style>
