import { createRouter, createWebHistory } from 'vue-router'

import StatExplorer from '../components/StatExplorer.vue'
import AdminView from '../views/AdminView.vue'
import AccessDeniedView from '../views/AccessDeniedView.vue'
import GameSummaryView from '../views/GameSummaryView.vue'
import HomeView from '../views/HomeView.vue'
import LineupScenarioView from '../views/LineupScenarioView.vue'
import LoginView from '../views/LoginView.vue'
import OpponentReportView from '../views/OpponentReportView.vue'
import PostseasonView from '../views/PostseasonView.vue'
import PlayerProfileView from '../views/PlayerProfile/PlayerProfileView.vue'
import PlayerComparisonView from '../views/PlayerComparisonView.vue'
import ScheduleView from '../views/ScheduleView.vue'
import SavedAnalysisRedirectView from '../views/SavedAnalysisRedirectView.vue'
import StandingsView from '../views/StandingsView.vue'
import TeamDirectoryView from '../views/TeamDirectoryView.vue'
import TeamProfileView from '../views/TeamProfileView.vue'
import WatchlistsView from '../views/WatchlistsView.vue'
import { useAuth } from '../composables/useAuth'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'home',
      component: HomeView,
    },
    {
      path: '/schedule',
      name: 'schedule',
      component: ScheduleView,
    },
    {
      path: '/standings',
      name: 'standings',
      component: StandingsView,
    },
    {
      path: '/postseason',
      name: 'postseason',
      component: PostseasonView,
    },
    {
      path: '/explore',
      name: 'stat-explorer',
      component: StatExplorer,
    },
    {
      path: '/stat-board',
      redirect: { name: 'stat-explorer' },
    },
    {
      path: '/games/:id',
      name: 'game-summary',
      component: GameSummaryView,
      props: (route) => ({ gameId: route.params.id }),
    },
    {
      path: '/players/:id',
      name: 'player-profile',
      component: PlayerProfileView,
      props: (route) => ({ playerId: route.params.id }),
    },
    {
      path: '/compare',
      name: 'player-comparison',
      component: PlayerComparisonView,
    },
    {
      path: '/saved/:id',
      name: 'saved-analysis',
      component: SavedAnalysisRedirectView,
      props: (route) => ({ savedAnalysisId: route.params.id }),
    },
    {
      path: '/teams',
      name: 'teams',
      component: TeamDirectoryView,
    },
    {
      path: '/watchlists',
      name: 'watchlists',
      component: WatchlistsView,
      meta: { requiresAuth: true },
    },
    {
      path: '/login',
      name: 'login',
      component: LoginView,
    },
    {
      path: '/access-denied',
      name: 'access-denied',
      component: AccessDeniedView,
      meta: { requiresAuth: true },
    },
    {
      path: '/teams/:id',
      name: 'team-profile',
      component: TeamProfileView,
      props: (route) => ({ teamId: route.params.id }),
    },
    {
      path: '/opponent-reports/:id',
      name: 'opponent-report',
      component: OpponentReportView,
      props: (route) => ({ reportId: route.params.id }),
    },
    {
      path: '/lineup-scenarios/:id',
      name: 'lineup-scenario',
      component: LineupScenarioView,
      props: (route) => ({ scenarioId: route.params.id }),
    },
    {
      path: '/admin',
      name: 'admin',
      component: AdminView,
      meta: { requiresAuth: true, requiresAdmin: true },
    },
  ],
  scrollBehavior: () => ({ top: 0 }),
})

router.beforeEach(async (to) => {
  if (!to.meta.requiresAuth && !to.meta.requiresAdmin) return true

  const auth = useAuth()
  const currentUser = auth.user.value || await auth.loadCurrentUser()
  if (!currentUser) return { name: 'login', query: { redirect: to.fullPath } }
  if (to.meta.requiresAdmin && !['admin', 'administrator'].includes(currentUser.role)) return { name: 'access-denied' }
  return true
})

export default router
