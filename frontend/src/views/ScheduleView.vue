<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import GameScheduleCard from '../components/GameScheduleCard.vue'
import { useSchedule } from '../composables/useSchedule'

const route = useRoute()
const router = useRouter()
const selectedDate = computed(() => validIsoDate(route.query.date) || localIsoDate(new Date()))
const { games, loading, error, refresh } = useSchedule(selectedDate)

const headingDate = computed(() => new Intl.DateTimeFormat('en-US', {
  weekday: 'long',
  month: 'long',
  day: 'numeric',
  year: 'numeric',
}).format(dateFromIso(selectedDate.value)))

function validIsoDate(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(value || ''))) return null
  const date = dateFromIso(value)
  return localIsoDate(date) === value ? value : null
}

function dateFromIso(value) {
  return new Date(`${value}T12:00:00`)
}

function localIsoDate(date) {
  return [date.getFullYear(), String(date.getMonth() + 1).padStart(2, '0'), String(date.getDate()).padStart(2, '0')].join('-')
}

function selectDate(value) {
  const date = validIsoDate(value)
  if (date) router.push({ name: 'schedule', query: { date } })
}

function shiftDate(days) {
  const date = dateFromIso(selectedDate.value)
  date.setDate(date.getDate() + days)
  selectDate(localIsoDate(date))
}

function showToday() {
  selectDate(localIsoDate(new Date()))
}
</script>

<template>
  <main class="schedule-shell">
    <section class="schedule-hero">
      <div>
        <p class="schedule-eyebrow">MLB schedule</p>
        <h1>Games around the league</h1>
        <p>Browse every stored matchup by date, then open a game or team for deeper detail.</p>
      </div>
      <div class="schedule-date" data-test="schedule-date-controls">
        <button type="button" data-test="schedule-previous" aria-label="Previous day" @click="shiftDate(-1)">←</button>
        <label>
          <span>Schedule date</span>
          <input :value="selectedDate" data-test="schedule-date-input" type="date" @change="selectDate($event.target.value)" />
        </label>
        <button type="button" data-test="schedule-next" aria-label="Next day" @click="shiftDate(1)">→</button>
        <button type="button" class="schedule-date__today" data-test="schedule-today" @click="showToday">Today</button>
      </div>
    </section>

    <section class="schedule-panel" data-test="schedule-games">
      <header>
        <div><p class="schedule-eyebrow">Daily slate</p><h2>{{ headingDate }}</h2></div>
        <span>{{ games.length }} {{ games.length === 1 ? 'game' : 'games' }}</span>
      </header>

      <div v-if="loading" class="schedule-state" data-test="schedule-loading">Loading the day’s games…</div>
      <div v-else-if="error" class="schedule-state schedule-state--error" data-test="schedule-error">
        <p>{{ error }}</p>
        <button type="button" @click="refresh">Try again</button>
      </div>
      <div v-else-if="games.length" class="schedule-grid">
        <GameScheduleCard v-for="game in games" :key="game.id" :game="game" />
      </div>
      <p v-else class="schedule-empty">No games are scheduled for {{ headingDate }}.</p>
    </section>
  </main>
</template>

<style scoped>
.schedule-shell { width: min(1440px, calc(100% - 2.5rem)); margin: 0 auto; padding: 2.4rem 0 5rem; color: #10263d; }
.schedule-hero { display: flex; justify-content: space-between; gap: 2rem; align-items: end; padding: clamp(1.4rem, 4vw, 2.4rem); border-radius: 28px; color: #fffaf0; background: linear-gradient(125deg, #10263d 0%, #183e5b 65%, #8f2d24 150%); box-shadow: 0 24px 70px rgba(16,38,61,.18); }
.schedule-eyebrow { margin: 0; color: #a93627; font-size: .71rem; font-weight: 900; letter-spacing: .16em; text-transform: uppercase; }
.schedule-hero .schedule-eyebrow { color: #e8b276; }
.schedule-hero h1 { margin: .35rem 0 .55rem; font-family: 'Avenir Next Condensed', sans-serif; font-size: clamp(2.7rem, 6vw, 5.2rem); line-height: .9; text-transform: uppercase; }
.schedule-hero > div:first-child > p:last-child { max-width: 670px; color: #d8e1e7; line-height: 1.5; }
.schedule-date { display: grid; grid-template-columns: auto minmax(150px, 1fr) auto; gap: .5rem; align-items: end; min-width: min(100%, 390px); }
.schedule-date label { display: grid; gap: .3rem; }
.schedule-date label span { color: #e8b276; font-size: .65rem; font-weight: 900; letter-spacing: .1em; text-transform: uppercase; }
.schedule-date input,.schedule-date button { min-height: 44px; border: 1px solid rgba(255,255,255,.22); border-radius: 11px; color: #fffaf0; background: rgba(255,255,255,.1); font: inherit; font-weight: 850; }
.schedule-date input { padding: .55rem .7rem; color-scheme: dark; }
.schedule-date button { min-width: 44px; cursor: pointer; }
.schedule-date__today { grid-column: 1 / -1; }
.schedule-panel { margin-top: 1.25rem; padding: clamp(1.1rem, 3vw, 1.65rem); border: 1px solid rgba(16,38,61,.1); border-radius: 25px; background: rgba(255,252,245,.86); box-shadow: 0 14px 38px rgba(73,52,24,.065); }
.schedule-panel > header { display: flex; justify-content: space-between; gap: 1rem; align-items: end; margin-bottom: 1rem; }
.schedule-panel h2 { margin-top: .2rem; font-family: 'Avenir Next Condensed', sans-serif; font-size: clamp(1.8rem, 4vw, 2.7rem); line-height: 1; text-transform: uppercase; }
.schedule-panel > header > span { color: #62707a; font-size: .77rem; font-weight: 800; }
.schedule-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(275px, 1fr)); gap: .8rem; }
.schedule-state,.schedule-empty { padding: 1.5rem; border-radius: 16px; color: #64717a; background: rgba(231,237,241,.65); text-align: center; }
.schedule-state--error { color: #8f2d24; }
.schedule-state--error button { margin-top: .75rem; padding: .6rem .9rem; border: 0; border-radius: 10px; color: white; background: #10263d; font-weight: 800; }
@media (max-width: 760px) { .schedule-shell { width: calc(100% - 1.4rem); padding-top: 1rem; } .schedule-hero { align-items: stretch; flex-direction: column; } .schedule-date { min-width: 0; } }
</style>
