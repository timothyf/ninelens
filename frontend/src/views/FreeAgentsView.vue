<script setup>
import { computed, nextTick, onMounted, ref } from 'vue'
import { API_BASE_URL } from '../config'

const data = ref({ season: null, as_of: null, batters: [], pitchers: [] })
const loading = ref(true)
const error = ref('')
const search = ref('')
const activeTab = ref('batters')

function onTabKeydown(event) {
  const tabs = ['batters', 'pitchers']
  let next = tabs.indexOf(activeTab.value)
  if (event.key === 'ArrowRight') next = (next + 1) % tabs.length
  else if (event.key === 'ArrowLeft') next = (next - 1 + tabs.length) % tabs.length
  else if (event.key === 'Home') next = 0
  else if (event.key === 'End') next = tabs.length - 1
  else return
  event.preventDefault()
  activeTab.value = tabs[next]
  nextTick(() => document.getElementById(`free-agent-tab-${activeTab.value}`)?.focus())
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const response = await fetch(`${API_BASE_URL}/api/free_agents`, { headers: { Accept: 'application/json' } })
    if (!response.ok) throw new Error(`Request failed with status ${response.status}`)
    data.value = (await response.json()).data || data.value
  } catch (cause) {
    error.value = 'Unable to load free agents. Please try again.'
    console.error(cause)
  } finally {
    loading.value = false
  }
}

onMounted(load)

const matches = (entry) => `${entry.player_name} ${entry.position || ''} ${entry.former_team || ''}`.toLowerCase().includes(search.value.trim().toLowerCase())
const batters = computed(() => (data.value.batters || []).filter(matches))
const pitchers = computed(() => (data.value.pitchers || []).filter(matches))

function stat(entry, name) {
  return entry.stat_line?.values?.[name] ?? null
}

function integer(value) {
  return value == null ? '—' : Math.round(Number(value)).toLocaleString('en-US')
}

function rate(value, digits = 3, leadingZero = false) {
  if (value == null) return '—'
  const formatted = Number(value).toFixed(digits)
  return leadingZero ? formatted : formatted.replace(/^0\./, '.')
}

function war(value) {
  return value == null ? '—' : Number(value).toFixed(1)
}

function date(value) {
  if (!value) return ''
  return new Intl.DateTimeFormat('en-US', { month: 'long', day: 'numeric', year: 'numeric' }).format(new Date(`${value}T12:00:00`))
}
</script>

