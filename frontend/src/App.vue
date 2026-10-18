<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
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
const navigationOpen = ref(false)
const searchOpen = ref(false)
const isAdministrator = computed(() => ['admin', 'administrator'].includes(user.value?.role))
const signInTarget = computed(() => ({
  name: 'login',
  query: route.name === 'login' ? {} : { redirect: route.fullPath },
}))
const passwordChangeTarget = computed(() => ({
  name: 'change-password',
  query: route.name === 'change-password' ? {} : { redirect: route.fullPath },
}))

function closeAccountMenu(event) {
  if (!event?.target?.closest?.('.app-account')) accountMenuOpen.value = false
}

function closeMobilePanels() {
  navigationOpen.value = false
  searchOpen.value = false
  accountMenuOpen.value = false
}

function toggleNavigation() {
  navigationOpen.value = !navigationOpen.value
  searchOpen.value = false
  accountMenuOpen.value = false
}

async function openSearch() {
  searchOpen.value = true
  navigationOpen.value = false
  accountMenuOpen.value = false
  await nextTick()
  document.getElementById('global-player-search')?.focus()
}

function handleKeydown(event) {
  if (event.key === 'Escape' && (navigationOpen.value || searchOpen.value)) closeMobilePanels()
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
  document.addEventListener('keydown', handleKeydown)
})
onBeforeUnmount(() => {
  document.removeEventListener('click', closeAccountMenu)
  document.removeEventListener('keydown', handleKeydown)
})

watch(() => route.fullPath, closeMobilePanels)
</script>

<template>
  <header class="app-bar">
    <RouterLink class="app-brand" to="/" @click="closeMobilePanels">
      <span class="app-brand__mark" aria-hidden="true">
        <img :src="nineLensLogo" alt="" />
      </span>
      <span>
        <strong>NineLens</strong>
        <small>Baseball intelligence</small>
      </span>
    </RouterLink>
    <div class="app-search-shell" :class="{ 'is-open': searchOpen }">
      <div class="app-mobile-panel__header">
        <strong>Search NineLens</strong>
        <button
          type="button"
          class="app-mobile-panel__close"
          aria-label="Close search"
          @click="closeMobilePanels"
        >
          <span aria-hidden="true">×</span>
        </button>
      </div>
      <PlayerSearch />
    </div>

    <div class="app-mobile-actions">
      <button type="button" aria-label="Search" :aria-expanded="searchOpen" @click="openSearch">
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <circle cx="11" cy="11" r="6.5"></circle>
          <path d="m16 16 4 4"></path>
        </svg>
      </button>
      <button
        type="button"
        aria-label="Open navigation"
        :aria-expanded="navigationOpen"
        aria-controls="mobile-navigation"
        @click.stop="toggleNavigation"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M4 7h16M4 12h16M4 17h16"></path>
        </svg>
      </button>
    </div>

    <div id="mobile-navigation" class="app-navigation-shell" :class="{ 'is-open': navigationOpen }">
      <div class="app-mobile-panel__header">
        <strong>Menu</strong>
        <button
          type="button"
          class="app-mobile-panel__close"
          aria-label="Close navigation"
          @click="closeMobilePanels"
        >
          <span aria-hidden="true">×</span>
        </button>
      </div>
      <nav class="app-primary-nav" aria-label="Primary navigation">
        <RouterLink to="/" @click="closeMobilePanels">Home</RouterLink>
        <RouterLink to="/schedule" @click="closeMobilePanels">Schedule</RouterLink>
        <RouterLink to="/standings" @click="closeMobilePanels">Standings</RouterLink>
        <RouterLink v-if="postseason.active" to="/postseason" @click="closeMobilePanels">Postseason</RouterLink>
        <RouterLink to="/explore" @click="closeMobilePanels">Stat Explorer</RouterLink>
        <RouterLink to="/compare" @click="closeMobilePanels">Compare</RouterLink>
        <RouterLink to="/teams" @click="closeMobilePanels">Teams</RouterLink>
      </nav>
      <div class="app-account">
        <RouterLink v-if="!user" :to="signInTarget" @click="closeMobilePanels">Sign in</RouterLink>
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
            <RouterLink to="/watchlists" role="menuitem" @click="closeMobilePanels">Watchlists</RouterLink>
            <RouterLink :to="passwordChangeTarget" role="menuitem" @click="closeMobilePanels">Change password</RouterLink>
            <RouterLink v-if="isAdministrator" to="/admin" role="menuitem" @click="closeMobilePanels">Admin</RouterLink>
            <button type="button" role="menuitem" @click="signOut">Sign out</button>
          </div>
        </template>
      </div>
    </div>
  </header>
  <button
    v-if="navigationOpen || searchOpen"
    type="button"
    class="app-mobile-scrim"
    aria-label="Close open panel"
    @click="closeMobilePanels"
  ></button>
  <div class="app-content">
    <RouterView />
  </div>
  <footer class="app-footer">
    <a href="https://github.com/timothyf/ninelens" target="_blank" rel="noopener noreferrer">NineLens on GitHub</a>
    <span class="data-source">Data provided by MLB</span>
  </footer>
</template>
