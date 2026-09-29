import { flushPromises, mount } from '@vue/test-utils'
import { createMemoryHistory, createRouter } from 'vue-router'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import StandingsView from '../StandingsView.vue'

const payload = {
  data: {
    season: 2026,
    available_seasons: [2025, 2026],
    as_of: '2026-07-19',
    season_status: 'final',
    playoff_odds: { simulations: 7000, remaining_games: 930, model: 'Monte Carlo' },
    leagues: [
      {
        key: 'american',
        name: 'American League',
        divisions: [{
          key: 'al_central',
          name: 'AL Central',
          teams: [
            { rank: 1, team: { id: 1, abbreviation: 'DET', name: 'Detroit Tigers', logo_url: '/det.svg' }, wins: 60, losses: 39, winning_percentage: 0.606, games_back: 0, run_differential: 105, playoff_odds: { playoffs: 92.4 } },
            { rank: 2, team: { id: 2, abbreviation: 'CLE', name: 'Cleveland Guardians', logo_url: '/cle.svg' }, wins: 56, losses: 43, winning_percentage: 0.566, games_back: 4, run_differential: 31, playoff_odds: { playoffs: 71.8 } },
          ],
        }],
        wild_card: {
          cutoff_positions: 3,
          teams: [
            { rank: 1, wild_card_position: 1, wild_card_games_back: 0, division: { key: 'al_central', name: 'AL Central' }, team: { id: 2, abbreviation: 'CLE', name: 'Cleveland Guardians', logo_url: '/cle.svg' }, wins: 56, losses: 43, winning_percentage: 0.566, run_differential: 31, playoff_odds: { playoffs: 71.8 } },
            { rank: 4, wild_card_position: null, wild_card_games_back: 2.5, division: { key: 'al_east', name: 'AL East' }, team: { id: 3, abbreviation: 'BOS', name: 'Boston Red Sox', logo_url: '/bos.svg' }, wins: 52, losses: 47, winning_percentage: 0.525, run_differential: 10, playoff_odds: { playoffs: 38.2 } },
          ],
        },
      },
      {
        key: 'national',
        name: 'National League',
        divisions: [{ key: 'nl_central', name: 'NL Central', teams: [] }],
        wild_card: { cutoff_positions: 3, teams: [] },
      },
    ],
  },
}

async function mountView(path = '/standings') {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/standings', name: 'standings', component: StandingsView },
      { path: '/teams/:id', name: 'team-profile', component: { template: '<div />' } },
    ],
  })
  await router.push(path)
  await router.isReady()
  const wrapper = mount(StandingsView, { global: { plugins: [router] } })
  await flushPromises()
  return { wrapper, router }
}

describe('StandingsView', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))
  })

  afterEach(() => vi.unstubAllGlobals())

  it('renders division standings and supports league and season selection', async () => {
    const { wrapper, router } = await mountView()

    expect(fetch).toHaveBeenCalledWith('/api/standings', expect.objectContaining({ headers: { Accept: 'application/json' } }))
    const central = wrapper.get('[data-test="standings-al_central"]')
    expect(central.text()).toContain('Detroit Tigers')
    expect(wrapper.get('.standings-season-status strong').text()).toBe('FINAL')
    expect(central.text()).toContain('60')
    expect(central.text()).toContain('.606')
    expect(central.text()).toContain('+105')
    expect(central.text()).toContain('92.4%')
    expect(central.text()).toContain('Cleveland Guardians')
    expect(central.text()).toContain('4')
    const wildCard = wrapper.get('[data-test="wild-card-standings"]')
    expect(wildCard.text()).toContain('Postseason standings')
    expect(wildCard.text()).not.toContain('Postseason race')
    expect(wildCard.text()).toContain('American League Wild Card')
    expect(wildCard.text()).toContain('WC1')
    expect(wildCard.text()).toContain('Cleveland Guardians')
    expect(wildCard.text()).toContain('IN')
    expect(wildCard.text()).toContain('Boston Red Sox')
    expect(wildCard.text()).toContain('2.5')
    expect(wildCard.text()).toContain('38.2%')
    expect(wrapper.get('[data-test="playoff-odds-note"]').text()).toContain('7,000 simulations')

    await wrapper.get('[data-test="standings-league-national"]').trigger('click')
    await flushPromises()
    expect(router.currentRoute.value.query.league).toBe('national')
    expect(wrapper.get('[data-test="standings-nl_central"]').text()).toContain('No teams are stored for this division')

    await wrapper.get('[data-test="standings-season"]').setValue('2025')
    await flushPromises()
    expect(router.currentRoute.value.query.season).toBe('2025')
    expect(fetch).toHaveBeenLastCalledWith('/api/standings?season=2025', expect.any(Object))
  })

  it('shows a retry state when standings cannot load', async () => {
    fetch.mockResolvedValueOnce({ ok: false, status: 503 })
    const { wrapper } = await mountView()

    expect(wrapper.get('[data-test="standings-error"]').text()).toContain('Unable to load MLB standings')
  })
})
