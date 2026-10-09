import { flushPromises, mount } from '@vue/test-utils'
import { createMemoryHistory, createRouter } from 'vue-router'
import { beforeEach, vi } from 'vitest'

import PlayerComparisonView from '../PlayerComparisonView.vue'

function profile(id, name, team, stats, careerStats = stats) {
  const [firstName, lastName] = name.split(' ')
  return {
    data: {
      id,
      mlb_id: 600000 + id,
      first_name: firstName,
      last_name: lastName,
      full_name: name,
      team: { id: team.id, name: team.name, abbreviation: team.abbreviation },
      display_team: { id: team.id, name: team.name, abbreviation: team.abbreviation },
      profile: { age: id === 1 ? 25 : 27, bats: id === 1 ? 'L' : 'R', throws: 'R' },
      positions: { primary: { abbreviation: id === 1 ? 'CF' : 'RF', name: 'Outfielder' }, secondary: [], assignments: [] },
      season_overview: {
        season: 2026, category: 'batting', preferred_category: 'batting', stats,
        comparison_benchmarks: {},
        comparison_stats: [
          { key: 'k_percentage', label: 'K%', value: id === 1 ? 0.22 : 0.29 },
          { key: 'bb_percentage', label: 'BB%', value: id === 1 ? 0.09 : 0.14 },
          { key: 'iso', label: 'ISO', value: id === 1 ? 0.18 : 0.21 },
          { key: 'wrc_plus', label: 'wRC+', value: id === 1 ? 118 : 126 },
          { key: 'baserunning_runs', label: 'BSR', value: id === 1 ? 1.2 : 0.4 },
        ],
      },
      career_overview: {
        category: 'batting', preferred_category: 'batting', first_season: 2022,
        last_season: 2026, season_count: id === 1 ? 5 : 7, columns: [],
        seasons: [], stats: careerStats,
        comparison_stats: [
          { key: 'k_percentage', label: 'K%', value: id === 1 ? 0.24 : 0.28 },
          { key: 'bb_percentage', label: 'BB%', value: id === 1 ? 0.1 : 0.15 },
        ],
      },
      current_membership: null,
      team_history: [],
      recent_pitch_indicators: { primary_role: 'batter', batting: {}, pitching: {} },
      contextual_benchmarks: {},
      analysis: {},
      source_metadata: {},
    },
  }
}

function apiResponse(url, responses) {
  if (!url.startsWith('/api/players/compare')) return responses[url.split('?')[0]]

  const ids = new URL(`http://localhost${url}`).searchParams.get('ids').split(',')
  return { data: ids.map((id) => responses[`/api/players/${id}`].data) }
}

