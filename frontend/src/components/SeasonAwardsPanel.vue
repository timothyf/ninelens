<script setup>
import { ref, watch } from 'vue'
import { API_BASE_URL } from '../config'

const props = defineProps({ season: { type: Number, default: null } })
const data = ref(null)
const loading = ref(false)
const error = ref('')
let requestId = 0

async function load() {
  const currentRequest = ++requestId
  if (!props.season) return
  loading.value = true
  error.value = ''
  data.value = null
  try {
    const response = await fetch(`${API_BASE_URL}/api/season_review/awards?season=${encodeURIComponent(props.season)}`, {
      headers: { Accept: 'application/json' },
    })
    if (!response.ok) throw new Error(`Request failed with status ${response.status}`)
    const payload = await response.json()
    if (currentRequest === requestId) data.value = payload.data
  } catch (fetchError) {
    if (currentRequest !== requestId) return
    error.value = 'Award winners could not be loaded right now.'
    console.error(fetchError)
  } finally {
    if (currentRequest === requestId) loading.value = false
  }
}

watch(() => props.season, load, { immediate: true })
</script>

<template>
  <section class="awards-panel" aria-label="Season awards">
    <header class="awards-heading">
      <div><p>Around the league</p><h2>{{ season }} award winners</h2></div>
      <span>Official MLB awards</span>
    </header>

    <div v-if="loading" class="awards-state" role="status">Loading award winners…</div>
    <div v-else-if="error" class="awards-state awards-state--error">{{ error }}</div>
    <div v-else-if="data?.status === 'unavailable'" class="awards-state awards-state--error">Award winners are temporarily unavailable. Check back shortly.</div>
    <div v-else-if="data?.status === 'pending'" class="awards-state">No award winners have been announced for this season yet.</div>
    <div v-else-if="data?.status === 'empty'" class="awards-state">No official award records are available for this season.</div>
    <template v-else-if="data">
      <p v-if="data.status === 'stale'" class="awards-stale">Showing stored winners while MLB award data is temporarily unavailable.</p>
      <div class="award-grid">
        <article v-for="group in data.groups" :key="group.name" class="award-card">
          <header><p>{{ group.name }}</p><span>{{ group.name === 'Gold Glove' ? 'Fielding excellence' : 'League honors' }}</span></header>
          <div class="award-leagues">
            <section v-for="league in group.leagues" :key="league.name">
              <h3>{{ league.name === 'AL' ? 'American League' : 'National League' }}</h3>
              <ul v-if="league.recipients.length">
                <li v-for="winner in league.recipients" :key="`${winner.player_name}-${winner.position}`">
                  <RouterLink v-if="winner.player_id" :to="{ name: 'player-profile', params: { id: winner.player_id } }">{{ winner.player_name }}</RouterLink>
                  <strong v-else>{{ winner.player_name }}</strong>
                  <small>{{ [winner.position, winner.team_abbreviation].filter(Boolean).join(' · ') }}</small>
                </li>
              </ul>
              <p v-else class="award-empty">No winner announced</p>
            </section>
          </div>
        </article>
      </div>
    </template>
  </section>
</template>

<style scoped>
.awards-panel{margin-top:1.2rem;color:#10263d}.awards-heading{display:flex;justify-content:space-between;align-items:end;gap:1rem;margin:0 .2rem .75rem}.awards-heading p{color:#a93627;font-size:.7rem;font-weight:900;letter-spacing:.15em;text-transform:uppercase}.awards-heading h2{margin:.25rem 0;font-family:'Avenir Next Condensed',sans-serif;font-size:clamp(1.8rem,4vw,2.6rem);line-height:1;text-transform:uppercase}.awards-heading>span{color:#697680;font-size:.72rem}.awards-state{padding:1.5rem;border:1px solid #d9d7ce;border-radius:18px;color:#697680;background:rgba(255,250,240,.76)}.awards-state--error{color:#8f2d24}.awards-stale{margin:0 0 .7rem;color:#8f2d24;font-size:.72rem}.award-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:.9rem}.award-card{min-width:0;overflow:hidden;border:1px solid #d9d7ce;border-radius:20px;background:rgba(255,255,255,.76)}.award-card:last-child{grid-column:1/-1}.award-card>header{display:flex;align-items:baseline;justify-content:space-between;gap:1rem;padding:1rem 1.2rem;color:#fffaf0;background:#10263d}.award-card>header p{font-family:'Avenir Next Condensed',sans-serif;font-size:1.5rem;font-weight:900;text-transform:uppercase}.award-card>header span{color:#c5d1d9;font-size:.67rem}.award-leagues{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:1rem;padding:1.1rem}.award-leagues h3{padding-bottom:.5rem;border-bottom:1px solid #d9d7ce;color:#a93627;font-size:.67rem;font-weight:900;letter-spacing:.1em;text-transform:uppercase}.award-leagues ul{display:grid;gap:.4rem;margin:.7rem 0 0;padding:0;list-style:none}.award-leagues li{display:flex;justify-content:space-between;align-items:baseline;gap:.5rem;font-size:.8rem}.award-leagues a,.award-leagues strong{color:#10263d;font-weight:800;text-decoration:none}.award-leagues a:hover{text-decoration:underline}.award-leagues small{color:#697680;font-size:.65rem;white-space:nowrap}.award-empty{margin:.8rem 0;color:#748089;font-size:.73rem}@media(max-width:700px){.award-grid{grid-template-columns:1fr}.award-card:last-child{grid-column:auto}.awards-heading{align-items:flex-start;flex-direction:column;gap:.2rem}}@media(max-width:480px){.award-leagues{grid-template-columns:1fr}}
</style>
