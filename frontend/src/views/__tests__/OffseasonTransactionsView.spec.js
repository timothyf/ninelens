import { flushPromises, mount } from '@vue/test-utils'
import { createMemoryHistory, createRouter } from 'vue-router'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import OffseasonTransactionsView from '../OffseasonTransactionsView.vue'

const payload = { data: {
  season: 2026,
  as_of: '2026-11-25',
  transactions: [
    { id: 'trade-1', type: 'Trade', date: '2026-11-20', player_id: 31, player_name: 'Alex Agent', description: 'Detroit traded Alex Agent to Los Angeles.' },
    { id: 'signing-2', type: 'Signing', date: '2026-11-18', player_id: 32, player_name: 'Sam Signed', description: 'Sam Signed signed with Detroit Tigers' },
    { id: 'trade-3', type: 'Trade', date: '2026-11-15', player_id: null, player_name: 'Other Player', description: 'A three-team trade.' },
  ],
} }

async function mountView() {
  const router = createRouter({ history: createMemoryHistory(), routes: [
    { path: '/', name: 'home', component: { template: '<div />' } },
    { path: '/offseason-transactions', name: 'offseason-transactions', component: OffseasonTransactionsView },
    { path: '/players/:id', name: 'player-profile', component: { template: '<div />' } },
  ] })
  await router.push('/offseason-transactions')
  await router.isReady()
  const wrapper = mount(OffseasonTransactionsView, { global: { plugins: [router] } })
  await flushPromises()
  return wrapper
}

describe('OffseasonTransactionsView', () => {
  beforeEach(() => { global.fetch = vi.fn().mockResolvedValue({ ok: true, json: async () => payload }) })
  afterEach(() => { vi.restoreAllMocks() })

  it('shows all moves and links stored players', async () => {
    const wrapper = await mountView()

    expect(fetch).toHaveBeenCalledWith('/api/offseason_transactions', expect.any(Object))
    expect(wrapper.get('h1').text()).toBe('Offseason Transactions')
    expect(wrapper.findAll('tbody tr')).toHaveLength(3)
    expect(wrapper.get('a[href="/players/31"]').text()).toBe('Alex Agent')
    expect(wrapper.get('a[href="/players/32"]').text()).toBe('Sam Signed')
    expect(wrapper.get('tbody').text()).toContain('A three-team trade.')
  })

  it('filters moves by type and search without dropping the full list', async () => {
    const wrapper = await mountView()
    await wrapper.get('#transactions-type').setValue('Signing')
    expect(wrapper.findAll('tbody tr')).toHaveLength(1)
    expect(wrapper.get('tbody').text()).toContain('Sam Signed')

    await wrapper.get('#transactions-type').setValue('all')
    await wrapper.get('#transactions-search').setValue('Alex Agent')
    expect(wrapper.findAll('tbody tr')).toHaveLength(1)
    expect(wrapper.get('tbody').text()).toContain('Detroit traded Alex Agent')
  })
})
