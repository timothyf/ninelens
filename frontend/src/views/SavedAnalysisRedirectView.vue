<script setup>
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import { authRequestHeaders } from '../composables/apiAuth'
import { apiUrl } from '../config'

const props = defineProps({ savedAnalysisId: { type: [String, Number], required: true } })
const router = useRouter()
const error = ref('')

onMounted(async () => {
  try {
    const response = await fetch(apiUrl(`/api/saved_analyses/${encodeURIComponent(props.savedAnalysisId)}`), {
      headers: authRequestHeaders({ Accept: 'application/json' }),
    })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(payload.message || 'Unable to open this saved analysis.')
    await router.replace(payload.data.reproducible_url)
  } catch (requestError) {
    error.value = requestError.message
  }
})
</script>

<template>
  <main class="saved-analysis-redirect">
    <p v-if="error" role="alert">{{ error }}</p>
    <p v-else>Opening saved analysis…</p>
  </main>
</template>

<style scoped>
.saved-analysis-redirect { min-height: calc(100vh - 80px); padding: 4rem 1rem; color: #173652; text-align: center; }
.saved-analysis-redirect [role="alert"] { color: #922e25; }
</style>