describe('PlayerComparisonView', () => {
  beforeEach(() => {
    const values = {}
    vi.stubGlobal('localStorage', {
      getItem: (key) => values[key] || null,
      setItem: (key, value) => { values[key] = String(value) },
      removeItem: (key) => { delete values[key] },
    })
  })

  it('loads URL-selected players and aligns season and career statistics', async () => {
    const responses = {
      '/api/players/1': profile(
        1, 'Riley Greene', { id: 10, name: 'Detroit Tigers', abbreviation: 'DET' },
        [{ key: 'atBats', label: 'AB', value: '500' }, { key: 'homeRuns', label: 'HR', value: '24.0' }, { key: 'ops', label: 'OPS', value: '0.842' }, { key: 'WAR', label: 'WAR', value: '3.2' }, { key: 'caughtStealing', label: 'CS', value: '5.0' }],
        [{ key: 'atBats', label: 'AB', value: '500' }, { key: 'homeRuns', label: 'HR', value: '82.0' }, { key: 'ops', label: 'OPS', value: '0.821' }, { key: 'WAR', label: 'WAR', value: '8.1' }, { key: 'caughtStealing', label: 'CS', value: '11.0' }],
      ),
      '/api/players/2': profile(
        2, 'Aaron Judge', { id: 11, name: 'New York Yankees', abbreviation: 'NYY' },
        [{ key: 'atBats', label: 'AB', value: '500' }, { key: 'homeRuns', label: 'HR', value: '38' }, { key: 'avg', label: 'AVG', value: '0.311' }, { key: 'WAR', label: 'WAR', value: '8.1' }, { key: 'caughtStealing', label: 'CS', value: '2' }],
        [{ key: 'atBats', label: 'AB', value: '500' }, { key: 'homeRuns', label: 'HR', value: '353' }, { key: 'avg', label: 'AVG', value: '0.288' }, { key: 'caughtStealing', label: 'CS', value: '7' }],
      ),
    }
    vi.stubGlobal('fetch', vi.fn((url) => Promise.resolve({
      ok: true,
      json: async () => apiResponse(url, responses),
    })))
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: '/compare', name: 'player-comparison', component: PlayerComparisonView },
        { path: '/players/:id', name: 'player-profile', component: { template: '<div />' } },
      ],
    })
    await router.push('/compare?left=1&right=2')
    await router.isReady()

    const wrapper = mount(PlayerComparisonView, { global: { plugins: [router] } })
    await flushPromises()

    expect(fetch).toHaveBeenCalledWith('/api/players/compare?ids=1%2C2&sections=core%2Cadvanced_stats%2Cdefensive_stats&view=comparison', expect.any(Object))
    expect(wrapper.get('[data-test="comparison-identities"]').text()).toContain('Riley Greene')
    expect(wrapper.get('[data-test="comparison-identities"]').text()).toContain('Aaron Judge')
    const playerAHeader = wrapper.get('[data-test="comparison-picker-player a"]')
    expect(playerAHeader.text()).toContain('Age 25')
    expect(playerAHeader.text()).toContain('Position CF')
    expect(playerAHeader.text()).toContain('Bats L')
    expect(playerAHeader.text()).toContain('Throws R')
    const playerBHeader = wrapper.get('[data-test="comparison-picker-player b"]')
    expect(playerBHeader.text()).toContain('Age 27')
    expect(playerBHeader.text()).toContain('Position RF')
    expect(playerBHeader.text()).toContain('Bats R')
    expect(playerBHeader.text()).toContain('Throws R')
    const season = wrapper.get('[data-test="season-comparison"]')
    expect(season.get('thead').text()).toMatch(/Offensive score \d+\/100/)
    expect(season.get('thead').text()).toMatch(/Overall value \d+\/100/)
    expect(season.get('thead').text()).not.toContain('Overall score —/100')
    expect(season.text()).toContain('24')
    expect(season.text()).not.toContain('24.0')
    expect(season.text()).toContain('38')
    expect(season.text()).toContain('0.842')
    expect(season.text()).toContain('0.311')
    expect(season.text()).toContain('3.2')
    expect(season.text()).toContain('8.1')
    expect(season.text()).toContain('—')
    const homeRuns = wrapper.get('[data-test="season-stat-homeRuns"]')
    expect(homeRuns.findAll('td')[0].classes()).toContain('is-lesser')
    expect(homeRuns.findAll('td')[1].classes()).toContain('is-better')
    const caughtStealing = wrapper.get('[data-test="season-stat-caughtStealing"]')
    expect(caughtStealing.findAll('td')[0].classes()).toContain('is-lesser')
    expect(caughtStealing.findAll('td')[1].classes()).toContain('is-better')
    const strikeoutPercentage = wrapper.get('[data-test="season-stat-k_percentage"]')
    expect(strikeoutPercentage.text()).toContain('22.0%')
    expect(strikeoutPercentage.text()).toContain('29.0%')
    expect(strikeoutPercentage.findAll('td')[0].classes()).toContain('is-better')
    const walkPercentage = wrapper.get('[data-test="season-stat-bb_percentage"]')
    expect(walkPercentage.text()).toContain('9.0%')
    expect(walkPercentage.text()).toContain('14.0%')
    expect(walkPercentage.findAll('td')[1].classes()).toContain('is-better')
    const career = wrapper.get('[data-test="career-comparison"]')
    expect(career.text()).toContain('82')
    expect(career.text()).toContain('353')
    expect(career.text()).toContain('24.0%')
    expect(career.text()).toContain('15.0%')

    const settings = wrapper.get('[data-test="comparison-settings"]')
    await settings.get('button').trigger('click')
    expect(settings.get('input[aria-label="OPS weight"]').element.value).toBe('0')
    expect(settings.get('input[aria-label="AB weight"]').element.value).toBe('0')
    expect(settings.get('input[aria-label="HR weight"]').element.value).toBe('0')
    expect(settings.get('input[aria-label="ISO weight"]').element.value).toBe('6')
    const wrcWeightInput = settings.findAll('input').find((input) => input.attributes('aria-label') === 'wRC+ weight')
    expect(wrcWeightInput.element.value).toBe('18')
    expect(settings.get('input[aria-label="BSR weight"]').element.value).toBe('6')
    expect(settings.get('input[aria-label="Defensive value weight"]').element.value).toBe('15')
    const opsPlusWeightInput = settings.findAll('input').find((input) => input.attributes('aria-label') === 'OPS+ weight')
    expect(opsPlusWeightInput.element.value).toBe('0')

    const scoreBeforeWeightChange = wrapper.get('[data-test="season-comparison"] thead').text()
    await settings.get('input[aria-label="WAR weight"]').setValue('100')
    await flushPromises()
    const scoreAfterWeightChange = wrapper.get('[data-test="season-comparison"] thead').text()
    expect(scoreAfterWeightChange).not.toBe(scoreBeforeWeightChange)
    await settings.get('input[aria-label="WAR weight"]').setValue('12')
    await settings.get('input[aria-label="OPS weight"]').setValue('33')
    expect(settings.get('.comparison-settings__save').text()).toBe('Save weights')
    await settings.get('.comparison-settings__save').trigger('click')
    expect(JSON.parse(localStorage.getItem('ninelens.compare.stat-weights'))).toMatchObject({ ops: 33 })

    wrapper.unmount()
    const reloadedWrapper = mount(PlayerComparisonView, { global: { plugins: [router] } })
    await flushPromises()
    const reloadedSettings = reloadedWrapper.get('[data-test="comparison-settings"]')
    await reloadedSettings.get('button').trigger('click')
    expect(reloadedSettings.get('input[aria-label="OPS weight"]').element.value).toBe('33')
    reloadedWrapper.unmount()
  })

  it('adds an optional third player to the comparison', async () => {
    const responses = {
      '/api/players/1': profile(1, 'Riley Greene', { id: 10, name: 'Detroit Tigers', abbreviation: 'DET' }, [{ key: 'homeRuns', label: 'HR', value: '24' }]),
      '/api/players/2': profile(2, 'Aaron Judge', { id: 11, name: 'New York Yankees', abbreviation: 'NYY' }, [{ key: 'homeRuns', label: 'HR', value: '38' }]),
      '/api/players/3': profile(3, 'Tarik Skubal', { id: 12, name: 'Detroit Tigers', abbreviation: 'DET' }, [{ key: 'homeRuns', label: 'HR', value: '2' }]),
    }
    vi.stubGlobal('fetch', vi.fn((url) => Promise.resolve({ ok: true, json: async () => apiResponse(url, responses) })))
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: '/compare', name: 'player-comparison', component: PlayerComparisonView },
        { path: '/players/:id', name: 'player-profile', component: { template: '<div />' } },
      ],
    })
    await router.push('/compare?left=1&right=2&third=3')
    await router.isReady()

    const wrapper = mount(PlayerComparisonView, { global: { plugins: [router] } })
    await flushPromises()

    expect(wrapper.get('[data-test="comparison-identities"]').text()).toContain('Tarik Skubal')
    expect(wrapper.get('[data-test="comparison-picker-player c"]').text()).toContain('Tarik Skubal')
    expect(wrapper.get('[data-test="season-comparison"] thead').findAll('th')).toHaveLength(4)
    expect(wrapper.get('[data-test="season-stat-homeRuns"]').findAll('td')).toHaveLength(3)
  })

  it('uses the season scoring model when both career records contain one season', async () => {
    const stats = [
      { key: 'atBats', label: 'AB', value: '500' },
      { key: 'homeRuns', label: 'HR', value: '24' },
      { key: 'ops', label: 'OPS', value: '0.842' },
      { key: 'WAR', label: 'WAR', value: '3.2' },
    ]
    const left = profile(1, 'Riley Greene', { id: 10, name: 'Detroit Tigers', abbreviation: 'DET' }, stats)
    const right = profile(2, 'Aaron Judge', { id: 11, name: 'New York Yankees', abbreviation: 'NYY' }, stats)
    right.data.season_overview.comparison_stats = left.data.season_overview.comparison_stats.map((stat) => ({ ...stat }))
    left.data.career_overview.comparison_stats = left.data.season_overview.comparison_stats.map((stat) => ({ ...stat }))
    right.data.career_overview.comparison_stats = left.data.season_overview.comparison_stats.map((stat) => ({ ...stat }))
    left.data.career_overview.season_count = 1
    right.data.career_overview.season_count = 1
    const responses = { '/api/players/1': left, '/api/players/2': right }
    vi.stubGlobal('fetch', vi.fn((url) => Promise.resolve({ ok: true, json: async () => apiResponse(url, responses) })))
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: '/compare', name: 'player-comparison', component: PlayerComparisonView },
        { path: '/players/:id', name: 'player-profile', component: { template: '<div />' } },
      ],
    })
    await router.push('/compare?left=1&right=2')
    await router.isReady()

    const wrapper = mount(PlayerComparisonView, { global: { plugins: [router] } })
    await flushPromises()

    const seasonScores = wrapper.get('[data-test="season-comparison"]').findAll('thead strong').map((node) => node.text())
    const careerScores = wrapper.get('[data-test="career-comparison"]').findAll('thead strong').map((node) => node.text())
    expect(careerScores).toEqual(seasonScores)
  })

  it('uses dedicated defensive stats when they are available', async () => {
    const left = profile(1, 'Alan Trammell', { id: 10, name: 'Detroit Tigers', abbreviation: 'DET' }, [{ key: 'atBats', label: 'AB', value: '500' }])
    const right = profile(2, 'Ozzie Smith', { id: 11, name: 'St. Louis Cardinals', abbreviation: 'STL' }, [{ key: 'atBats', label: 'AB', value: '500' }])
    left.data.defensive_stats = { seasons: [{ season: 2026, games: 120, fielding_percentage: 0.98, defensive_runs_saved: 12, outs_above_average: 8 }] }
    right.data.defensive_stats = { seasons: [{ season: 2026, games: 140, fielding_percentage: 0.99, defensive_runs_saved: 20, outs_above_average: 15 }] }
    const responses = { '/api/players/1': left, '/api/players/2': right }
    vi.stubGlobal('fetch', vi.fn((url) => Promise.resolve({ ok: true, json: async () => apiResponse(url, responses) })))
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: '/compare', name: 'player-comparison', component: PlayerComparisonView },
        { path: '/players/:id', name: 'player-profile', component: { template: '<div />' } },
      ],
    })
    await router.push('/compare?left=1&right=2')
    await router.isReady()

    const wrapper = mount(PlayerComparisonView, { global: { plugins: [router] } })
    await flushPromises()

    expect(wrapper.get('[data-test="season-stat-defensive_value"]').text()).toContain('12')
    expect(wrapper.get('[data-test="season-stat-defensive_runs_saved"]').text()).toContain('20')
    expect(wrapper.get('[data-test="season-stat-outs_above_average"]').text()).toContain('15')
    expect(wrapper.get('[data-test="season-stat-fielding_percentage"]').text()).toContain('99.0%')
  })

  it('uses TZR when the defensive value and DRS placeholders are zero', async () => {
    const left = profile(1, 'Alan Trammell', { id: 10, name: 'Detroit Tigers', abbreviation: 'DET' }, [
      { key: 'atBats', label: 'AB', value: '500' },
      { key: 'TZR', label: 'TZR', value: '76' },
    ])
    const right = profile(2, 'Lou Whitaker', { id: 11, name: 'Detroit Tigers', abbreviation: 'DET' }, [
      { key: 'atBats', label: 'AB', value: '500' },
      { key: 'TZR', label: 'TZR', value: '77' },
    ])
    left.data.season_overview.comparison_stats.push({ key: 'defensive_value', label: 'Defensive value', value: 0 })
    right.data.season_overview.comparison_stats.push({ key: 'defensive_value', label: 'Defensive value', value: 0 })
    left.data.defensive_stats = { seasons: [{ season: 2026, total_zone_runs: 76, defensive_runs_saved: 0 }] }
    right.data.defensive_stats = { seasons: [{ season: 2026, total_zone_runs: 77, defensive_runs_saved: 0 }] }
    const responses = { '/api/players/1': left, '/api/players/2': right }
    vi.stubGlobal('fetch', vi.fn((url) => Promise.resolve({ ok: true, json: async () => apiResponse(url, responses) })))
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: '/compare', name: 'player-comparison', component: PlayerComparisonView },
        { path: '/players/:id', name: 'player-profile', component: { template: '<div />' } },
      ],
    })
    await router.push('/compare?left=1&right=2')
    await router.isReady()

    const wrapper = mount(PlayerComparisonView, { global: { plugins: [router] } })
    await flushPromises()

    expect(wrapper.get('[data-test="season-stat-defensive_value"]').text()).toContain('76')
  })

  it('shows only career comparison when a selected player is retired', async () => {
    const retiredPlayer = profile(1, 'Riley Greene', { id: 10, name: 'Detroit Tigers', abbreviation: 'DET' }, [{ key: 'homeRuns', label: 'HR', value: '24' }])
    retiredPlayer.data.profile.active = false
    const responses = {
      '/api/players/1': retiredPlayer,
      '/api/players/2': profile(2, 'Aaron Judge', { id: 11, name: 'New York Yankees', abbreviation: 'NYY' }, [{ key: 'homeRuns', label: 'HR', value: '38' }]),
    }
    vi.stubGlobal('fetch', vi.fn((url) => Promise.resolve({ ok: true, json: async () => apiResponse(url, responses) })))
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: '/compare', name: 'player-comparison', component: PlayerComparisonView },
        { path: '/players/:id', name: 'player-profile', component: { template: '<div />' } },
      ],
    })
    await router.push('/compare?left=1&right=2')
    await router.isReady()

    const wrapper = mount(PlayerComparisonView, { global: { plugins: [router] } })
    await flushPromises()

    expect(wrapper.find('[data-test="season-comparison"]').exists()).toBe(false)
    expect(wrapper.get('[data-test="career-comparison"]').exists()).toBe(true)
  })
})
