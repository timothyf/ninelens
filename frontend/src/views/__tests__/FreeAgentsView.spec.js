import { flushPromises, mount } from '@vue/test-utils'
import { createMemoryHistory, createRouter } from 'vue-router'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import FreeAgentsView from '../FreeAgentsView.vue'

const payload = { data: {
  season: 2026,
  as_of: '2026-11-21',
  batters: [
    { player_id: 1, player_name: 'Randy Arozarena', age: 31, position: 'LF', former_team: 'SEA', experience_years: 8, war: 5.6,
      stat_line: { season: 2026, values: { G: 154, AVG: 0.281, OBP: 0.381, SLG: 0.484, HR: 26, RBI: 79 } } },
    { player_id: 2, player_name: 'No Stats', position: '1B', former_team: 'DET', experience_years: null, war: null, stat_line: null },
  ],
  pitchers: [
    { player_id: 3, player_name: 'Tarik Skubal', age: 30, position: 'P', former_team: 'LAD', experience_years: 7, war: 5.2,
      stat_line: { season: 2026, values: { G: 26, W: 12, L: 7, ERA: 2.72, WHIP: 0.96, IP: 158.2, SO: 186 } } },
  ],
} }

async function mountView() {
  const router = createRouter({ history: createMemoryHistory(), routes: [
    { path: '/', name: 'home', component: { template: '<div />' } },
    { path: '/free-agents', name: 'free-agents', component: FreeAgentsView },
    { path: '/players/:id', name: 'player-profile', component: { template: '<div />' } },
  ] })
  await router.push('/free-agents')
  await router.isReady()
  const wrapper = mount(FreeAgentsView, { global: { plugins: [router] } })
  await flushPromises()
  return wrapper
}

describe('FreeAgentsView', () => {
  beforeEach(() => { global.fetch = vi.fn().mockResolvedValue({ ok: true, json: async () => payload }) })
  afterEach(() => { vi.restoreAllMocks() })

  it('shows batter and pitcher stats in separate tabs with player links and missing values', async () => {
    const wrapper = await mountView()

    expect(fetch).toHaveBeenCalledWith('/api/free_agents', expect.any(Object))
    expect(wrapper.get('#free-agent-tab-batters').attributes('aria-selected')).toBe('true')
    expect(wrapper.get('#free-agent-tab-pitchers').text()).toContain('1')
    expect(wrapper.get('a[href="/players/1"]').text()).toBe('Randy Arozarena')
    expect(wrapper.get('a[href="/players/1"]').element.closest('tr').textContent).toContain('31')
    expect(wrapper.find('a[href="/players/3"]').exists()).toBe(false)
    expect(wrapper.get('#free-agent-batters-panel').text()).toContain('.281')
    expect(wrapper.get('#free-agent-batters-panel').text()).toContain('26')
    expect(wrapper.get('a[href="/players/2"]').element.closest('tr').textContent).toContain('—')

    await wrapper.get('#free-agent-tab-pitchers').trigger('click')
    expect(wrapper.get('#free-agent-tab-pitchers').attributes('aria-selected')).toBe('true')
    expect(wrapper.find('#free-agent-batters-panel').exists()).toBe(false)
    expect(wrapper.get('a[href="/players/3"]').text()).toBe('Tarik Skubal')
    expect(wrapper.get('a[href="/players/3"]').element.closest('tr').textContent).toContain('30')
    expect(wrapper.get('#free-agent-pitchers-panel').text()).toContain('2.72')
    expect(wrapper.get('#free-agent-pitchers-panel').text()).toContain('158.2')
  })

  it('filters both tabs by player, position, or former team', async () => {
    const wrapper = await mountView()
    await wrapper.get('#free-agents-search').setValue('LAD')

    expect(wrapper.find('a[href="/players/1"]').exists()).toBe(false)
    expect(wrapper.get('#free-agent-batters-panel').text()).toContain('No batters match your search.')
    await wrapper.get('#free-agent-tab-pitchers').trigger('click')
    expect(wrapper.get('a[href="/players/3"]').text()).toBe('Tarik Skubal')
    expect(wrapper.get('#free-agent-tab-batters').text()).toContain('0')
  })

  it('switches tabs with the keyboard', async () => {
    const wrapper = await mountView()
    await wrapper.get('#free-agent-tab-batters').trigger('keydown', { key: 'ArrowRight' })

    expect(wrapper.get('#free-agent-tab-pitchers').attributes('aria-selected')).toBe('true')
    expect(wrapper.get('#free-agent-pitchers-panel').exists()).toBe(true)
  })
})
