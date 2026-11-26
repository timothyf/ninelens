<script setup>
import { computed, onMounted, ref } from 'vue'
import { API_BASE_URL } from '../config'

const data = ref({ season: null, as_of: null, transactions: [] })
const loading = ref(true)
const error = ref('')
const search = ref('')
const type = ref('all')

async function load() {
  loading.value = true
  error.value = ''
  try {
    const response = await fetch(`${API_BASE_URL}/api/offseason_transactions`, { headers: { Accept: 'application/json' } })
    if (!response.ok) throw new Error(`Request failed with status ${response.status}`)
    data.value = (await response.json()).data || data.value
  } catch (cause) {
    error.value = 'Unable to load offseason transactions. Please try again.'
    console.error(cause)
  } finally {
    loading.value = false
  }
}

onMounted(load)

const transactions = computed(() => (data.value.transactions || []).filter((move) => {
  if (type.value !== 'all' && move.type !== type.value) return false
  const text = `${move.player_name || ''} ${move.description || ''}`.toLowerCase()
  return text.includes(search.value.trim().toLowerCase())
}))

function formatDate(value, options = { month: 'short', day: 'numeric', year: 'numeric' }) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('en-US', options).format(new Date(`${value}T12:00:00`))
}
</script>

<template>
  <main class="transactions-page">
    <header class="transactions-hero">
      <RouterLink :to="{ name: 'home' }" class="transactions-back">← Back to home</RouterLink>
      <p class="transactions-eyebrow">Around the league</p>
      <h1>Offseason Transactions</h1>
      <p v-if="data.season" class="transactions-subtitle">{{ data.season }}–{{ data.season + 1 }} offseason · Trades and signings recorded through {{ formatDate(data.as_of) }}.</p>
    </header>

    <div v-if="loading" class="transactions-state" role="status">Loading offseason transactions…</div>
    <div v-else-if="error" class="transactions-state is-error" role="alert">{{ error }} <button type="button" @click="load">Try again</button></div>
    <template v-else>
      <div class="transactions-toolbar">
        <label for="transactions-search">Search players or descriptions</label>
        <input id="transactions-search" v-model="search" type="search" placeholder="Search transactions" />
        <label for="transactions-type">Type</label>
        <select id="transactions-type" v-model="type">
          <option value="all">All moves</option>
          <option value="Trade">Trades</option>
          <option value="Signing">Signings</option>
        </select>
        <span>{{ transactions.length }} {{ transactions.length === 1 ? 'move' : 'moves' }}</span>
      </div>

      <section class="transactions-card" aria-labelledby="transactions-heading">
        <header><p class="transactions-eyebrow">The transaction wire</p><h2 id="transactions-heading">Recent moves</h2></header>
        <div class="transactions-table-wrap">
          <table>
            <thead><tr><th scope="col">Date</th><th scope="col">Type</th><th scope="col">Player</th><th scope="col">Transaction</th></tr></thead>
            <tbody>
              <tr v-for="move in transactions" :key="move.id">
                <td class="transactions-date">{{ formatDate(move.date) }}</td>
                <td><span class="transactions-type" :class="{ 'is-signing': move.type === 'Signing' }">{{ move.type }}</span></td>
                <th scope="row"><RouterLink v-if="move.player_id" :to="{ name: 'player-profile', params: { id: move.player_id } }">{{ move.player_name }}</RouterLink><span v-else>{{ move.player_name || 'League move' }}</span></th>
                <td class="transactions-description">{{ move.description }}</td>
              </tr>
              <tr v-if="!transactions.length"><td colspan="4" class="transactions-empty">{{ search || type !== 'all' ? 'No moves match these filters.' : 'No offseason moves are stored yet.' }}</td></tr>
            </tbody>
          </table>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.transactions-page { max-width: 1500px; margin: 0 auto; padding: clamp(1.25rem, 3vw, 3rem); color: #10263d; }
.transactions-hero { margin: 0 0 2rem; }
.transactions-back { color: #34556a; font-weight: 800; text-decoration: none; font-size: .9rem; }
.transactions-back:hover, .transactions-card a:hover { text-decoration: underline; }
.transactions-eyebrow { margin: 1.8rem 0 .35rem; color: #a73629; font-weight: 900; letter-spacing: .17em; text-transform: uppercase; font-size: .78rem; }
.transactions-hero h1 { margin: 0; font-size: clamp(2.6rem, 5vw, 5rem); line-height: 1; text-transform: uppercase; letter-spacing: -.04em; }
.transactions-subtitle { max-width: 70ch; color: #576b78; font-size: 1rem; }
.transactions-toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: .75rem 1rem; margin-bottom: 1.5rem; color: #536674; font-size: .85rem; font-weight: 700; }
.transactions-toolbar input, .transactions-toolbar select { padding: .7rem .85rem; border: 1px solid #c8d2d6; border-radius: .65rem; background: #fff; color: #10263d; font: inherit; }
.transactions-toolbar input { min-width: min(100%, 20rem); }
.transactions-toolbar span { margin-left: auto; }
.transactions-card { padding: clamp(1rem, 2vw, 1.6rem); border: 1px solid #ddd9ce; border-radius: 1.35rem; background: #fff; }
.transactions-card header { margin-bottom: 1rem; }
.transactions-card .transactions-eyebrow { margin: 0 0 .2rem; }
.transactions-card h2 { margin: 0; font-size: clamp(1.4rem, 2vw, 2rem); }
.transactions-table-wrap { overflow-x: auto; }
.transactions-card table { width: 100%; min-width: 720px; border-collapse: collapse; }
.transactions-card th, .transactions-card td { padding: .85rem .7rem; border-bottom: 1px solid #e8e6df; text-align: left; vertical-align: top; font-size: .84rem; }
.transactions-card thead th { color: #63727d; font-size: .71rem; text-transform: uppercase; letter-spacing: .06em; }
.transactions-card tbody tr:last-child th, .transactions-card tbody tr:last-child td { border-bottom: 0; }
.transactions-card tbody tr:hover { background: #f6f8f8; }
.transactions-card a { color: #10263d; font-weight: 900; text-decoration: none; }
.transactions-date { white-space: nowrap; color: #526674; font-weight: 700; }
.transactions-type { display: inline-block; border-radius: 999px; padding: .2rem .55rem; background: #e8eef1; color: #183e5b; font-size: .72rem; font-weight: 900; }
.transactions-type.is-signing { background: #f7e9dc; color: #9b421c; }
.transactions-description { width: 55%; color: #526674; line-height: 1.45; }
.transactions-empty { padding: 1.5rem !important; text-align: center !important; color: #63727d; }
.transactions-state { padding: 2rem; border-radius: 1rem; background: #fff; color: #536674; }
.transactions-state.is-error { color: #9f3027; }
.transactions-state button { margin-left: .5rem; cursor: pointer; }
@media (max-width: 650px) { .transactions-toolbar > span { width: 100%; margin-left: 0; } }
</style>
