<script setup>
import { computed, inject } from 'vue'

const {
  player, sectionLoading, titleize, contextualMetricLabel, contextualValue, peerAverage, peerLabel,
  percentileStyle, benchmarkPeriodLabel,
} = inject('player-profile-context')

const props = defineProps({
  metricKeys: { type: Array, default: null },
  title: { type: String, default: 'Benchmarks & percentiles' },
  dataTest: { type: String, default: 'contextual-benchmarks' },
  emptyMessage: { type: String, default: 'Benchmark context will appear after daily analytics have been calculated for multiple players.' },
})

const metricOrder = [
  'ops',
  'batter_strikeout_percentage',
  'batter_walk_percentage',
  'batter_whiff_percentage',
  'batter_chase_percentage',
  'average_exit_velocity',
  'hard_hit_percentage',
  'barrel_percentage',
  'maximum_exit_velocity',
  'average_bat_speed',
  'pitcher_strikeout_percentage',
  'pitcher_walk_percentage',
  'pitcher_whiff_percentage',
  'pitcher_chase_percentage',
  'pitcher_average_velocity',
  'pitcher_average_spin_rate',
  'pitch_usage_percentage',
]

const benchmarkMetrics = computed(() => player.value.contextualBenchmarks.metrics
  .filter((metric) => props.metricKeys
    ? props.metricKeys.includes(metric.metricKey)
    : metric.metricKey !== 'pitch_usage_percentage')
  .slice()
  .sort((left, right) => {
    const leftIndex = metricOrder.indexOf(left.metricKey)
    const rightIndex = metricOrder.indexOf(right.metricKey)
    return (leftIndex === -1 ? metricOrder.length : leftIndex) - (rightIndex === -1 ? metricOrder.length : rightIndex)
  }))
</script>

<template>
  <section class="profile-panel contextual-panel" :data-test="dataTest">
    <header class="profile-section-heading">
      <div>
        <p class="eyebrow">League Context</p>
        <h2>{{ title }}</h2>
      </div>
      <span>{{ benchmarkPeriodLabel }}</span>
    </header>

    <p
      v-if="sectionLoading('analytics').value"
      class="contextual-benchmarks-loading"
      role="status"
      aria-live="polite"
      data-test="contextual-benchmarks-loading"
    >
      <span class="contextual-benchmarks-loading__spinner" aria-hidden="true"></span>
      Loading benchmark context…
    </p>
    <div v-else-if="benchmarkMetrics.length" class="context-percentile-board">
      <div class="context-percentile-board__scale" aria-hidden="true">
        <span>Poor</span>
        <span>Average</span>
        <span>Great</span>
      </div>

      <div class="context-percentile-board__metrics">
        <article
          v-for="metric in benchmarkMetrics"
          :key="`${metric.metricKey}-${metric.dimensionValue || 'all'}`"
          class="context-percentile-row"
          :style="percentileStyle(metric.percentile)"
        >
          <div class="context-percentile-row__metric">
            <strong>{{ contextualMetricLabel(metric) }}</strong>
            <small>
              {{ titleize(metric.metricGroup) }} · MLB {{ contextualValue(metric.mlbAverage, metric.unit) }}
              <template v-if="peerAverage(metric) !== null && peerAverage(metric) !== undefined">
                · {{ peerLabel(metric) }} {{ contextualValue(peerAverage(metric), metric.unit) }}
              </template>
            </small>
          </div>

          <div
            class="context-percentile-row__gauge"
            role="img"
            :aria-label="`${contextualMetricLabel(metric)} percentile: ${Math.round(metric.percentile)}`"
          >
            <span class="context-percentile-row__fill"></span>
            <span class="percentile-pill">{{ Math.round(metric.percentile) }}</span>
          </div>

          <div class="context-percentile-row__value">
            <strong>{{ contextualValue(metric.rawValue, metric.unit) }}</strong>
            <small>{{ Number(metric.sampleSize || 0).toLocaleString() }} sample</small>
          </div>
        </article>
      </div>
    </div>
    <p v-else class="profile-empty">
      {{ player.contextualBenchmarks.unavailableReason || emptyMessage }}
    </p>
  </section>
</template>
