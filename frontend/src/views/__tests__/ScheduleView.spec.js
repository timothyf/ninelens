import { flushPromises, mount } from '@vue/test-utils'
import { createMemoryHistory, createRouter } from 'vue-router'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import ScheduleView from '../ScheduleView.vue'

const games = [
  {
    id: 10,
    scheduled_at: '2026-07-16T17:10:00Z',
    status: 'preview',
    if_necessary: true,
    detailed_status: 'Pre-Game',
    venue_name: 'Comerica Park',
    away_score: null,
    home_score: null,
    away_team: { id: 2, abbreviation: 'CLE', name: 'Cleveland Guardians' },
    home_team: { id: 1, abbreviation: 'DET', name: 'Detroit Tigers' },
    away_probable_pitcher: { id: 20, full_name: 'Tanner Bibee' },
    home_probable_pitcher: { id: 21, full_name: 'Tarik Skubal' },
  },
  {
    id: 11,
    scheduled_at: '2026-07-16T18:10:00Z',
    status: 'live',
    detailed_status: 'In Progress',
    current_inning: 5,
    current_inning_ordinal: '5th',
    venue_name: 'Progressive Field',
    away_score: 2,
    home_score: 3,
    away_team: { id: 4, abbreviation: 'HOU', name: 'Houston Astros' },
    home_team: { id: 5, abbreviation: 'CLE', name: 'Cleveland Guardians' },
  },
]

async function mountView(path = '/schedule?date=2026-07-16') {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/schedule', name: 'schedule', component: ScheduleView },
      { path: '/games/:id', name: 'game-summary', component: { template: '<div />' } },
      { path: '/teams/:id', name: 'team-profile', component: { template: '<div />' } },
    ],
  })
  await router.push(path)
  await router.isReady()
  const wrapper = mount(ScheduleView, { global: { plugins: [router] } })
  await flushPromises()
  return { wrapper, router }
}

describe('ScheduleView', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: vi.fn().mockResolvedValue({ data: games, meta: { total_count: 1 } }),
    }))
  })

  afterEach(() => vi.unstubAllGlobals())

  it('lists the selected date and moves backward and forward through the schedule', async () => {
    const { wrapper, router } = await mountView()

    expect(fetch).toHaveBeenCalledWith(
      '/api/games?start_date=2026-07-16&end_date=2026-07-16&per_page=100',
      expect.objectContaining({ headers: { Accept: 'application/json' } }),
    )
    expect(wrapper.get('[data-test="schedule-games"]').text()).toContain('Thursday, July 16, 2026')
    expect(wrapper.get('[data-test="schedule-games"]').text()).toContain('Detroit Tigers')
    expect(wrapper.get('[data-test="schedule-games"]').text()).toContain('Tarik Skubal')
    expect(wrapper.get('[data-test="game-summary-link"]').attributes('aria-label')).toContain('Cleveland Guardians at Detroit Tigers')
    expect(wrapper.findAll('.schedule-game-card__team-name')).toHaveLength(4)
    expect(wrapper.findAll('.schedule-game-card__team > a')).toHaveLength(4)
    expect(wrapper.text()).toContain('In Progress · 5th')
    expect(wrapper.text()).toContain('If necessary')

    await wrapper.get('[data-test="schedule-next"]').trigger('click')
    await flushPromises()
    expect(router.currentRoute.value.query.date).toBe('2026-07-17')
    expect(fetch).toHaveBeenLastCalledWith(
      '/api/games?start_date=2026-07-17&end_date=2026-07-17&per_page=100',
      expect.any(Object),
    )

    await wrapper.get('[data-test="schedule-previous"]').trigger('click')
    await flushPromises()
    expect(router.currentRoute.value.query.date).toBe('2026-07-16')

    await wrapper.get('[data-test="schedule-date-input"]').setValue('2026-07-20')
    await flushPromises()
    expect(router.currentRoute.value.query.date).toBe('2026-07-20')
  })

  it('shows empty and retry states', async () => {
    fetch.mockResolvedValueOnce({ ok: true, json: async () => ({ data: [] }) })
    const { wrapper } = await mountView()
    expect(wrapper.get('[data-test="schedule-games"]').text()).toContain('No games are stored for Thursday, July 16, 2026')
    wrapper.unmount()

    fetch.mockResolvedValueOnce({ ok: false, status: 503 })
    const failed = await mountView()
    expect(failed.wrapper.get('[data-test="schedule-error"]').text()).toContain('Unable to load the schedule for this date')
  })
})
