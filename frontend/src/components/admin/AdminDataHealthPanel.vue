<script setup>
import { nextTick, ref, watch } from 'vue'
import { formatCount, formatTimestamp, humanize } from '../../utils/adminFormatting'

const props = defineProps({
  report: { type: Object, default: null },
  loading: { type: Boolean, default: false },
  error: { type: String, default: '' },
})
const emit = defineEmits(['refresh'])
const open = ref(false)
const dialog = ref(null)
const button = ref(null)
const includePostseason = ref(true)

watch(
  () => props.report?.includePostseason,
  (value) => {
    if (typeof value === 'boolean') includePostseason.value = value
  },
  { immediate: true },
)

async function openReport() {
  open.value = true
  await nextTick()
  dialog.value?.focus()
}

async function closeReport() {
  open.value = false
  await nextTick()
  button.value?.focus()
}

function runHealthCheck() {
  emit('refresh', includePostseason.value)
}

</script>

<template>
  <div class="data-health-summary" :class="report ? `data-health-summary--${report.status}` : ''" data-test="data-health-summary">
    <span>Data health</span>
    <strong :class="report?.status === 'healthy' ? 'data-health-text--healthy' : ''">{{ loading ? 'Checking…' : report ? humanize(report.status) : 'Not checked' }}</strong>
    <small v-if="report">{{ report.summary.criticalCount }} critical · {{ report.summary.warningCount }} warnings</small>
    <small v-else>Run contextual completeness checks</small>
    <button ref="button" type="button" data-test="data-health-button" :disabled="loading" @click="openReport">
      {{ report ? 'View report' : 'Configure health check' }}
    </button>
  </div>

  <div v-if="open" class="database-modal" data-test="data-health-modal" @click.self="closeReport" @keydown.esc="closeReport">
    <section ref="dialog" class="database-insights data-health-insights" data-test="data-health-details" role="dialog" aria-modal="true" aria-labelledby="data-health-title" tabindex="-1">
      <header class="database-insights__heading">
        <div><p class="eyebrow">Completeness and integrity</p><h2 id="data-health-title">Data health</h2></div>
        <div class="database-insights__heading-actions">
          <p v-if="report?.checkedAt">Checked {{ formatTimestamp(report.checkedAt) }}</p>
          <button type="button" data-test="data-health-close" aria-label="Close data health details" @click="closeReport">×</button>
        </div>
      </header>

      <p v-if="error" class="admin-message admin-message--error" role="alert">{{ error }}</p>
      <div v-if="loading && !report" class="data-health-loading">Checking schedules, games, players, pitches, and analytics…</div>

      <div class="data-health-options">
        <label>
          <input v-model="includePostseason" type="checkbox" data-test="data-health-include-postseason" />
          <span>Include postseason games and associated stats</span>
        </label>
        <button type="button" :disabled="loading" data-test="data-health-refresh" @click="runHealthCheck">
          {{ loading ? 'Checking…' : report ? 'Run check again' : 'Run health check' }}
        </button>
      </div>

      <template v-if="report">
        <div class="database-summary-grid data-health-totals">
          <article><span>Overall status</span><strong :class="`data-health-text--${report.status}`">{{ humanize(report.status) }}</strong><small>Calculation version {{ report.calculationVersion }}</small></article>
          <article><span>Healthy checks</span><strong>{{ formatCount(report.summary.healthyCount) }}</strong><small>of {{ formatCount(report.summary.checkCount) }} checks</small></article>
          <article><span>Warnings</span><strong class="data-health-text--warning">{{ formatCount(report.summary.warningCount) }}</strong><small>Checks needing review</small></article>
          <article><span>Critical</span><strong class="data-health-text--critical">{{ formatCount(report.summary.criticalCount) }}</strong><small>Checks likely affecting accuracy</small></article>
        </div>
        <div class="data-health-toolbar">
          <p>{{ formatCount(report.summary.affectedRecordCount) }} total findings across all checks · Postseason {{ report.includePostseason ? 'included' : 'excluded' }}</p>
        </div>
        <div class="data-health-checks">
          <article v-for="check in report.checks" :key="check.id" class="data-health-check" :class="`data-health-check--${check.status}`" :data-test="`data-health-check-${check.id}`">
            <header><div><span>{{ check.category }}</span><h3>{{ check.name }}</h3></div><strong>{{ check.status === 'healthy' ? 'Healthy' : `${formatCount(check.affectedCount)} affected` }}</strong></header>
            <p>{{ check.description }}</p>
            <ul v-if="check.examples.length"><li v-for="example in check.examples" :key="example"><code>{{ example }}</code></li></ul>
            <footer v-if="check.status !== 'healthy'"><span>Suggested action</span>{{ check.recommendation }}</footer>
          </article>
        </div>
      </template>
    </section>
  </div>
</template>
