<script setup>
import { computed } from 'vue'
import { formatDate } from '../../utils/adminFormatting'

import AdminTaskCard from './AdminTaskCard.vue'
import AdminTaskResult from './AdminTaskResult.vue'

const props = defineProps({
  options: { type: Object, required: true },
  importRange: { type: Object, required: true },
  dateRange: { type: Object, required: true },
  overviewLoading: { type: Boolean, default: false },
  overviewError: { type: String, default: '' },
  anyActionRunning: { type: Boolean, default: false },
  runningTask: { type: String, default: '' },
  task: { type: Object, default: null },
  error: { type: String, default: '' },
  result: { type: Object, default: null },
})
const emit = defineEmits(['submit'])

const hasImportedSchedule = computed(
  () => Boolean(props.importRange.earliestImportDate && props.importRange.latestImportDate),
)
const hasStoredGames = computed(
  () => Boolean(props.dateRange.earliestGameDate && props.dateRange.latestGameDate),
)

</script>

<template>
  <AdminTaskCard
    source="Games & schedules"
    title="MLB schedule synchronization"
    command="mlb_schedule:sync"
    description="Downloads MLB schedules and updates games, teams, venues, statuses, and probable pitchers for the selected dates."
    data-test="schedule-sync-form"
    @submit.prevent="emit('submit')"
  >
    <div class="schedule-coverage" data-test="schedule-date-range">
      <p v-if="overviewLoading">Loading stored dates…</p>
      <p v-else-if="overviewError" class="schedule-coverage__error">{{ overviewError }}</p>
      <div v-else class="schedule-coverage__ranges">
        <section class="schedule-coverage__range">
          <span>Imported schedule coverage</span>
          <dl v-if="hasImportedSchedule">
            <div>
              <dt>From</dt>
              <dd>{{ formatDate(importRange.earliestImportDate) }}</dd>
            </div>
            <div>
              <dt>Through</dt>
              <dd>{{ formatDate(importRange.latestImportDate) }}</dd>
            </div>
          </dl>
          <p v-else>No schedule windows have been imported.</p>
        </section>
        <section class="schedule-coverage__range">
          <span>Stored game-date span</span>
          <dl v-if="hasStoredGames">
            <div>
              <dt>Earliest game</dt>
              <dd>{{ formatDate(dateRange.earliestGameDate) }}</dd>
            </div>
            <div>
              <dt>Latest game</dt>
              <dd>{{ formatDate(dateRange.latestGameDate) }}</dd>
            </div>
          </dl>
          <p v-else>No games are currently stored.</p>
        </section>
      </div>
    </div>
    <div class="admin-fields admin-fields--four">
      <label><span>Start date</span><input v-model="options.startDate" type="date" required /></label>
      <label><span>End date</span><input v-model="options.endDate" type="date" required /></label>
      <label><span>Game types</span><input v-model="options.gameTypes" type="text" required /></label>
      <label><span>Sport ID</span><input v-model.number="options.sportId" type="number" min="1" required /></label>
    </div>
    <button class="admin-button" type="submit" :disabled="anyActionRunning">
      {{ runningTask === 'mlb_schedule_sync' ? 'Synchronizing schedule…' : 'Synchronize schedule' }}
    </button>
    <AdminTaskResult :error="error" :result="result" :task="task" />
  </AdminTaskCard>
</template>

<style scoped>
.schedule-coverage {
  margin-top: 1rem;
  padding: 0.8rem 0.9rem;
  border: 1px solid rgba(16, 38, 61, 0.1);
  border-radius: 14px;
  background: rgba(231, 237, 241, 0.7);
}

.schedule-coverage__ranges {
  display: grid;
  gap: 0.9rem;
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.schedule-coverage__range {
  min-width: 0;
}

.schedule-coverage__range + .schedule-coverage__range {
  padding-left: 0.9rem;
  border-left: 1px solid rgba(16, 38, 61, 0.1);
}

.schedule-coverage__range > span,
.schedule-coverage dt {
  color: #61707b;
  font-size: 0.66rem;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.schedule-coverage > p,
.schedule-coverage__range > p {
  margin-top: 0.35rem;
  color: #53616b;
  font-size: 0.84rem;
}

.schedule-coverage dl {
  display: grid;
  gap: 0.75rem;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  margin-top: 0.45rem;
}

.schedule-coverage dl div {
  min-width: 0;
}

.schedule-coverage dd {
  color: #10263d;
  font-size: 0.98rem;
  font-weight: 850;
}

.schedule-coverage .schedule-coverage__error {
  color: #992e26;
}

@media (max-width: 680px) {
  .schedule-coverage__ranges {
    grid-template-columns: 1fr;
  }

  .schedule-coverage__range + .schedule-coverage__range {
    padding-top: 0.9rem;
    padding-left: 0;
    border-top: 1px solid rgba(16, 38, 61, 0.1);
    border-left: 0;
  }
}
</style>