<template>
  <main class="free-agents-page">
    <header class="free-agents-hero">
      <RouterLink :to="{ name: 'home' }" class="free-agents-back">← Back to home</RouterLink>
      <p class="free-agents-eyebrow">Around the league</p>
      <h1>Free Agents</h1>
      <p v-if="data.season" class="free-agents-subtitle">{{ data.season }}–{{ data.season + 1 }} offseason · Confirmed free agents without a recorded new team as of {{ date(data.as_of) }}.</p>
    </header>

    <div v-if="loading" class="free-agents-state" role="status">Loading free agents…</div>
    <div v-else-if="error" class="free-agents-state is-error" role="alert">{{ error }} <button type="button" @click="load">Try again</button></div>
    <template v-else>
      <div class="free-agents-toolbar">
        <label for="free-agents-search">Search players, positions, or former teams</label>
        <input id="free-agents-search" v-model="search" type="search" placeholder="Search free agents" />
        <span>Sorted by latest available WAR</span>
      </div>

      <div class="free-agents-tabs" role="tablist" aria-label="Free agent category" @keydown="onTabKeydown">
        <button id="free-agent-tab-batters" type="button" role="tab" aria-controls="free-agent-batters-panel" :aria-selected="activeTab === 'batters'" :tabindex="activeTab === 'batters' ? 0 : -1" @click="activeTab = 'batters'">Batters <span>{{ batters.length }}</span></button>
        <button id="free-agent-tab-pitchers" type="button" role="tab" aria-controls="free-agent-pitchers-panel" :aria-selected="activeTab === 'pitchers'" :tabindex="activeTab === 'pitchers' ? 0 : -1" @click="activeTab = 'pitchers'">Pitchers <span>{{ pitchers.length }}</span></button>
      </div>

      <section v-if="activeTab === 'batters'" id="free-agent-batters-panel" class="free-agents-section" role="tabpanel" aria-labelledby="free-agent-tab-batters" tabindex="0">
        <header><div><p class="free-agents-eyebrow">At the plate</p><h2>Free agent batters <small>{{ batters.length }}</small></h2></div></header>
        <div class="free-agents-table-wrap">
          <table>
            <thead><tr><th scope="col">Player</th><th scope="col">Age</th><th scope="col">Pos</th><th scope="col">Last team</th><th scope="col">Season</th><th scope="col">MLB seasons</th><th scope="col">G</th><th scope="col">AVG</th><th scope="col">OBP</th><th scope="col">SLG</th><th scope="col">HR</th><th scope="col">RBI</th><th scope="col">WAR</th></tr></thead>
            <tbody>
              <tr v-for="agent in batters" :key="agent.player_id">
                <th scope="row"><RouterLink :to="{ name: 'player-profile', params: { id: agent.player_id } }">{{ agent.player_name }}</RouterLink></th>
                <td>{{ integer(agent.age) }}</td><td>{{ agent.position || '—' }}</td><td>{{ agent.former_team || '—' }}</td><td>{{ agent.stat_line?.season || '—' }}</td><td>{{ integer(agent.experience_years) }}</td>
                <td>{{ integer(stat(agent, 'G')) }}</td><td>{{ rate(stat(agent, 'AVG')) }}</td><td>{{ rate(stat(agent, 'OBP')) }}</td><td>{{ rate(stat(agent, 'SLG')) }}</td><td>{{ integer(stat(agent, 'HR')) }}</td><td>{{ integer(stat(agent, 'RBI')) }}</td><td class="free-agents-war">{{ war(agent.war) }}</td>
              </tr>
              <tr v-if="!batters.length"><td colspan="13" class="free-agents-empty">{{ search ? 'No batters match your search.' : 'No confirmed free agent batters are stored yet.' }}</td></tr>
            </tbody>
          </table>
        </div>
      </section>

      <section v-if="activeTab === 'pitchers'" id="free-agent-pitchers-panel" class="free-agents-section" role="tabpanel" aria-labelledby="free-agent-tab-pitchers" tabindex="0">
        <header><div><p class="free-agents-eyebrow">On the mound</p><h2>Free agent pitchers <small>{{ pitchers.length }}</small></h2></div></header>
        <div class="free-agents-table-wrap">
          <table>
            <thead><tr><th scope="col">Player</th><th scope="col">Age</th><th scope="col">Pos</th><th scope="col">Last team</th><th scope="col">Season</th><th scope="col">MLB seasons</th><th scope="col">G</th><th scope="col">W</th><th scope="col">L</th><th scope="col">ERA</th><th scope="col">WHIP</th><th scope="col">IP</th><th scope="col">SO</th><th scope="col">WAR</th></tr></thead>
            <tbody>
              <tr v-for="agent in pitchers" :key="agent.player_id">
                <th scope="row"><RouterLink :to="{ name: 'player-profile', params: { id: agent.player_id } }">{{ agent.player_name }}</RouterLink></th>
                <td>{{ integer(agent.age) }}</td><td>{{ agent.position || '—' }}</td><td>{{ agent.former_team || '—' }}</td><td>{{ agent.stat_line?.season || '—' }}</td><td>{{ integer(agent.experience_years) }}</td>
                <td>{{ integer(stat(agent, 'G')) }}</td><td>{{ integer(stat(agent, 'W')) }}</td><td>{{ integer(stat(agent, 'L')) }}</td><td>{{ rate(stat(agent, 'ERA'), 2, true) }}</td><td>{{ rate(stat(agent, 'WHIP'), 3, true) }}</td><td>{{ stat(agent, 'IP') == null ? '—' : Number(stat(agent, 'IP')).toFixed(1) }}</td><td>{{ integer(stat(agent, 'SO')) }}</td><td class="free-agents-war">{{ war(agent.war) }}</td>
              </tr>
              <tr v-if="!pitchers.length"><td colspan="14" class="free-agents-empty">{{ search ? 'No pitchers match your search.' : 'No confirmed free agent pitchers are stored yet.' }}</td></tr>
            </tbody>
          </table>
        </div>
      </section>
      <p class="free-agents-note">Age is as of {{ date(data.as_of) }}. Stats are from each player’s latest stored MLB season. WAR may come from a different latest available season.</p>
    </template>
  </main>
