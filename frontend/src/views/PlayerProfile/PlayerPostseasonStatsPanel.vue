<script setup>
import { computed, inject } from 'vue'

const { player, sectionLoading } = inject('player-profile-context')

const groups = computed(() => [
  { key: 'batting', label: 'Batting', data: player.value?.postseasonStats?.batting },
  { key: 'pitching', label: 'Pitching', data: player.value?.postseasonStats?.pitching },
].filter((group) => group.data?.available))

function teamLabel(teams) {
  return (teams || []).map((team) => team.abbreviation).filter(Boolean).join('/') || '—'
}

function value(values, key) {
  const result = values?.[key]
  return result === null || result === undefined || result === '' ? '—' : result
}
</script>

<template>
  <section
    id="player-profile-panel-postseason"
    class="profile-stat-table profile-career-table postseason-stats-panel"
    role="tabpanel"
    aria-labelledby="player-profile-tab-postseason"
    data-test="postseason-stats-panel"
  >
    <header class="profile-section-heading">
      <div>
        <p class="eyebrow">October ledger</p>
        <h2>Postseason Stats</h2>
      </div>
      <span>Completed postseason games</span>
    </header>

    <p v-if="sectionLoading('postseason').value" class="profile-empty">Loading postseason statistics…</p>
    <div v-else-if="groups.length" class="postseason-stat-groups">
      <article v-for="group in groups" :key="group.key" :data-test="`postseason-${group.key}-stats`">
        <h3>{{ group.label }}</h3>
        <div class="career-table-wrap">
          <table class="career-table">
            <thead>
              <tr>
                <th class="career-table__season">Season</th>
                <th class="career-table__team">Team</th>
                <th v-for="column in group.data.columns" :key="column.key" class="career-table__stat">{{ column.label }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="season in group.data.seasons" :key="`${group.key}-${season.season}`">
                <th class="career-table__season">{{ season.season }}</th>
                <td class="career-table__team">{{ teamLabel(season.teams) }}</td>
                <td v-for="column in group.data.columns" :key="column.key" class="career-table__stat">{{ value(season.values, column.key) }}</td>
              </tr>
            </tbody>
            <tfoot>
              <tr>
                <th class="career-table__season">Career</th>
                <td class="career-table__team">Total</td>
                <td v-for="column in group.data.columns" :key="column.key" class="career-table__stat">{{ value(group.data.career.values, column.key) }}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </article>
    </div>
    <p v-else class="profile-empty">No postseason statistics are stored for this player yet.</p>
  </section>
</template>

<style scoped>
.postseason-stat-groups { display:grid; gap:1.25rem; }
.postseason-stat-groups h3 { margin:0 0 .65rem; color:#10263d; font-family:'Avenir Next Condensed',sans-serif; font-size:1.35rem; text-transform:uppercase; }
</style>
