<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useSeasonReview } from '../composables/useSeasonReview'
import SeasonAwardsPanel from '../components/SeasonAwardsPanel.vue'

const route = useRoute()
const router = useRouter()
const requestedSeason = computed(() => {
  const value = Number(route.query.season)
  return Number.isInteger(value) && value > 1800 ? value : null
})
const { review, loading, error, refresh } = useSeasonReview(requestedSeason)
const season = computed(() => requestedSeason.value || review.value.season)
const statCards = computed(() => [
  { label: 'Regular season games', value: review.value.games, mark: 'G' },
  { label: 'Hits', value: review.value.totals.hits, mark: 'H' },
  { label: 'Strikeouts', value: review.value.totals.strikeouts, mark: 'K' },
  { label: 'Walks', value: review.value.totals.walks, mark: 'BB' },
  { label: 'Home runs', value: review.value.totals.home_runs, mark: 'HR' },
  { label: 'Triples', value: review.value.totals.triples, mark: '3B' },
  { label: 'Shutouts', value: review.value.shutouts, mark: 'SO' },
  { label: 'One-run games', value: review.value.one_run_games, mark: '1R' },
  { label: 'Complete games', value: review.value.complete_games, mark: 'CG' },
])

function selectSeason(value) {
  router.push({ name: 'season-review', query: { ...route.query, season: value } })
}

function number(value) {
  return Number(value || 0).toLocaleString('en-US')
}

function leaderValue(category, value) {
  if (category === 'Batting average' || category === 'OPS') return Number(value).toFixed(3).replace(/^0/, '')
  if (category === 'WAR') return Number(value).toFixed(1)
  if (category === 'ERA') return Number(value).toFixed(2)
  return number(value)
}

function eventLabel(event) {
  return event ? event.replaceAll('_', ' ') : 'Batted ball'
}
</script>

