<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import PlayerSearch from './components/PlayerSearch.vue'
import nineLensLogo from './assets/ninelens_logo.png'
import { useAuth } from './composables/useAuth'
import { usePostseason } from './composables/usePostseason'

const { user, loadCurrentUser, logout } = useAuth()
const { postseason, load: loadPostseason } = usePostseason()
const route = useRoute()
const router = useRouter()
const accountMenuOpen = ref(false)
const isAdministrator = computed(() => ['admin', 'administrator'].includes(user.value?.role))
const signInTarget = computed(() => ({
  name: 'login',
  query: route.name === 'login' ? {} : { redirect: route.fullPath },
}))

function closeAccountMenu(event) {
  if (!event?.target?.closest?.('.app-account')) accountMenuOpen.value = false
}

async function signOut() {
  accountMenuOpen.value = false
  const signedOutFrom = route.fullPath
  const logoutRequest = logout()
  if (route.meta.requiresAuth || route.meta.requiresAdmin) {
    await router.replace({ name: 'login', query: { redirect: signedOutFrom } })
  }
  await logoutRequest
}

onMounted(() => {
  loadCurrentUser()
  loadPostseason()
  document.addEventListener('click', closeAccountMenu)
})
onBeforeUnmount(() => document.removeEventListener('click', closeAccountMenu))
</script>

<template>
  <header class="app-bar">
    <RouterLink class="app-brand" to="/">
      <span class="app-brand__mark" aria-hidden="true">
        <img :src="nineLensLogo" alt="" />
      </span>
      <span>
        <strong>NineLens</strong>
        <small>Baseball intelligence</small>
      </span>
    </RouterLink>
    <PlayerSearch />
    <nav class="app-primary-nav" aria-label="Primary navigation">
      <RouterLink to="/">Home</RouterLink>
      <RouterLink to="/schedule">Schedule</RouterLink>
      <RouterLink to="/standings">Standings</RouterLink>
      <RouterLink v-if="postseason.active" to="/postseason">Postseason</RouterLink>
      <RouterLink to="/explore">Stat Explorer</RouterLink>
      <RouterLink to="/compare">Compare</RouterLink>
      <RouterLink to="/teams">Teams</RouterLink>
    </nav>
    <div class="app-account">
      <RouterLink v-if="!user" :to="signInTarget">Sign in</RouterLink>
      <template v-else>
        <button
          type="button"
          class="app-account__trigger"
          :aria-expanded="accountMenuOpen"
          aria-haspopup="menu"
          @click.stop="accountMenuOpen = !accountMenuOpen"
        >
          {{ user.name }} <span aria-hidden="true">⌄</span>
        </button>
        <div v-if="accountMenuOpen" class="app-account__menu" role="menu">
          <span class="app-account__email">{{ user.email }}</span>
          <RouterLink to="/watchlists" role="menuitem" @click="accountMenuOpen = false">Watchlists</RouterLink>
          <RouterLink v-if="isAdministrator" to="/admin" role="menuitem" @click="accountMenuOpen = false">Admin</RouterLink>
          <button type="button" role="menuitem" @click="signOut">Sign out</button>
        </div>
      </template>
    </div>
  </header>
  <div class="app-content">
    <RouterView />
  </div>
  <footer class="app-footer">
    <a href="https://github.com/timothyf/ninelens" target="_blank" rel="noopener noreferrer">NineLens on GitHub</a>
    <span class="data-source">Data provided by MLB</span>
  </footer>
</template>