</template>

<style scoped>
.free-agents-page { max-width: 1500px; margin: 0 auto; padding: clamp(1.25rem, 3vw, 3rem); color: #10263d; }
.free-agents-hero { margin: 0 0 2rem; }
.free-agents-back { color: #34556a; font-weight: 800; text-decoration: none; font-size: .9rem; }
.free-agents-back:hover, .free-agents-section a:hover { text-decoration: underline; }
.free-agents-eyebrow { margin: 1.8rem 0 .35rem; color: #a73629; font-weight: 900; letter-spacing: .17em; text-transform: uppercase; font-size: .78rem; }
.free-agents-hero h1 { margin: 0; font-size: clamp(2.6rem, 5vw, 5rem); line-height: 1; text-transform: uppercase; letter-spacing: -.04em; }
.free-agents-subtitle { max-width: 70ch; color: #576b78; font-size: 1rem; }
.free-agents-toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: .75rem 1rem; margin-bottom: 1.5rem; color: #536674; font-size: .85rem; font-weight: 700; }
.free-agents-toolbar input { min-width: min(100%, 20rem); padding: .7rem .85rem; border: 1px solid #c8d2d6; border-radius: .65rem; background: white; color: #10263d; font: inherit; }
.free-agents-toolbar span { margin-left: auto; }
.free-agents-tabs { display: flex; gap: .4rem; margin: 0 0 1rem; border-bottom: 1px solid #d9d9d1; }
.free-agents-tabs button { margin: 0; padding: .8rem 1.2rem; border: 0; border-bottom: 3px solid transparent; background: transparent; color: #61717d; font: inherit; font-weight: 900; cursor: pointer; }
.free-agents-tabs button[aria-selected="true"] { border-bottom-color: #a73629; color: #10263d; }
.free-agents-tabs button:hover { color: #10263d; }
.free-agents-tabs button span { margin-left: .3rem; font-size: .78em; }
.free-agents-tabs button:focus-visible { outline: 2px solid #183e5b; outline-offset: -2px; }
.free-agents-section { margin: 0 0 1.5rem; padding: clamp(1rem, 2vw, 1.6rem); border: 1px solid #ddd9ce; border-radius: 1.35rem; background: #fff; }
.free-agents-section header { margin-bottom: 1rem; }
.free-agents-section .free-agents-eyebrow { margin: 0 0 .2rem; }
.free-agents-section h2 { margin: 0; font-size: clamp(1.4rem, 2vw, 2rem); }
.free-agents-section h2 small { color: #6b7880; font-size: .65em; }
.free-agents-table-wrap { overflow-x: auto; }
.free-agents-section table { width: 100%; min-width: 850px; border-collapse: collapse; font-variant-numeric: tabular-nums; }
.free-agents-section th, .free-agents-section td { padding: .75rem .55rem; border-bottom: 1px solid #e8e6df; text-align: right; white-space: nowrap; font-size: .84rem; }
.free-agents-section thead th { color: #63727d; font-size: .71rem; text-transform: uppercase; letter-spacing: .06em; }
.free-agents-section th:first-child, .free-agents-section td:first-child { text-align: left; }
.free-agents-section tbody tr:last-child th, .free-agents-section tbody tr:last-child td { border-bottom: 0; }
.free-agents-section tbody tr:hover { background: #f6f8f8; }
.free-agents-section a { color: #10263d; font-weight: 900; text-decoration: none; }
.free-agents-war { font-weight: 900; }
.free-agents-empty { text-align: center !important; color: #63727d; padding: 1.5rem !important; }
.free-agents-state { padding: 2rem; border-radius: 1rem; background: #fff; color: #536674; }
.free-agents-state.is-error { color: #9f3027; }
.free-agents-state button { margin-left: .5rem; cursor: pointer; }
.free-agents-note { color: #667780; font-size: .8rem; }
@media (max-width: 650px) { .free-agents-toolbar span { width: 100%; margin-left: 0; } }
</style>
