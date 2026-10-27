<script setup>
import { formatCount } from '../../utils/adminFormatting'
import AdminTaskCard from './AdminTaskCard.vue'

defineProps({
  options: { type: Object, required: true },
  metrics: { type: Object, required: true },
  downloading: { type: Boolean, default: false },
  anyActionRunning: { type: Boolean, default: false },
  error: { type: String, default: '' },
  summary: { type: String, default: '' },
})
const emit = defineEmits(['submit'])
const currentSeason = new Date().getFullYear()

</script>

<template>
  <AdminTaskCard
    number="01"
    source="MLB Stats API"
    title="Player season statistics"
    chip="Download + import"
    description="Downloads and imports season-level batting or pitching statistics for the selected year range."
    data-test="stats-download-form"
    @submit.prevent="emit('submit')"
  >
    <div class="data-coverage" data-test="player-season-stats-coverage">
      <span>Currently stored</span>
      <dl v-if="metrics.batting.earliestSeason || metrics.pitching.earliestSeason">
        <div>
          <dt>From season</dt>
          <dd>
            <span>Batting: {{ metrics.batting.earliestSeason ?? '—' }}</span>
            <span>Pitching: {{ metrics.pitching.earliestSeason ?? '—' }}</span>
          </dd>
        </div>
        <div>
          <dt>Through season</dt>
          <dd>
            <span>Batting: {{ metrics.batting.latestSeason ?? '—' }}</span>
            <span>Pitching: {{ metrics.pitching.latestSeason ?? '—' }}</span>
          </dd>
        </div>
      </dl>
      <p v-else>No player season statistics are currently stored.</p>
      <small>Approximately {{ formatCount(metrics.approximateRowCount) }} stat rows</small>
    </div>
    <div class="admin-fields admin-fields--four">
      <label>
        <span>Category</span>
        <select v-model="options.category">
          <option value="batting">Batting</option>
          <option value="pitching">Pitching</option>
        </select>
      </label>
      <label>
        <span>Start year</span>
        <input v-model.number="options.startYear" type="number" min="1876" :max="currentSeason + 1" required />
      </label>
      <label>
        <span>End year</span>
        <input v-model.number="options.endYear" type="number" min="1876" :max="currentSeason + 1" required />
      </label>
      <label class="admin-check">
        <input v-model="options.replaceSeason" type="checkbox" />
        <span>Replace season</span>
      </label>
    </div>
    <button class="admin-button" type="submit" :disabled="anyActionRunning">
      {{ downloading ? 'Downloading statistics…' : 'Retrieve player statistics' }}
    </button>
    <p v-if="error" class="admin-message admin-message--error">{{ error }}</p>
    <p v-else-if="summary" class="admin-message admin-message--success">{{ summary }}</p>
  </AdminTaskCard>
</template>
