<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { useAuth } from '../composables/useAuth'

const router = useRouter()
const route = useRoute()
const { login, register, loading, error } = useAuth()
const anonymousRegistrationEnabled = !import.meta.env.PROD
const mode = ref('login')
const name = ref('')
const email = ref('')
const password = ref('')

async function submit() {
  try {
    const session = mode.value === 'register'
      ? await register(name.value, email.value, password.value)
      : await login(email.value, password.value)
    const destination = returnDestination()
    if (session.password_change_required) {
      await router.replace({ name: 'change-password', query: redirectQuery(destination) })
    } else {
      await router.replace(destination)
    }
  } catch (_error) {}
}

function redirectQuery(destination) {
  if (typeof destination === 'string') return { redirect: destination }
  return {}
}

function returnDestination() {
  const destination = route.query.redirect
  if (
    typeof destination === 'string'
    && destination.startsWith('/')
    && !destination.startsWith('//')
    && !destination.startsWith('/login')
  ) {
    return destination
  }

  return { name: 'home' }
}
</script>

<template>
  <main class="login-shell">
    <section class="login-card">
      <p class="eyebrow">Private front-office workspace</p>
      <h1>{{ mode === 'login' ? 'Sign in to NineLens' : 'Create your account' }}</h1>
      <p>Watchlists, notes, and acquisition evaluations are private to your account.</p>
      <form @submit.prevent="submit">
        <label v-if="mode === 'register'">Name<input v-model="name" required autocomplete="name" /></label>
        <label>Email<input v-model="email" required type="email" autocomplete="email" /></label>
        <label>Password<input v-model="password" required minlength="8" type="password" :autocomplete="mode === 'register' ? 'new-password' : 'current-password'" /></label>
        <p v-if="error" class="login-error" role="alert">{{ error }}</p>
        <button type="submit" :disabled="loading">{{ loading ? 'Working…' : mode === 'login' ? 'Sign in' : 'Create account' }}</button>
      </form>
      <p v-if="!anonymousRegistrationEnabled" class="account-help">Accounts are provisioned by a workspace administrator.</p>
      <button v-if="anonymousRegistrationEnabled" class="login-switch" type="button" @click="mode = mode === 'login' ? 'register' : 'login'">
        {{ mode === 'login' ? 'Create the first workspace account' : 'Already have an account? Sign in' }}
      </button>
    </section>
  </main>
</template>

<style scoped>
.login-shell { min-height: calc(100vh - 74px); display: grid; place-items: center; padding: 2rem; background: linear-gradient(145deg,#f7f1e3,#ead8b6); color: #10263d; }.login-card { width: min(440px,100%); padding: 2rem; border: 1px solid rgba(16,38,61,.14); border-radius: 24px; background: rgba(255,252,244,.92); box-shadow: 0 20px 50px rgba(64,43,20,.12); }.eyebrow { color: #b79569; font-size: .68rem; font-weight: 900; letter-spacing: .12em; text-transform: uppercase; }.login-card h1 { margin: .3rem 0; font-family: 'Avenir Next Condensed',sans-serif; font-size: 2.6rem; text-transform: uppercase; }.login-card > p:not(.eyebrow) { color: #71808c; font-size: .8rem; }.login-card form { display: grid; gap: .7rem; margin-top: 1.2rem; }.login-card label { display: grid; gap: .25rem; color: #697784; font-size: .67rem; font-weight: 900; text-transform: uppercase; }.login-card input { padding: .65rem; border: 1px solid rgba(16,38,61,.16); border-radius: 9px; background: #fffdf7; font: inherit; }.login-card form button { padding: .7rem; border: 0; border-radius: 9px; color: #fffaf0; background: #20543c; font-weight: 900; }.login-card button:disabled { opacity: .5; }.login-error { margin: 0; color: #8f2d24; font-size: .76rem; }.account-help { margin: 1rem 0 0; }.login-switch { margin-top: 1rem; padding: 0; border: 0; color: #20543c; background: transparent; font-size: .74rem; font-weight: 800; }
</style>