<template>
  <main class="review-shell">
    <section class="review-hero">
      <div class="hero-copy"><p class="eyebrow">The year in baseball</p><h1>Season<br><em>in review.</em></h1><p class="intro">A whole summer, distilled. The numbers, the names, and the moments that made {{ season || 'the season' }}.</p></div>
      <div class="season-control"><span class="eyebrow">Explore a season</span><label for="season-picker">Season</label><select id="season-picker" :value="season" :disabled="loading" @change="selectSeason($event.target.value)"><option v-for="year in review.available_seasons" :key="year" :value="year">{{ year }}</option></select><small>{{ loading ? 'Opening the record book…' : 'Choose a year to open its record book' }}</small></div>
      <div class="hero-stamp" aria-hidden="true"><span>MLB</span><strong>{{ season || '—' }}</strong><small>EST. 1876</small></div>
    </section>

    <div v-if="loading" class="review-state review-state--loading" role="status" aria-live="polite"><span class="review-spinner" aria-hidden="true"></span><span>Loading {{ season ? `${season} season review` : 'season review' }}…</span></div>
    <div v-else-if="error" class="review-state is-error"><p>{{ error }}</p><button @click="refresh">Try again</button></div>
    <template v-else>
      <section class="stats-section"><header class="section-heading"><div><p class="eyebrow">By the numbers</p><h2>{{ season }} at a glance</h2></div><span>Regular season totals</span></header>
        <div class="stat-grid"><article v-for="(stat, index) in statCards" :key="stat.label" class="stat-card" :class="`tone-${index % 4}`"><span class="stat-mark">{{ stat.mark }}</span><strong>{{ number(stat.value) }}</strong><span>{{ stat.label }}</span></article></div>
      </section>

      <div class="detail-grid">
        <div class="velocity-column">
          <section class="paper-card speed-card"><header><div><p class="eyebrow">Heat check</p><h2>Fastest pitches</h2></div><span class="card-icon">↗</span></header><p class="card-note">The hardest-thrown pitches recorded this season.</p><ol v-if="review.fastest_pitches.length"><li v-for="(pitch, index) in review.fastest_pitches" :key="`${pitch.player}-${pitch.date}-${index}`"><span class="rank">{{ String(index + 1).padStart(2, '0') }}</span><span class="pitcher">{{ pitch.player || 'Unknown pitcher' }}<small>{{ pitch.pitch || 'Pitch' }} · {{ pitch.date }}</small></span><strong>{{ Number(pitch.speed).toFixed(1) }}<small>mph</small></strong></li></ol><div v-else class="empty-note">Pitch tracking data is not available for this season.</div></section>
          <section class="paper-card speed-card exit-card"><header><div><p class="eyebrow">Off the bat</p><h2>Top exit velocities</h2></div><span class="card-icon">↗</span></header><p class="card-note">The 8 hardest-hit balls recorded this season.</p><ol v-if="review.top_exit_velocities.length"><li v-for="(ball, index) in review.top_exit_velocities" :key="`${ball.player}-${ball.date}-${index}`"><span class="rank">{{ String(index + 1).padStart(2, '0') }}</span><span class="pitcher">{{ ball.player || 'Unknown batter' }}<small>{{ eventLabel(ball.event) }} · {{ ball.date }}</small></span><strong>{{ Number(ball.speed).toFixed(1) }}<small>mph</small></strong></li></ol><div v-else class="empty-note">Batted-ball tracking data is not available for this season.</div></section>
          <section class="paper-card speed-card distance-card"><header><div><p class="eyebrow">Going deep</p><h2>Longest balls hit</h2></div><span class="card-icon">↗</span></header><p class="card-note">The 8 longest batted balls recorded this season.</p><ol v-if="review.longest_balls.length"><li v-for="(ball, index) in review.longest_balls" :key="`${ball.player}-${ball.date}-${index}`"><span class="rank">{{ String(index + 1).padStart(2, '0') }}</span><span class="pitcher">{{ ball.player || 'Unknown batter' }}<small>{{ eventLabel(ball.event) }} · {{ ball.date }}</small></span><strong>{{ Math.round(Number(ball.distance)) }}<small>ft</small></strong></li></ol><div v-else class="empty-note">Batted-ball distance data is not available for this season.</div></section>
        </div>
        <section class="paper-card leaders-card"><header><div><p class="eyebrow">The record holders</p><h2>Season leaders</h2></div><span class="card-icon">✳</span></header><p class="card-note">Top five in selected counting and rate stats.</p><div v-for="leader in review.leaders" :key="leader.category" class="leader-group"><h3>{{ leader.category }} <small v-if="leader.qualifier">{{ leader.qualifier }}</small></h3><ol><li v-for="(entry, index) in leader.entries" :key="entry.player"><span>{{ index + 1 }}</span><strong>{{ entry.player }}</strong><small>{{ entry.team || 'MLB' }}</small><b>{{ leaderValue(leader.category, entry.value) }}</b></li></ol><p v-if="!leader.entries.length" class="empty-note">{{ leader.qualifier ? 'No qualified leaders are available.' : 'No leader data stored.' }}</p></div></section>
      </div>

      <section class="postseason-card paper-card"><header><div><p class="eyebrow">October baseball</p><h2>Postseason field</h2></div><RouterLink :to="{ name: 'postseason', query: { season: String(season) } }">Series details ↗</RouterLink></header><div v-if="review.postseason_teams.length" class="playoff-teams"><span v-for="team in review.postseason_teams" :key="team.id">{{ team.abbreviation }} <small>{{ team.wins }} wins</small></span></div><p v-else class="empty-note">Postseason results are not stored for this season.</p><div v-if="review.world_series.teams.length" class="world-series"><span>WORLD SERIES</span><strong>{{ review.world_series.champion || 'In progress' }}</strong><small>vs. {{ review.world_series.teams.filter((name) => name !== review.world_series.champion).join(' · ') }}</small></div></section>
      <SeasonAwardsPanel :season="season" />
    </template>
  </main>
</template>

