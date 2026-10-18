import { flushPromises, mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import HomeView from '../HomeView.vue'

const dashboardPayload = {
  data: {
    as_of: '2026-07-16',
    season: 2026,
    games: [
      {
        id: 10,
        scheduled_at: '2026-07-16T17:10:00Z',
        status: 'preview',
        detailed_status: 'Pre-Game',
        venue_name: 'Comerica Park',
        away_score: null,
        home_score: null,
        away_team: { id: 2, mlb_id: 114, abbreviation: 'CLE', name: 'Cleveland Guardians' },
        home_team: { id: 1, mlb_id: 116, abbreviation: 'DET', name: 'Detroit Tigers' },
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
        away_team: { id: 4, mlb_id: 117, abbreviation: 'HOU', name: 'Houston Astros' },
        home_team: { id: 5, mlb_id: 118, abbreviation: 'CLE', name: 'Cleveland Guardians' },
      },
    ],
    leaders: [
      {
        key: 'ops',
        label: 'OPS',
        category: 'batting',
        qualifier: 'Minimum 259 AB',
        entries: [{ rank: 1, value: '1.025', player: { id: 30, full_name: 'Aaron Judge' }, team: { abbreviation: 'NYY' } }],
      },
      {
        key: 'avg',
        label: 'Batting average',
        category: 'batting',
        qualifier: 'Minimum 259 AB',
        entries: [{ rank: 1, value: '0.333', player: { id: 30, full_name: 'Aaron Judge' }, team: { abbreviation: 'NYY' } }],
      },
      {
        key: 'battingWAR',
        label: 'Batting WAR',
        category: 'batting',
        qualifier: '',
        entries: [{ rank: 1, value: '4.2', player: { id: 30, full_name: 'Aaron Judge' }, team: { abbreviation: 'NYY' } }],
      },
      {
        key: 'rbi',
        label: 'RBI',
        category: 'batting',
        qualifier: '',
        entries: [{ rank: 1, value: '12', player: { id: 30, full_name: 'Aaron Judge' }, team: { abbreviation: 'NYY' } }],
      },
      {
        key: 'pitchingWAR',
        label: 'Pitching WAR',
        category: 'pitching',
        qualifier: '',
        entries: [{ rank: 1, value: '3.5', player: { id: 31, full_name: 'Tarik Skubal' }, team: { abbreviation: 'DET' } }],
      },
      {
        key: 'wins',
        label: 'Wins',
        category: 'pitching',
        qualifier: '',
        entries: [{ rank: 1, value: '12', player: { id: 31, full_name: 'Tarik Skubal' }, team: { abbreviation: 'DET' } }],
      },
      {
        key: 'ERA',
        label: 'ERA',
        category: 'pitching',
        qualifier: 'Minimum 96 IP',
        entries: [{ rank: 1, value: '1.75', player: { id: 31, full_name: 'Tarik Skubal' }, team: { abbreviation: 'DET' } }],
      },
    ],
    team_pulse: {
      best_records: [{ team: { id: 1, abbreviation: 'DET', name: 'Detroit Tigers' }, wins: 60, losses: 36 }],
      run_differential: [{ team: { id: 1, abbreviation: 'DET', name: 'Detroit Tigers' }, run_differential: 105 }],
      recent_form: [{ team: { id: 1, abbreviation: 'DET', name: 'Detroit Tigers' }, recent_games: 10, recent_wins: 8, recent_losses: 2 }],
      last_30_form: [{ team: { id: 1, abbreviation: 'DET', name: 'Detroit Tigers' }, recent_30_games: 30, recent_30_wins: 19, recent_30_losses: 11 }],
    },
    freshness: { analytics: '2026-07-16T20:32:00Z' },
  },
}

const RouterLink = {
  props: ['to'],
  template: '<a href="#"><slot /></a>',
}

describe('HomeView', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: vi.fn().mockResolvedValue(dashboardPayload),
    }))
  })

  afterEach(() => vi.unstubAllGlobals())

  it('presents the daily slate, league leaders, team pulse, and exploration links', async () => {
    Object.values(dashboardPayload.data.team_pulse).flat().forEach((entry) => { entry.team.logo_url = "/DET.svg" })
    const wrapper = mount(HomeView, { global: { components: { RouterLink } } })
    await flushPromises()

    expect(fetch).toHaveBeenCalledWith('/api/home', expect.objectContaining({ headers: { Accept: 'application/json' } }))
    expect(wrapper.text()).toContain('Baseball intelligence, brought into focus')
    expect(wrapper.get('[data-test="today-games"]').text()).toContain('Detroit Tigers')
    expect(wrapper.get('[data-test="today-games"]').text()).toContain('Tarik Skubal')
    expect(wrapper.get('[data-test="today-games"]').text()).toContain('In Progress · 5th')
    expect(wrapper.get('[data-test="game-summary-link"]').exists()).toBe(true)
    expect(wrapper.findAll('.schedule-game-card__team-logo')).toHaveLength(4)
    expect(wrapper.get('.schedule-game-card__team-logo').attributes('src')).toContain('team-logos/114.svg')
    expect(wrapper.get('[data-test="home-leaders"]').text()).toContain('Aaron Judge')
    expect(wrapper.get('[data-test="home-leaders"]').text()).toContain('1.025')
    expect(wrapper.get('[data-test="home-leaders"]').text()).toContain('1.75')
    expect(wrapper.get('[data-test="home-leaders"]').text()).toContain('.333')
    expect(wrapper.get('[data-test="home-leaders"]').text()).toContain('4.2')
    expect(wrapper.get('[data-test="home-leaders"]').text()).toContain('RBI')
    expect(wrapper.get('[data-test="home-leaders"]').text()).toContain('12')
    expect(wrapper.get('[data-test="home-leaders"]').text()).toContain('Batting WAR')
    expect(wrapper.get('[data-test="home-leaders"]').text()).toContain('Pitching WAR')
    expect(wrapper.get('[data-test="home-leaders"]').text()).toContain('Wins')
    expect(wrapper.get('[data-test="home-leaders"]').text()).toContain('3.5')
    expect(wrapper.get('[data-test="leader-section-batting"] h3').text()).toBe('Batting')
    expect(wrapper.get('[data-test="leader-section-pitching"] h3').text()).toBe('Pitching')
    expect(wrapper.get('[data-test="leader-section-batting"]').text()).toContain('Batting WAR')
    expect(wrapper.get('[data-test="leader-section-batting"]').text()).not.toContain('Pitching WAR')
    expect(wrapper.get('[data-test="leader-section-pitching"]').text()).toContain('Pitching WAR')
    expect(wrapper.get('[data-test="leader-section-pitching"]').text()).not.toContain('Batting WAR')
    await wrapper.get('[data-test="leader-league-select"]').setValue('national')
    await flushPromises()
    expect(fetch).toHaveBeenLastCalledWith('/api/home?league=national', expect.objectContaining({ headers: { Accept: 'application/json' } }))
    expect(wrapper.get('[data-test="league-pulse"]').text()).toContain('60-36')
    expect(wrapper.get('[data-test="league-pulse"]').text()).toContain('+105')
    expect(wrapper.get('[data-test="league-pulse"]').text()).toContain('Last 30 games')
    expect(wrapper.get('[data-test="league-pulse"]').text()).toContain('19-11')
    expect(wrapper.findAll('.pulse-team-logo')).toHaveLength(4)
    expect(wrapper.get('.pulse-team-logo').attributes('src')).toBe('/DET.svg')
    expect(wrapper.text()).toContain('Stat Explorer')
  })

  it('shows a retry state when the briefing cannot be loaded', async () => {
    fetch.mockResolvedValueOnce({ ok: false, status: 503 })
    const wrapper = mount(HomeView, { global: { components: { RouterLink } } })
    await flushPromises()

    expect(wrapper.get('[data-test="home-error"]').text()).toContain('Unable to load today’s NineLens briefing')
  })
})
