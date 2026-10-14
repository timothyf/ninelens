<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { useAuth } from '../composables/useAuth'

const route = useRoute()
const router = useRouter()
const { changePassword, loading, error } = useAuth()
const currentPassword = ref('')
const password = ref('')
const passwordConfirmation = ref('')

async function submit() {
  try {
    await changePassword(currentPassword.value, password.value, passwordConfirmation.value)
    await router.replace(returnDestination())
  } catch (_error) {}
}

function returnDestination() {
  const destination = route.query.redirect
  if (
    typeof destination === 'string'
    && destination.startsWith('/')
    && !destination.startsWith('//')
    && !destination.startsWith('/login')
    && !destination.startsWith('/change-password')
  ) {
    return destination
  }

  return { name: 'home' }
}
</script>

<template>
  <main class="password-shell">
    <section class="password-card">
      <p class="eyebrow">Secure your account</p>
      <h1>Choose a new password</h1>
      <p>Your temporary password must be replaced before you can continue.</p>
      <form @submit.prevent="submit">
        <label>Temporary password<input v-model="currentPassword" required type="password" autocomplete="current-password" /></label>
        <label>New password<input v-model="password" required minlength="8" type="password" autocomplete="new-password" /></label>
        <label>Confirm new password<input v-model="passwordConfirmation" required minlength="8" type="password" autocomplete="new-password" /></label>
        <p v-if="error" class="password-error" role="alert">{{ error }}</p>
        <button type="submit" :disabled="loading">{{ loading ? 'Updating…' : 'Set new password' }}</button>
      </form>
    </section>
  </main>
</template>

<style scoped>
.password-shell { min-height: calc(100vh - 74px); display: grid; place-items: center; padding: 2rem; background: linear-gradient(145deg,#f7f1e3,#ead8b6); color: #10263d; }.password-card { width: min(440px,100%); padding: 2rem; border: 1px solid rgba(16,38,61,.14); border-radius: 24px; background: rgba(255,252,244,.92); box-shadow: 0 20px 50px rgba(64,43,20,.12); }.eyebrow { color: #b79569; font-size: .68rem; font-weight: 900; letter-spacing: .12em; text-transform: uppercase; }.password-card h1 { margin: .3rem 0; font-family: 'Avenir Next Condensed',sans-serif; font-size: 2.6rem; text-transform: uppercase; }.password-card > p:not(.eyebrow) { color: #71808c; font-size: .8rem; }.password-card form { display: grid; gap: .7rem; margin-top: 1.2rem; }.password-card label { display: grid; gap: .25rem; color: #697784; font-size: .67rem; font-weight: 900; text-transform: uppercase; }.password-card input { padding: .65rem; border: 1px solid rgba(16,38,61,.16); border-radius: 9px; background: #fffdf7; font: inherit; }.password-card form button { padding: .7rem; border: 0; border-radius: 9px; color: #fffaf0; background: #20543c; font-weight: 900; }.password-card button:disabled { opacity: .5; }.password-error { margin: 0; color: #8f2d24; font-size: .76rem; }
</style>
