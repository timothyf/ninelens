<script setup>
import AdminTaskCard from './AdminTaskCard.vue'
import AdminSyncProgress from './AdminSyncProgress.vue'

defineProps({
  profileOptions: { type: Object, required: true },
  teamHistoryOptions: { type: Object, required: true },
  anyActionRunning: { type: Boolean, default: false },
  runningTask: { type: String, default: '' },
  teamHistoryTask: { type: Object, default: null },
  teamHistoryActive: { type: Boolean, default: false },
  teamHistoryError: { type: String, default: '' },
})
const emit = defineEmits(['sync-profiles', 'sync-team-histories', 'cancel-team-histories'])
</script>

<template>
  <AdminTaskCard
    data-test="profile-sync-form"
    source="Player identity"
    title="MLB profile synchronization"
    command="mlb_player_profiles:sync"
    description="Downloads MLB biographical, handedness, position, and headshot information for players already stored in NineLens."
    @submit.prevent="emit('sync-profiles')"
  >
    <div class="admin-fields admin-fields--four">
      <label><span>Batch size</span><input v-model.number="profileOptions.batchSize" type="number" min="1" max="100" required /></label>
      <label><span>Limit (optional)</span><input v-model="profileOptions.limit" type="number" min="1" /></label>
      <label class="admin-field--wide"><span>MLB IDs (optional)</span><input v-model="profileOptions.mlbIds" type="text" placeholder="700270, 669360" /></label>
      <label class="admin-check"><input v-model="profileOptions.onlyMissing" type="checkbox" /><span>Only missing</span></label>
    </div>
    <button class="admin-button" type="submit" :disabled="anyActionRunning">
      {{ runningTask === 'mlb_player_profiles_sync' ? 'Synchronizing profiles…' : 'Synchronize player profiles' }}
    </button>
  </AdminTaskCard>

  <AdminTaskCard
    data-test="team-history-sync-form"
    source="Player organization trail"
    title="MLB transaction history synchronization"
    command="mlb_player_team_histories:sync"
    description="Downloads official MLB transactions and rebuilds dated major-league organization tenures. Choose a season to include players with stats, roster membership, or an organization change in that year; other years are preserved."
    @submit.prevent="emit('sync-team-histories')"
  >
    <div class="admin-fields admin-fields--three">
      <label><span>Season (optional)</span><input v-model="teamHistoryOptions.season" type="number" min="1900" :max="new Date().getFullYear()" placeholder="All history" /></label>
      <label><span>Limit (optional)</span><input v-model="teamHistoryOptions.limit" type="number" min="1" /></label>
      <label><span>MLB IDs (optional)</span><input v-model="teamHistoryOptions.mlbIds" type="text" placeholder="656427, 669360" /></label>
    </div>
    <button class="admin-button" type="submit" :disabled="anyActionRunning">
      {{ runningTask === 'mlb_player_team_histories_sync' ? 'Synchronizing team histories…' : 'Synchronize team histories' }}
    </button>
    <AdminSyncProgress
      v-if="teamHistoryTask"
      :task="teamHistoryTask"
      :active="teamHistoryActive"
      test-id="team-history-sync-progress"
      aria-label="MLB transaction history synchronization"
      item-noun="players"
      current-item-label="Current player"
      cancel-item-noun="player"
      @cancel="emit('cancel-team-histories')"
    />
    <p v-if="teamHistoryError" class="admin-message admin-message--error" role="alert">{{ teamHistoryError }}</p>
  </AdminTaskCard>
</template>
