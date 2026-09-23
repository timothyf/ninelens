<script setup>
import AdminTaskCard from './AdminTaskCard.vue'

defineProps({
  options: { type: Object, required: true },
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
    number="02"
    source="FanGraphs RosterResource"
    title="Player salaries and contracts"
    chip="Download + update"
    description="Download the latest team payroll pages and save player contract details, AAV, and year-by-year salaries as a local CSV."
    data-test="contracts-download-form"
    @submit.prevent="emit('submit')"
  >
    <div class="admin-fields admin-fields--two">
      <label>
        <span>Season</span>
        <input v-model.number="options.season" type="number" min="1876" :max="currentSeason + 1" required />
      </label>
    </div>
    <button class="admin-button" type="submit" :disabled="anyActionRunning">
      {{ downloading ? 'Updating salary and contract data…' : 'Download salary and contract data' }}
    </button>
    <p v-if="error" class="admin-message admin-message--error">{{ error }}</p>
    <p v-else-if="summary" class="admin-message admin-message--success">{{ summary }}</p>
  </AdminTaskCard>
</template>
