import { flushPromises, mount } from '@vue/test-utils'
import { createMemoryHistory, createRouter } from 'vue-router'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import PostseasonView from '../PostseasonView.vue'

const postseason = {
  active: true,
  season: 2026,
  available_seasons: [2026],
  playoff_teams: [],
  game_results: [],
  upcoming_games: [],
  rounds: [],
  leaders: {
    batting: [{
      player: { id: 11, full_name: 'Ronald Acuna' },
      team: { id: 1, abbreviation: 'ATL' },
      games: 3,
      at_bats: 12,
      runs: 4,
      hits: 6,
      home_runs: 2,
      runs_batted_in: 5,
      batting_average: 0.5,
      ops: 1.417,
    }],
    pitching: [{
      player: { id: 12, full_name: 'Spencer Strider' },
      team: { id: 1, abbreviation: 'ATL' },
      games: 1,
      innings_pitched: '7.0',
      wins: 1,
      losses: 0,
      saves: 0,
      strikeouts: 9,
      era: 1.286,
      whip: 0.714,
    }],
  },
}

async function mountView() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/postseason', name: 'postseason', component: PostseasonView },
      { path: '/players/:id', name: 'player-profile', component: { template: '<div />' } },
      { path: '/teams/:id', name: 'team-profile', component: { template: '<div />' } },
      { path: '/games/:id', name: 'game-summary', component: { template: '<div />' } },
    ],
  })
  await router.push('/postseason')
  await router.isReady()
  const wrapper = mount(PostseasonView, { global: { plugins: [router] } })
  await flushPromises()
  return wrapper
}

describe('PostseasonView', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: vi.fn().mockResolvedValue({ data: postseason }),
    }))
  })

  afterEach(() => vi.unstubAllGlobals())

  it('shows postseason batting and pitching leaders with formatted rates', async () => {
    const wrapper = await mountView()
    const leaders = wrapper.get('[data-test="postseason-leaders"]')

    expect(leaders.text()).toContain('Minimum 3.1 AB or 1 IP per team game')
    expect(leaders.text()).toContain('Ronald Acuna')
    expect(leaders.text()).toContain('.500')
    expect(leaders.text()).toContain('1.417')
    expect(leaders.text()).toContain('Spencer Strider')
    expect(leaders.text()).toContain('1.29')
    expect(leaders.text()).toContain('0.71')
    expect(leaders.find('a[href="/players/11"]').exists()).toBe(true)
    expect(leaders.find('a[href="/teams/1"]').exists()).toBe(true)
  })
})
