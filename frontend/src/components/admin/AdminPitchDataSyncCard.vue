<script setup>
import { ref } from 'vue'
import { formatCount, formatDate } from '../../utils/adminFormatting'

import AdminSyncProgress from './AdminSyncProgress.vue'
import AdminTaskCard from './AdminTaskCard.vue'

defineProps({
  options: { type: Object, required: true },
  metrics: { type: Object, required: true },
  task: { type: Object, default: null },
  active: { type: Boolean, default: false },
  starting: { type: Boolean, default: false },
  anyActionRunning: { type: Boolean, default: false },
  error: { type: String, default: '' },
})
const emit = defineEmits(['submit', 'cancel-active'])
const syncButton = ref(null)

defineExpose({
  focusSyncButton: () => syncButton.value?.focus(),
})

</script>

<template>
  <AdminTaskCard
    number="02"
    source="Baseball Savant"
    title="Statcast pitch data"
    chip="Download + import"
    description="Downloads and bulk-imports pitch-by-pitch Statcast data, then refreshes daily analytics for the imported dates."
    data-test="pitch-download-form"
    @submit.prevent="emit('submit')"
  >
    <div class="data-coverage" data-test="pitch-data-coverage">
      <span>Currently stored</span>
      <dl v-if="metrics.earliestGameDate && metrics.latestGameDate">
        <div><dt>Earliest game</dt><dd>{{ formatDate(metrics.earliestGameDate) }}</dd></div>
        <div><dt>Latest game</dt><dd>{{ formatDate(metrics.latestGameDate) }}</dd></div>
      </dl>
      <p v-else>No Statcast pitch data is currently stored.</p>
      <small>Approximately {{ formatCount(metrics.approximateRowCount) }} pitch rows</small>
    </div>

    <div class="admin-fields admin-fields--four">
      <label><span>Start date</span><input v-model="options.startDate" type="date" required /></label>
      <label><span>End date</span><input v-model="options.endDate" type="date" required /></label>
      <label><span>Game types</span><input v-model="options.gameTypes" type="text" placeholder="R,W,D,L,F" required /></label>
      <label><span>Chunk days</span><input v-model.number="options.chunkDays" type="number" min="1" max="31" required /></label>
    </div>
    <label class="pitch-replace-existing">
      <input v-model="options.replaceExisting" type="checkbox" />
      <span>
        <strong>Replace completed game data</strong>
        <small>Redownload selected games and replace their existing local pitch rows.</small>
      </span>
    </label>

    <button ref="syncButton" class="admin-button" type="submit" :disabled="anyActionRunning">
      {{ starting ? 'Starting synchronization…' : active ? 'Synchronization in progress…' : 'Retrieve Statcast pitches' }}
    </button>

    <AdminSyncProgress
      v-if="task"
      :task="task"
      :active="active"
      progress-mode="pitch-data"
      test-id="pitch-data-progress"
      aria-label="Statcast pitch synchronization"
      @cancel="emit('cancel-active')"
    />
    <p v-if="error" class="admin-message admin-message--error">{{ error }}</p>
  </AdminTaskCard>
</template>

<style scoped>
.pitch-replace-existing { display: flex; gap: .65rem; align-items: flex-start; margin-top: .85rem; padding: .75rem; border: 1px solid rgba(16,38,61,.12); border-radius: 12px; background: rgba(16,38,61,.035); cursor: pointer; }
.pitch-replace-existing input { width: 16px; height: 16px; margin-top: .1rem; }
.pitch-replace-existing strong,.pitch-replace-existing small { display: block; }
.pitch-replace-existing strong { color: #173652; font-size: .78rem; }
.pitch-replace-existing small { margin-top: .2rem; color: #697784; font-size: .7rem; line-height: 1.35; }
</style>