<style scoped>
.review-shell{width:min(1440px,calc(100% - 2.5rem));margin:0 auto;padding:2.4rem 0 5rem;color:#10263d}
.review-hero{position:relative;display:flex;justify-content:space-between;gap:2rem;align-items:end;overflow:hidden;padding:clamp(1.5rem,4vw,2.6rem);border-radius:30px;color:#fffaf0;background:linear-gradient(125deg,#10263d,#183e5b 65%,#8f2d24 150%);box-shadow:0 24px 70px rgba(16,38,61,.18)}
.review-hero>div:first-child{max-width:760px}.eyebrow{color:#e8b276;font-size:.7rem;font-weight:900;letter-spacing:.15em;text-transform:uppercase}
.hero-copy h1{margin:.3rem 0 .75rem;color:#fffaf0;font-family:'Avenir Next Condensed',sans-serif;font-size:clamp(3.4rem,7vw,6rem);line-height:.88;text-transform:uppercase}.hero-copy h1 em{color:inherit;font-style:normal}.intro{max-width:580px;color:#d4dee5;line-height:1.55}
.season-control{display:grid;gap:.45rem;min-width:190px;padding:1rem 1.1rem;border:1px solid rgba(255,255,255,.2);border-radius:14px;background:rgba(16,38,61,.32)}.season-control .eyebrow{color:#e8b276}.season-control label{color:#d4dee5;font-size:.65rem;font-weight:900;letter-spacing:.1em;text-transform:uppercase}.season-control select{padding:.7rem .8rem;border:1px solid rgba(255,255,255,.25);border-radius:10px;color:#fffaf0;background:#183e5b;font:inherit;font-weight:850}.season-control small{color:#bdcbd4;font-size:.65rem}
.hero-stamp{position:absolute;right:285px;top:22px;display:grid;justify-items:center;align-content:center;width:78px;height:78px;border:1px solid #e8b276;border-radius:50%;color:#e8b276;opacity:.72;transform:rotate(9deg)}.hero-stamp span,.hero-stamp small{font-size:.48rem;letter-spacing:.15em}.hero-stamp strong{font-family:'Avenir Next Condensed',sans-serif;font-size:1.35rem}
.stats-section{padding:2rem 0 1.5rem}.section-heading,.paper-card header{display:flex;justify-content:space-between;align-items:end;gap:1rem}.section-heading h2,.paper-card h2{margin:.25rem 0;font-family:'Avenir Next Condensed',sans-serif;font-size:clamp(1.8rem,4vw,2.6rem);line-height:1;text-transform:uppercase}.section-heading .eyebrow,.paper-card .eyebrow{color:#a93627}.section-heading>span{color:#697680;font-size:.72rem}
.stat-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:.8rem}.stat-card{position:relative;display:grid;gap:.4rem;min-height:132px;align-content:end;padding:1.1rem 1.2rem;overflow:hidden;border:1px solid #d9d7ce;border-radius:17px;background:rgba(255,250,240,.8)}.stat-card:before{position:absolute;inset:0 0 auto;height:4px;background:#183e5b;content:''}.tone-1:before{background:#e8b276}.tone-2:before{background:#a93627}.tone-3:before{background:#59798d}.stat-mark{position:absolute;right:1rem;top:.8rem;color:#89949b;font-size:.62rem;font-weight:900;letter-spacing:.1em}.stat-card strong{font-family:'Avenir Next Condensed',sans-serif;font-size:clamp(2rem,4vw,3rem);line-height:1;font-variant-numeric:tabular-nums}.stat-card>span:last-child{color:#697680;font-size:.72rem;font-weight:700}
.detail-grid{display:grid;grid-template-columns:1fr 1fr;gap:.9rem}.velocity-column{display:grid;align-content:start;gap:.9rem;min-width:0}.paper-card{min-width:0;padding:1.25rem;border:1px solid #d9d7ce;border-radius:20px;background:rgba(255,255,255,.76)}.card-icon{display:grid;place-items:center;width:35px;height:35px;border-radius:12px;color:#fffaf0;background:#183e5b;font-size:1rem}.card-note{margin:.5rem 0 1rem;color:#697680;font-size:.75rem}.paper-card ol{list-style:none;padding:0;margin:0}.speed-card li{display:grid;grid-template-columns:34px 1fr auto;gap:.65rem;align-items:center;padding:.65rem 0;border-bottom:1px solid #ebe8df}.rank{color:#a93627;font-size:.72rem;font-weight:900}.pitcher{font-size:.82rem;font-weight:800}.pitcher small{display:block;margin-top:.2rem;color:#748089;font-size:.65rem;font-weight:500}.speed-card li>strong{font-family:'Avenir Next Condensed',sans-serif;font-size:1.35rem}.speed-card li>strong small{margin-left:.25rem;color:#748089;font-family:inherit;font-size:.6rem}.leader-group{margin-top:1rem}.leader-group h3{padding-bottom:.4rem;border-bottom:1px solid #d9d7ce;color:#a93627;font-size:.64rem;letter-spacing:.12em;text-transform:uppercase}.leader-group li{display:grid;grid-template-columns:22px 1fr 42px 54px;gap:.45rem;align-items:center;padding:.35rem 0;font-size:.72rem}.leader-group li>span,.leader-group li>small{color:#748089}.leader-group li>b{text-align:right;font-variant-numeric:tabular-nums}.empty-note{padding:.9rem;color:#748089;font-size:.75rem}
.postseason-card{margin-top:.9rem}.postseason-card header a{color:#183e5b;font-size:.7rem;font-weight:850;text-decoration:none}.playoff-teams{display:flex;flex-wrap:wrap;gap:.45rem;margin-top:1rem}.playoff-teams span{padding:.5rem .7rem;border:1px solid #d9d7ce;border-radius:10px;color:#10263d;background:#fffaf0;font-size:.72rem;font-weight:900}.playoff-teams small{margin-left:.35rem;color:#697680;font-weight:600}.world-series{display:flex;gap:.8rem;align-items:baseline;flex-wrap:wrap;margin-top:1rem;padding-top:1rem;border-top:1px solid #ebe8df}.world-series span{color:#a93627;font-size:.62rem;font-weight:900;letter-spacing:.13em}.world-series strong{font-family:'Avenir Next Condensed',sans-serif;font-size:1.3rem;text-transform:uppercase}.world-series small{color:#697680}.review-state{padding:2rem;border:1px solid #d9d7ce;border-radius:18px;color:#697680;background:rgba(255,250,240,.76);text-align:center}.is-error{color:#8f2d24}.review-state button{margin-top:.6rem;padding:.6rem .9rem;border:0;border-radius:9px;color:white;background:#10263d;font:inherit;font-weight:800}
.leader-group h3 small{float:right;color:#697680;font-size:.6rem;font-weight:800;letter-spacing:0;text-transform:none}
.review-state--loading{display:flex;align-items:center;justify-content:center;gap:.8rem;min-height:180px;margin-top:1rem;color:#10263d;font-weight:800}.review-spinner{width:22px;height:22px;border:3px solid #d9d7ce;border-top-color:#a93627;border-radius:50%;animation:review-spin .8s linear infinite}@keyframes review-spin{to{transform:rotate(360deg)}}@media(prefers-reduced-motion:reduce){.review-spinner{animation:none;border-top-color:#a93627}}
@media(max-width:900px){.hero-stamp{display:none}.stat-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.detail-grid{grid-template-columns:1fr}}
@media(max-width:650px){.review-shell{width:calc(100% - 1.4rem);padding-top:1rem}.review-hero{align-items:stretch;flex-direction:column;padding:1.4rem;border-radius:22px}.season-control{max-width:100%}.section-heading{align-items:flex-start;flex-direction:column;gap:.3rem}.stat-card{min-height:112px;padding:.9rem}.paper-card{padding:1rem}.hero-copy h1{font-size:3.6rem}}
</style>
