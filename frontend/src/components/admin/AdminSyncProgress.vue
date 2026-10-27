<script setup>
import { computed } from 'vue'

import { formatCount, formatElapsed } from '../../utils/adminFormatting'
import { taskStatusLabel } from '../../utils/gameDetailsTaskPresentation'

const props = defineProps({
  task: { type: Object, required: true },
  active: { type: Boolean, default: false },
  testId: { type: String, required: true },
  ariaLabel: { type: String, required: true },
  itemNoun: { type: String, default: 'games' },
  currentItemLabel: { type: String, default: 'Current game' },
  cancelItemNoun: { type: String, default: 'game' },
  progressMode: { type: String, default: 'standard' },
})
const emit = defineEmits(['cancel'])

const pitchDataPhase = computed(() => props.task.resultData?.progress_phase || 'downloading')
const currentItemHeading = computed(() => {
  if (props.progressMode !== 'pitch-data') return props.currentItemLabel
  if (pitchDataPhase.value === 'analytics') return 'Current step'
  if (/^(Downloading|Downloaded) Statcast/.test(props.task.currentItemLabel || '')) return 'Download progress'
  return props.currentItemLabel
})
const progressLabel = computed(() => {
  if (props.progressMode !== 'pitch-data') return taskStatusLabel(props.task.status)
  if (pitchDataPhase.value === 'analytics') return 'Finalizing analytics'
  if (pitchDataPhase.value === 'complete') return 'Synchronization complete'
  return 'Downloading and importing'
})
const progressSummary = computed(() => {
  if (props.progressMode === 'pitch-data' && pitchDataPhase.value === 'analytics') return 'Finalizing imported pitch data…'
  return `${formatCount(props.task.processedItems)} of ${formatCount(props.task.totalItems)} ${props.itemNoun}`
})
const cancellationAvailable = computed(() => (
  props.active && !(props.progressMode === 'pitch-data' && pitchDataPhase.value === 'analytics')
))

</script>

<template>
  <section class="sync-progress" :data-test="testId" aria-live="polite">
    <header>
      <div>
        <span>{{ progressLabel }}</span>
        <strong>{{ progressSummary }}</strong>
      </div>
      <b>{{ task.progressPercentage.toFixed(1) }}%</b>
    </header>
    <div
      class="sync-progress__track"
      role="progressbar"
      :aria-valuenow="task.progressPercentage"
      aria-valuemin="0"
      aria-valuemax="100"
      :aria-label="`${ariaLabel} ${task.progressPercentage}% complete`"
    >
      <i :style="{ width: `${task.progressPercentage}%` }"></i>
    </div>
    <dl>
      <div><dt>Completed</dt><dd>{{ formatCount(task.completedItems) }}</dd></div>
      <div><dt>Failed</dt><dd>{{ formatCount(task.failedItems) }}</dd></div>
      <div><dt>Elapsed</dt><dd>{{ formatElapsed(task.elapsedSeconds) }}</dd></div>
      <div><dt>Remaining</dt><dd>{{ active ? formatElapsed(task.estimatedRemainingSeconds) : '—' }}</dd></div>
    </dl>
    <p v-if="task.currentItemLabel" class="sync-progress__current"><span>{{ currentItemHeading }}</span>{{ task.currentItemLabel }}</p>
    <p
      v-if="progressMode === 'pitch-data' && pitchDataPhase === 'analytics'"
      class="sync-progress__notice"
      data-test="pitch-data-analytics-refresh-processing"
    >
      Game downloads and imports are complete. Daily analytics are now being refreshed.
    </p>
    <p v-if="task.cancelRequested && active" class="sync-progress__notice">Cancellation requested. The current {{ cancelItemNoun }} will finish safely before the task stops.</p>
    <p v-else-if="task.errorMessage" class="sync-progress__error">{{ task.errorMessage }}</p>

    <slot />

    <button
      v-if="cancellationAvailable"
      type="button"
      class="admin-button admin-button--danger"
      :data-test="`${testId.replace('-progress', '')}-cancel-active`"
      :disabled="task.cancelRequested"
      @click="emit('cancel')"
    >
      {{ task.cancelRequested ? 'Cancellation requested…' : `Cancel after current ${cancelItemNoun}` }}
    </button>
  </section>
</template>

<style>
.sync-progress { margin-top: 1rem; padding: .9rem; border: 1px solid rgba(23,96,135,.2); border-radius: 14px; background: rgba(231,237,241,.72); }
.sync-progress header { display: flex; justify-content: space-between; gap: 1rem; align-items: flex-end; }
.sync-progress header div { display: grid; gap: .15rem; }
.sync-progress header span, .sync-progress dt, .sync-progress__current span { color: #61707b; font-size: .64rem; font-weight: 850; letter-spacing: .06em; text-transform: uppercase; }
.sync-progress header strong, .sync-progress header b { color: #10263d; }
.sync-progress header b { font-family: 'Avenir Next Condensed', sans-serif; font-size: 1.4rem; }
.sync-progress__track { height: 10px; margin-top: .65rem; overflow: hidden; border-radius: 999px; background: rgba(16,38,61,.12); }
.sync-progress__track i { position: relative; display: block; width: 0; height: 100%; overflow: hidden; border-radius: inherit; background: linear-gradient(90deg, #176087, #2f7d32); transition: width 240ms ease; }
.sync-progress__track i::after { position: absolute; inset: 0 auto 0 -45%; width: 45%; background: linear-gradient(90deg, transparent, rgba(255,255,255,.3), transparent); content: ''; animation: sync-progress-shimmer 1.8s ease-in-out infinite; }
@keyframes sync-progress-shimmer { to { transform: translateX(325%); } }
.sync-progress dl { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: .5rem; margin-top: .75rem; }
.sync-progress dl div { display: grid; gap: .1rem; }
.sync-progress dd { color: #263e52; font-size: .84rem; font-weight: 800; }
.sync-progress__current, .sync-progress__notice, .sync-progress__error { margin-top: .7rem; color: #405362; font-size: .78rem; }
.sync-progress__current span { display: block; margin-bottom: .12rem; }
.sync-progress__notice { color: #8a5a12; }
.sync-progress__error { color: #992e26; }
.sync-progress__failure-block { margin-top: .55rem; }
.sync-progress__failure-list { margin: .35rem 0 0; padding-left: 1rem; color: #992e26; font-size: .76rem; line-height: 1.35; }
.sync-progress__failure-list li + li { margin-top: .18rem; }
.sync-progress .admin-button { margin-top: .75rem; }
.admin-button--danger { background: #8f2d24; }
@media (max-width: 680px) { .sync-progress dl { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
@media (prefers-reduced-motion: reduce) { .sync-progress__track i::after { animation: none; } }
</style>
