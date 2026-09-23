import { flushPromises, mount } from '@vue/test-utils'
import { vi } from 'vitest'

import TeamProfileView from '../TeamProfileView.vue'

const RouterLinkStub = {
  name: 'RouterLink',
  props: ['to'],
  template: '<a><slot /></a>',
}

const payload = {
  data: {
    id: 1,
    mlb_id: 116,
    name: 'Detroit Tigers',
    abbreviation: 'DET',
    team_name: 'Tigers',
    location_name: 'Detroit',
    short_name: 'Detroit',
    logo_url: 'https://www.mlbstatic.com/team-logos/116.svg',
    season: 2026,
    available_seasons: [2025, 2026],
    division_rank: { rank: 1, total_teams: 5, games_ahead: 3.5, division: { key: 'al_central', name: 'AL Central' } },
    record: {
      wins: 52, losses: 43, ties: 0, games_played: 95, runs_scored: 430, runs_allowed: 401,
      recent: {
        10: { wins: 7, losses: 3, ties: 0, games_played: 10 },
        30: { wins: 18, losses: 12, ties: 0, games_played: 30 },
        50: { wins: 29, losses: 21, ties: 0, games_played: 50 },
      },
    },
    roster_summary: { total: 40, active: 26, injured: 6, other: 8 },
    roster_as_of: '2026-07-15',
    roster: [
      {
        id: 9,
        roster_status: 'active',
        status_description: 'Active',
        injured: false,
        jersey_number: '31',
        primary_position: 'CF',
        starts_on: '2026-03-26',
        player: { id: 42, mlb_id: 680776, full_name: 'Riley Greene', first_name: 'Riley', last_name: 'Greene', headshot_url: null },
      },
      {
        id: 10,
        roster_status: 'injured_10_day',
        status_description: '10-Day Injured List',
        injured: true,
        jersey_number: '20',
        primary_position: '1B',
        starts_on: '2026-06-01',
        player: { id: 43, mlb_id: 679529, full_name: 'Spencer Torkelson', first_name: 'Spencer', last_name: 'Torkelson', headshot_url: null },
      },
    ],
    rosters: {
      forty_man: [
        {
          id: 9,
          roster_status: 'active',
          status_description: 'Active',
          injured: false,
          jersey_number: '31',
          primary_position: 'CF',
          starts_on: '2026-03-26',
          player: { id: 42, mlb_id: 680776, full_name: 'Riley Greene', first_name: 'Riley', last_name: 'Greene', headshot_url: null },
        },
        {
          id: 10,
          roster_status: 'injured_10_day',
          status_description: '10-Day Injured List',
          injured: true,
          jersey_number: '20',
          primary_position: '1B',
          starts_on: '2026-06-01',
          player: { id: 43, mlb_id: 679529, full_name: 'Spencer Torkelson', first_name: 'Spencer', last_name: 'Torkelson', headshot_url: null },
        },
      ],
      active: [
        {
          id: 9,
          roster_status: 'active',
          status_description: 'Active',
          injured: false,
          jersey_number: '31',
          primary_position: 'CF',
          starts_on: '2026-03-26',
          player: { id: 42, mlb_id: 680776, full_name: 'Riley Greene', first_name: 'Riley', last_name: 'Greene', headshot_url: null },
        },
      ],
    },
    recent_games: [
      { id: 80, official_date: '2026-07-14', home_score: 5, away_score: 2, home_team: { id: 1, abbreviation: 'DET' }, away_team: { id: 2, abbreviation: 'CLE' } },
    ],
    upcoming_games: [
      {
        id: 81, official_date: '2026-07-16', venue_name: 'Comerica Park', home_score: null, away_score: null,
        home_team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' },
        away_team: { id: 2, mlb_id: 114, name: 'Cleveland Guardians', abbreviation: 'CLE' },
        home_probable_pitcher: { id: 51, full_name: 'Tarik Skubal' },
        away_probable_pitcher: { id: 52, full_name: 'Tanner Bibee' },
      },
      {
        id: 82, official_date: '2026-07-17', venue_name: 'Comerica Park', home_score: null, away_score: null,
        home_team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' },
        away_team: { id: 2, mlb_id: 114, name: 'Cleveland Guardians', abbreviation: 'CLE' },
        home_probable_pitcher: { id: 53, full_name: 'Jack Flaherty' },
        away_probable_pitcher: null,
      },
      {
        id: 83, official_date: '2026-07-18', venue_name: 'Comerica Park', home_score: null, away_score: null,
        home_team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' },
        away_team: { id: 3, mlb_id: 145, name: 'Chicago White Sox', abbreviation: 'CWS' },
        home_probable_pitcher: { id: 54, full_name: 'Casey Mize' },
        away_probable_pitcher: { id: 55, full_name: 'Garrett Crochet' },
      },
    ],
    schedule_games: [
      {
        id: 80, official_date: '2026-07-14', scheduled_at: '2026-07-14T23:10:00Z',
        status: 'final', detailed_status: 'Final', home_score: 5, away_score: 2,
        home_team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', team_name: 'Tigers', abbreviation: 'DET' },
        away_team: { id: 2, mlb_id: 114, name: 'Cleveland Guardians', team_name: 'Guardians', abbreviation: 'CLE' },
      },
      {
        id: 81, official_date: '2026-07-16', scheduled_at: '2026-07-16T23:10:00Z',
        status: 'scheduled', detailed_status: 'Scheduled', home_score: null, away_score: null,
        home_team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', team_name: 'Tigers', abbreviation: 'DET' },
        away_team: { id: 2, mlb_id: 114, name: 'Cleveland Guardians', team_name: 'Guardians', abbreviation: 'CLE' },
      },
      {
        id: 84, official_date: '2026-08-18', scheduled_at: '2026-08-18T23:10:00Z',
        status: 'scheduled', detailed_status: 'Scheduled', home_score: null, away_score: null,
        home_team: { id: 2, mlb_id: 114, name: 'Cleveland Guardians', team_name: 'Guardians', abbreviation: 'CLE' },
        away_team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', team_name: 'Tigers', abbreviation: 'DET' },
      },
    ],
    player_stats: {
      season: 2026,
      batting: {
        columns: [
          { key: 'gamesPlayed', label: 'G' },
          { key: 'homeRuns', label: 'HR' },
          { key: 'avg', label: 'AVG' },
        ],
        players: [
          {
            player: { id: 42, full_name: 'Riley Greene', first_name: 'Riley', last_name: 'Greene', headshot_url: null },
            stats: { gamesPlayed: '95', homeRuns: '24', avg: '.287' },
          },
        ],
      },
      pitching: {
        columns: [
          { key: 'W', label: 'W' },
          { key: 'ERA', label: 'ERA' },
          { key: 'strikeOuts', label: 'SO' },
        ],
        players: [
          {
            player: { id: 51, full_name: 'Tarik Skubal', first_name: 'Tarik', last_name: 'Skubal', headshot_url: null },
            stats: { W: '11', ERA: '2.01', strikeOuts: '162' },
          },
        ],
      },
    },
    team_stats: {
      season: 2026,
      batting: {
        columns: [{ key: 'homeRuns', label: 'HR' }, { key: 'ops', label: 'OPS' }],
        teams: [{ team: { id: 1, name: 'Detroit Tigers', league: 'AL' }, stats: { homeRuns: '150.0', ops: '0.750' } }],
      },
      pitching: {
        columns: [{ key: 'ERA', label: 'ERA' }],
        teams: [{ team: { id: 1, name: 'Detroit Tigers', league: 'AL' }, stats: { ERA: '3.50' } }],
      },
    },
    team_stats_summary: {
      season: 2026,
      batting: { avg: { value: '.242', rank: 20 }, homeRuns: { value: 154, rank: 18 } },
      pitching: { ERA: { value: '3.50', rank: 12 } },
    },
    opponent_preparation: {
      opponent: { id: 2, mlb_id: 114, name: 'Cleveland Guardians', abbreviation: 'CLE' },
      recent_performance: { games: 10, wins: 7, losses: 3, runs_per_game: 4.8, ops: 0.781, era: 3.42 },
      probable_starters: [
        {
          player: { id: 52, mlb_id: 999001, full_name: 'Tanner Bibee' },
          throws: 'R',
          sample_size: 200,
          repertoire: [
            {
              pitch_type: 'FF', pitch_name: '4-Seam Fastball', count: 100, usage_percentage: 50,
              average_velocity: 95.6, horizontal_break: -7.2, vertical_break: 14.4,
              evidence: [{ game_id: 80, pitch_id: 1001, plate_appearance_id: 901, pitch_name: '4-Seam Fastball', velocity: 96.1, result: 'swinging_strike' }],
            },
          ],
          handedness_splits: [
            {
              batter_hand: 'L', pitches: 100, plate_appearances: 24, strikeout_rate: 29.2, whiff_rate: 31.5,
              evidence: [{ game_id: 80, pitch_id: 1001, plate_appearance_id: 901, pitch_name: '4-Seam Fastball', velocity: 96.1 }],
            },
            { batter_hand: 'R', pitches: 100, plate_appearances: 25, strikeout_rate: 24, whiff_rate: 27.2, evidence: [] },
          ],
          recent_changes: [
            {
              key: 'velocity', label: 'Average velocity', change: 1.2, unit: 'mph',
              evidence: [{ game_id: 80, pitch_id: 1001, plate_appearance_id: 901, pitch_name: '4-Seam Fastball', velocity: 96.1 }],
            },
          ],
          evidence: [],
        },
      ],
    },
    opponent_reports: [
      {
        id: 301,
        title: 'DET vs CLE · Jul 16–Jul 17, 2026',
        season: 2026,
        series_starts_on: '2026-07-16',
        series_ends_on: '2026-07-17',
        generated_at: '2026-07-15T14:00:00Z',
        opponent: { id: 2, mlb_id: 114, name: 'Cleveland Guardians', abbreviation: 'CLE' },
        probable_starter_count: 1,
      },
    ],
    lineup_scenarios: [
      {
        id: 401,
        name: 'Vs RHP — opener',
        scenario_date: '2026-07-16',
        validated_at: '2026-07-15T14:00:00Z',
        entry_count: 9,
        total_score: 78.4,
        evaluation_inputs: { opponent: 'Cleveland Guardians', pitcher_hand: 'R', park_factor: 105 },
        score_breakdown: { opponent: 35, park: 25, platoon: 75, recent_performance: 82, reliability: 88 },
      },
    ],
    source_metadata: { last_updated_at: '2026-07-15T12:00:00Z', schedule_last_synced_at: '2026-07-15T12:00:00Z', roster_last_synced_at: '2026-07-15T11:00:00Z', sources: ['MLB Stats API'] },
    team_leaders: {
      batting: [
        { key: 'avg', label: 'Batting average', abbreviation: 'AVG', value: '0.287', player: { id: 42, full_name: 'Riley Greene', first_name: 'Riley', last_name: 'Greene', headshot_url: null } },
        { key: 'ops', label: 'On-base plus slugging', abbreviation: 'OPS', value: '0.842', player: { id: 42, full_name: 'Riley Greene', first_name: 'Riley', last_name: 'Greene', headshot_url: null } },
        { key: 'WAR', label: 'Wins above replacement', abbreviation: 'WAR', value: '4.2', player: { id: 42, full_name: 'Riley Greene', first_name: 'Riley', last_name: 'Greene', headshot_url: null } },
        { key: 'homeRuns', label: 'Home runs', abbreviation: 'HR', value: '24', player: { id: 43, full_name: 'Spencer Torkelson', first_name: 'Spencer', last_name: 'Torkelson', headshot_url: null } },
        { key: 'rbi', label: 'Runs batted in', abbreviation: 'RBI', value: '68', player: { id: 42, full_name: 'Riley Greene', first_name: 'Riley', last_name: 'Greene', headshot_url: null } },
      ],
      pitching: [
        { key: 'W', label: 'Wins', abbreviation: 'W', value: '11', player: { id: 51, full_name: 'Tarik Skubal', first_name: 'Tarik', last_name: 'Skubal', headshot_url: null } },
        { key: 'ERA', label: 'Earned run average', abbreviation: 'ERA', value: '2.01', player: { id: 51, full_name: 'Tarik Skubal', first_name: 'Tarik', last_name: 'Skubal', headshot_url: null } },
        { key: 'whip', label: 'Walks and hits per inning', abbreviation: 'WHIP', value: '0.99', player: { id: 51, full_name: 'Tarik Skubal', first_name: 'Tarik', last_name: 'Skubal', headshot_url: null } },
        { key: 'WAR', label: 'Wins above replacement', abbreviation: 'WAR', value: '5.6', player: { id: 51, full_name: 'Tarik Skubal', first_name: 'Tarik', last_name: 'Skubal', headshot_url: null } },
        { key: 'strikeOuts', label: 'Strikeouts', abbreviation: 'SO', value: '162', player: { id: 51, full_name: 'Tarik Skubal', first_name: 'Tarik', last_name: 'Skubal', headshot_url: null } },
      ],
    },
    performance_dashboard: {
      rankings: {
        offense: {
          ops: { rank: 5, value: 0.765 },
          runs_per_game: { rank: 8, value: 4.5 },
          home_runs: { rank: 6, value: 132 },
          batting_average: { rank: 7, value: 0.261 },
          stolen_bases: { rank: 11, value: 68 },
          strikeout_rate: { rank: 12, value: 0.219 },
          walk_rate: { rank: 9, value: 0.086 },
        },
        pitching: {
          era: { rank: 7, value: 3.8126 },
          whip: { rank: 10, value: 1.2346 },
          saves: { rank: 4, value: 31 },
          strikeouts: { rank: 3, value: 902 },
          quality_starts: { rank: 8, value: 44 },
          strikeout_rate: { rank: 6, value: 0.251 },
          walk_rate: { rank: 11, value: 0.082 },
        },
        context: { total_teams: 30 },
      },
      recent_form: {
        '7': { wins: 5, losses: 2, home_runs: 11, runs_per_game: 5.14, ops: 0.791, era: 3.43 },
        '15': { wins: 9, losses: 6, home_runs: 23, runs_per_game: 4.87, ops: 0.768, era: 3.76 },
        '30': { wins: 17, losses: 13, home_runs: 41, runs_per_game: 4.63, ops: 0.751, era: 3.92 },
      },
      home_road_splits: {
        home: { wins: 27, losses: 19, run_differential: 22 },
        road: { wins: 25, losses: 24, run_differential: 7 },
      },
      platoon_splits: {
        offense: {
          vs_left: { strikeout_rate: 0.244, average_exit_velocity: 90.2 },
          vs_right: { strikeout_rate: 0.211, average_exit_velocity: 91.0 },
        },
        pitching: {
          vs_left: { strikeout_rate: 0.257, average_velocity: 94.1 },
          vs_right: { strikeout_rate: 0.245, average_velocity: 94.4 },
        },
      },
      starter_bullpen: {
        starters: { innings_pitched: 520.1, era: 3.61, whip: 1.18 },
        bullpen: { innings_pitched: 336.2, era: 4.13, whip: 1.31 },
      },
      one_run_performance: { wins: 14, losses: 11, games: 25, winning_percentage: 0.56 },
      analytics_coverage: {
        complete: true,
        completed_game_count: 95,
        complete_pitching_game_count: 95,
        missing_game_count: 0,
        missing_games: [],
      },
      strengths: ['Top-10 offense by OPS'],
      concerns: ['Offense has cooled over the last 30 games'],
    },
  },
}

describe('TeamProfileView', () => {
  it('generates a frozen report from the current opponent preparation', async () => {
    const fetchMock = vi.fn().mockImplementation((url, options = {}) => {
      if (url === '/api/teams') return Promise.resolve({ ok: true, json: async () => ({ data: [{ id: 2, name: 'Cleveland Guardians', abbreviation: 'CLE' }] }) })
      if (url === '/api/teams/1/opponent_reports') return Promise.resolve({ ok: true, json: async () => ({ data: { id: 302 } }) })
      return Promise.resolve({ ok: true, json: async () => payload })
    })
    vi.stubGlobal('fetch', fetchMock)
    const wrapper = mount(TeamProfileView, {
      props: { teamId: '1' },
      global: { stubs: { RouterLink: RouterLinkStub } },
    })
    await flushPromises()

    await wrapper.get('[data-test="save-opponent-report"]').trigger('click')
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/teams/1/opponent_reports',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ season: 2026 }),
      }),
    )
    expect(fetchMock).toHaveBeenCalledWith('/api/teams/1?include=overview&season=2026', expect.any(Object))
  })

  it('renders the overview and opens a separate roster tab on the active roster', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))
    const wrapper = mount(TeamProfileView, {
      props: { teamId: '1' },
      global: { stubs: { RouterLink: RouterLinkStub } },
    })
    await flushPromises()

    expect(wrapper.text()).toContain("Detroit Tigers")
    expect(wrapper.get('.team-hero').attributes('style')).toContain('--profile-team-primary: #0c2340')
    expect(wrapper.get('.team-hero__pattern').exists()).toBe(true)
    const externalLinks = wrapper.findAll(".team-external-links a")
    expect(externalLinks).toHaveLength(4)
    expect(externalLinks.map((link) => link.attributes("href"))).toEqual([
      "https://baseballsavant.mlb.com/team/116",
      "https://www.mlb.com/tigers",
      "https://www.baseball-reference.com/teams/DET/2026.shtml",
      "https://www.fangraphs.com/teams/tigers",
    ])
    expect(externalLinks.every((link) => link.attributes("target") === "_blank" && link.attributes("rel") === "noopener noreferrer")).toBe(true)
    expect(wrapper.text()).toContain('52–43')
    expect(wrapper.get('[data-test="division-rank"]').text()).toContain('#1')
    expect(wrapper.get('[data-test="division-rank"]').text()).toContain('AL Central')
    expect(wrapper.get('[data-test="division-rank"]').text()).toContain('3.5 games ahead')
    expect(wrapper.get('[data-test="team-stat-summary"]').text()).toContain('.242')
    expect(wrapper.get('[data-test="team-stat-summary"]').text()).toContain('#20')
    expect(wrapper.get('[aria-label="Season summary"]').text()).toContain('Last 10')
    expect(wrapper.get('[aria-label="Season summary"]').text()).toContain('7–3')
    expect(wrapper.get('[aria-label="Season summary"]').text()).toContain('18–12')
    expect(wrapper.get('[aria-label="Season summary"]').text()).toContain('29–21')
    expect(wrapper.get('[data-test="upcoming-games"]').text()).toContain('Tarik Skubal')
    expect(wrapper.get('[data-test="recent-games"]').text()).toContain('5–2')
    expect(wrapper.get('[data-test="recent-games"] .game-result-link').exists()).toBe(true)
    const opponentPrep = wrapper.get('[data-test="opponent-preparation"]')
    expect(opponentPrep.text()).toContain('Cleveland Guardians')
    expect(opponentPrep.text()).toContain('Jul 16, 2026 – Jul 17, 2026')
    expect(opponentPrep.text()).toContain('Tarik Skubal')
    expect(opponentPrep.text()).toContain('Tanner Bibee')
    expect(opponentPrep.text()).toContain('Jack Flaherty')
    expect(opponentPrep.text()).toContain('TBD')
    expect(opponentPrep.text()).not.toContain('Garrett Crochet')
    expect(wrapper.findAll('[data-test^="opponent-series-game-"]')).toHaveLength(2)
    expect(wrapper.getComponent('[data-test="opponent-probable-81"]').props('to')).toEqual({
      name: 'player-profile',
      params: { id: 52 },
    })
    expect(wrapper.get('[data-test="opponent-recent-performance"]').text()).toContain('7–3')
    expect(wrapper.get('[data-test="opponent-report-history"]').text()).toContain('DET vs CLE')
    expect(wrapper.getComponent('[data-test="opponent-report-301"]').props('to')).toEqual({
      name: 'opponent-report',
      params: { id: 301 },
    })
    expect(wrapper.get('[data-test="lineup-scenarios"]').text()).toContain('Lineup scenarios')
    expect(wrapper.get('[data-test="lineup-scenarios"]').text()).toContain('Vs RHP — opener')
    expect(wrapper.get('[data-test="lineup-evaluation-inputs"]').text()).toContain('Evaluation context')
    expect(wrapper.get('[data-test="lineup-score-comparison"]').text()).toContain('78.4/100')
    expect(wrapper.get('[data-test="lineup-score-comparison"]').text()).toContain('Platoon 75')
    expect(wrapper.findAll('[data-test^="lineup-row-"]')).toHaveLength(9)
    const starterScouting = wrapper.get('[data-test="starter-scouting-52"]')
    expect(starterScouting.text()).toContain('4-Seam Fastball')
    expect(starterScouting.text()).toContain('95.6 mph')
    expect(starterScouting.text()).toContain('-7.2 in')
    expect(starterScouting.text()).toContain('vs LHB')
    expect(starterScouting.text()).toContain('+1.2 mph')
    const evidenceLink = wrapper.getComponent('.evidence-link')
    expect(evidenceLink.props('to')).toEqual({
      name: 'game-summary',
      params: { id: 80 },
      hash: '#pitch-1001',
    })
    expect(wrapper.get('[data-test="team-profile-tab-overview"]').attributes('aria-selected')).toBe('true')
    expect(wrapper.get('[data-test="team-profile-panel-overview"]').attributes('style') || '').not.toContain('display: none')
    expect(wrapper.get('[data-test="team-profile-panel-roster"]').attributes('style')).toContain('display: none')
    expect(wrapper.get('[data-test="team-profile-panel-opponent"]').attributes('style')).toContain('display: none')
    expect(wrapper.get('[data-test="team-profile-panel-lineup"]').attributes('style')).toContain('display: none')

    await wrapper.get('[data-test="team-profile-tab-opponent"]').trigger('click')
    expect(wrapper.get('[data-test="team-profile-panel-opponent"]').attributes('style') || '').not.toContain('display: none')
    expect(wrapper.get('[data-test="team-profile-panel-overview"]').attributes('style')).toContain('display: none')

    await wrapper.get('[data-test="team-profile-tab-lineup"]').trigger('click')
    expect(wrapper.get('[data-test="team-profile-panel-lineup"]').attributes('style') || '').not.toContain('display: none')
    expect(wrapper.get('[data-test="team-profile-panel-opponent"]').attributes('style')).toContain('display: none')

    await wrapper.get('[data-test="team-profile-tab-roster"]').trigger('click')

    expect(wrapper.get('[data-test="team-profile-tab-roster"]').attributes('aria-selected')).toBe('true')
    expect(wrapper.get('[data-test="team-profile-panel-overview"]').attributes('style')).toContain('display: none')
    expect(wrapper.get('[data-test="team-profile-panel-roster"]').attributes('style') || '').not.toContain('display: none')
    expect(wrapper.get('[data-test="team-roster"]').text()).toContain('Riley Greene')
    expect(wrapper.get('[data-test="team-roster"]').text()).toContain('CF')
    expect(wrapper.get('[data-test="team-roster"]').text()).not.toContain('Spencer Torkelson')
    expect(wrapper.get('[data-test="team-depth-chart"]').text()).toContain('Outfield')
    expect(wrapper.get('[data-test="team-depth-chart"]').text()).toContain('Riley Greene')
    expect(wrapper.get('[data-test="roster-view-active"]').attributes('aria-pressed')).toBe('true')
    expect(wrapper.get('[data-test="roster-view-40man"]').text()).toContain('2')
    expect(wrapper.get('[data-test="roster-view-active"]').text()).toContain('1')
    expect(wrapper.get('[data-test="roster-view-injured"]').text()).toContain('1')

    await wrapper.get('[data-test="roster-view-injured"]').trigger('click')

    expect(wrapper.get('[data-test="roster-view-injured"]').attributes('aria-pressed')).toBe('true')
    expect(wrapper.get('[data-test="team-roster"]').text()).toContain('Spencer Torkelson')
    expect(wrapper.get('[data-test="team-roster"]').text()).toContain('10-Day Injured List')
    expect(wrapper.get('[data-test="team-roster"]').text()).not.toContain('Riley Greene')

    await wrapper.get('[data-test="roster-view-40man"]').trigger('click')

    expect(wrapper.get('[data-test="roster-view-40man"]').attributes('aria-pressed')).toBe('true')
    expect(wrapper.get('[data-test="team-roster"]').text()).toContain('Riley Greene')
    expect(wrapper.get('[data-test="team-roster"]').text()).toContain('Spencer Torkelson')
    expect(wrapper.get('[data-test="team-season-select"]').text()).toContain('2025')
    expect(wrapper.get('[data-test="team-performance-dashboard"]').text()).toContain('Team performance dashboard')
    expect(wrapper.get('[data-test="team-performance-dashboard"]').text()).toContain('Last 7 games')
    expect(wrapper.get('[data-test="team-performance-dashboard"]').text()).toContain('HR 11 · R/G 5.14')
    expect(wrapper.get('[data-test="team-performance-dashboard"]').text()).toContain('HR 23 · R/G 4.87')
    expect(wrapper.get('[data-test="team-performance-dashboard"]').text()).toContain('HR 41 · R/G 4.63')
    expect(wrapper.get('[data-test="pitching-ranking-era"]').text()).toContain('3.81')
    expect(wrapper.get('[data-test="pitching-ranking-era"]').text()).toContain('#7')
    expect(wrapper.get('[data-test="pitching-ranking-whip"]').text()).toContain('1.23')
    expect(wrapper.get('[data-test="pitching-ranking-whip"]').text()).toContain('#10')
    expect(wrapper.get('[data-test="pitching-ranking-saves"]').text()).toContain('31')
    expect(wrapper.get('[data-test="pitching-ranking-strikeouts"]').text()).toContain('902')
    expect(wrapper.get('[data-test="pitching-ranking-quality-starts"]').text()).toContain('44')
    expect(wrapper.get('[data-test="offense-ranking-home-runs"]').text()).toContain('132')
    expect(wrapper.get('[data-test="offense-ranking-home-runs"]').text()).toContain('#6')
    expect(wrapper.get('[data-test="offense-ranking-batting-average"]').text()).toContain('0.261')
    expect(wrapper.get('[data-test="offense-ranking-batting-average"]').text()).toContain('#7')
    expect(wrapper.get('[data-test="offense-ranking-stolen-bases"]').text()).toContain('68')
    expect(wrapper.get('[data-test="offense-ranking-stolen-bases"]').text()).toContain('#11')
    expect(wrapper.get('[data-test="team-performance-dashboard"]').text()).toContain('Top-10 offense by OPS')
    const leaders = wrapper.get('[data-test="team-leaders"]')
    expect(leaders.text()).toContain('Team leaders')
    expect(leaders.text()).toContain('Riley Greene')
    expect(leaders.text()).toContain('.287')
    expect(leaders.text()).toContain('Spencer Torkelson')
    expect(leaders.text()).toContain('Tarik Skubal')
    expect(wrapper.get('[data-test="team-leader-ERA"]').text()).toContain('2.01')
    expect(wrapper.get('[data-test="team-leader-ops"]').text()).toContain('.842')
    expect(wrapper.get('[data-test="team-leader-whip"]').text()).toContain('0.99')
    expect(wrapper.get('[data-test="team-leader-WAR"][data-category="batting"]').text()).toContain('4.2')
    expect(wrapper.get('[data-test="team-leader-WAR"][data-category="pitching"]').text()).toContain('5.6')
  })

  it('shows games behind for a team outside first place', async () => {
    const trailingPayload = structuredClone(payload)
    trailingPayload.data.division_rank = {
      rank: 3, total_teams: 5, games_behind: 4.5, division: { key: 'al_central', name: 'AL Central' },
    }
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => trailingPayload }))

    const wrapper = mount(TeamProfileView, { props: { teamId: '1' }, global: { stubs: { RouterLink: true } } })
    await flushPromises()

    expect(wrapper.get('[data-test="division-rank"]').text()).toContain('4.5 games behind')
  })

  it('sizes ranking bars from empty to full using the 30-team comparison', async () => {
    const rankingPayload = structuredClone(payload)
    rankingPayload.data.performance_dashboard.rankings.offense.ops.rank = 1
    rankingPayload.data.performance_dashboard.rankings.offense.runs_per_game.rank = 0
    rankingPayload.data.performance_dashboard.rankings.offense.strikeout_rate.rank = 15
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => rankingPayload }))

    const wrapper = mount(TeamProfileView, {
      props: { teamId: '1' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    const first = wrapper.get('[data-test="offense-ranking-ops"]')
    const unavailable = wrapper.get('[data-test="offense-ranking-runs-per-game"]')
    const middle = wrapper.get('[data-test="offense-ranking-strikeout-rate"]')

    expect(first.get('[role="progressbar"]').attributes('aria-valuenow')).toBe('100')
    expect(first.get('.ranking-bar__fill').attributes('style')).toContain('width: 100%')
    expect(unavailable.get('[role="progressbar"]').attributes('aria-valuenow')).toBe('0')
    expect(unavailable.get('.ranking-bar__fill').attributes('style')).toContain('width: 0%')
    expect(middle.get('[role="progressbar"]').attributes('aria-valuenow')).toBe('50')
    expect(middle.get('.ranking-bar__fill').attributes('style')).toContain('width: 50%')
  })

  it('loads and navigates the monthly team schedule', async () => {
    const overviewPayload = structuredClone(payload)
    delete overviewPayload.data.schedule_games
    vi.stubGlobal('fetch', vi.fn().mockImplementation((url) => Promise.resolve({
      ok: true,
      json: async () => String(url).includes('include=schedule') ? payload : overviewPayload,
    })))
    const wrapper = mount(TeamProfileView, {
      props: { teamId: '1' },
      global: { stubs: { RouterLink: RouterLinkStub } },
    })
    await flushPromises()

    await wrapper.get('[data-test="team-profile-tab-schedule"]').trigger('click')
    await flushPromises()

    expect(fetch).toHaveBeenLastCalledWith(
      '/api/teams/1?include=schedule&season=2026',
      expect.any(Object),
    )
    expect(wrapper.get('[data-test="team-profile-panel-schedule"]').attributes('style') || '').not.toContain('display: none')
    expect(wrapper.get('[data-test="schedule-month-label"]').text()).toBe('August 2026')
    expect(wrapper.get('[data-test="team-schedule-calendar"]').text()).toContain('Sun')
    expect(wrapper.get('[data-test="team-schedule-calendar"]').text()).toContain('Sat')
    expect(wrapper.get('[data-test="schedule-game-84"]').text()).toContain('@')
    expect(wrapper.get('[data-test="schedule-game-84"]').text()).toContain('Guardians')
    expect(wrapper.get('[data-test="schedule-game-84"] img').attributes('src')).toContain('/team-logos/114.svg')

    await wrapper.get('[data-test="schedule-previous-month"]').trigger('click')

    expect(wrapper.get('[data-test="schedule-month-label"]').text()).toBe('July 2026')
    expect(wrapper.get('[data-test="schedule-game-80"]').text()).toContain('W, 5–2')
    expect(wrapper.get('[data-test="schedule-game-81"]').text()).toContain('Guardians')
    expect(wrapper.getComponent('[data-test="schedule-game-80"]').props('to')).toEqual({
      name: 'game-summary',
      params: { id: 80 },
    })
    expect(wrapper.get('[data-test="schedule-previous-month"]').attributes()).toHaveProperty('disabled')
    expect(wrapper.get('[data-test="schedule-next-month"]').attributes()).not.toHaveProperty('disabled')
  })

  it("shows Player Stats and Team Stats tabs in the requested order", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))
    const wrapper = mount(TeamProfileView, {
      props: { teamId: "1" },
      global: { stubs: { RouterLink: RouterLinkStub } },
    })
    await flushPromises()

    expect(wrapper.findAll("[role=tab]").map((tab) => tab.attributes("data-test"))).toEqual([
      "team-profile-tab-overview",
      "team-profile-tab-roster",
      "team-profile-tab-schedule",
      "team-profile-tab-player-stats",
      "team-profile-tab-team-stats",
      "team-profile-tab-opponent",
      "team-profile-tab-lineup",
    ])

    const requestCount = fetch.mock.calls.length
    await wrapper.get("[data-test=team-profile-tab-player-stats]").trigger("click")
    const playerStatsPanel = wrapper.get("[data-test=team-profile-panel-player-stats]")
    expect(playerStatsPanel.text()).toContain("2026 player stats")
    expect(playerStatsPanel.get("[data-test=team-player-stats-batting]").text()).toContain("Riley Greene")
    expect(playerStatsPanel.get("[data-test=team-player-stats-batting]").text()).toContain(".287")
    expect(playerStatsPanel.find("[data-test=team-player-stats-pitching]").exists()).toBe(false)
    await playerStatsPanel.findAll(".team-stats-mode-toggle button")[1].trigger("click")
    expect(playerStatsPanel.get("[data-test=team-player-stats-pitching]").text()).toContain("Tarik Skubal")
    expect(playerStatsPanel.get("[data-test=team-player-stats-pitching]").text()).toContain("2.01")
    expect(playerStatsPanel.find("[data-test=team-player-stats-batting]").exists()).toBe(false)
    expect(playerStatsPanel.attributes("style") || "").not.toContain("display: none")

    await wrapper.get("[data-test=team-profile-tab-team-stats]").trigger("click")
    expect(wrapper.get("[data-test=team-profile-panel-team-stats]").text()).toContain("2026 team stats")
    expect(wrapper.get("[data-test=team-stats-table]").text()).toContain("Detroit Tigers")
    expect(wrapper.get("[data-test=team-stats-table] tbody th").classes()).toContain("is-current-team")
    expect(wrapper.get("[data-test=team-profile-panel-team-stats]").attributes("style") || "").not.toContain("display: none")
    expect(fetch).toHaveBeenCalledTimes(requestCount + 2)
  })

  it('sorts Team Profile player stats and formats count and rate values', async () => {
    const statsPayload = structuredClone(payload)
    statsPayload.data.player_stats.batting.players = [
      {
        player: { id: 42, full_name: 'Riley Greene', first_name: 'Riley', last_name: 'Greene', headshot_url: null },
        stats: { gamesPlayed: '95.0', homeRuns: '24.0', avg: '0.287' },
      },
      {
        player: { id: 43, full_name: 'Aaron Judge', first_name: 'Aaron', last_name: 'Judge', headshot_url: null },
        stats: { gamesPlayed: '100.0', homeRuns: '8.0', avg: '0.310' },
      },
    ]
    statsPayload.data.player_stats.pitching.columns.push({ key: 'whip', label: 'WHIP' })
    statsPayload.data.player_stats.pitching.players[0].stats.whip = '0.99'
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => statsPayload }))
    const wrapper = mount(TeamProfileView, {
      props: { teamId: '1' },
      global: { stubs: { RouterLink: RouterLinkStub } },
    })
    await flushPromises()
    await wrapper.get('[data-test="team-profile-tab-player-stats"]').trigger('click')

    const batting = wrapper.get('[data-test="team-player-stats-batting"]')
    expect(batting.findAll('tbody tr')[0].text()).toContain('Aaron Judge')
    expect(batting.text()).toContain('.310')
    expect(batting.text()).not.toContain('95.0')

    const playerStatsPanel = wrapper.get('[data-test="team-profile-panel-player-stats"]')
    await playerStatsPanel.findAll('.team-stats-mode-toggle button')[1].trigger('click')
    expect(wrapper.get('[data-test="team-player-stats-pitching"]').text()).toContain('0.99')
    await playerStatsPanel.findAll('.team-stats-mode-toggle button')[0].trigger('click')
    const battingTable = wrapper.get('[data-test="team-player-stats-batting"]')

    await battingTable.findAll('thead button').find((button) => button.text().includes('HR')).trigger('click')

    expect(battingTable.findAll('tbody tr')[0].text()).toContain('Riley Greene')
    expect(battingTable.findAll('thead button').find((button) => button.text().includes('HR')).text()).toContain('↓')
  })

  it('reloads the profile for the selected season', async () => {
    const historicalPayload = structuredClone(payload)
    historicalPayload.data.season = 2025
    historicalPayload.data.record = {
      wins: 82,
      losses: 80,
      ties: 0,
      games_played: 162,
      runs_scored: 682,
      runs_allowed: 667,
    }
    historicalPayload.data.performance_dashboard.rankings.offense.ops.value = 0.699

    const fetchMock = vi.fn().mockImplementation(async (url) => ({
      ok: true,
      json: async () => (String(url).includes('season=2025') ? historicalPayload : payload),
    }))
    vi.stubGlobal('fetch', fetchMock)

    const wrapper = mount(TeamProfileView, {
      props: { teamId: '1' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    await wrapper.get('[data-test="team-season-select"]').setValue('2025')
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledWith(
      expect.stringContaining('/api/teams/1?include=overview&season=2025'),
      expect.any(Object),
    )
    expect(wrapper.get('[aria-label="Season summary"]').text()).toContain('2025 record')
    expect(wrapper.get('[aria-label="Season summary"]').text()).toContain('82–80')
    expect(wrapper.get('[data-test="offense-ranking-ops"]').text()).toContain('0.699')
  })

  it('shows a loading indicator while a different season is loading', async () => {
    let resolveHistoricalRequest
    const historicalRequest = new Promise((resolve) => {
      resolveHistoricalRequest = resolve
    })
    const fetchMock = vi.fn().mockImplementation((url) => {
      if (String(url).includes('season=2025')) return historicalRequest

      return Promise.resolve({ ok: true, json: async () => payload })
    })
    vi.stubGlobal('fetch', fetchMock)

    const wrapper = mount(TeamProfileView, {
      props: { teamId: '1' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    await wrapper.get('[data-test="team-season-select"]').setValue('2025')

    expect(wrapper.get('[data-test="season-loading"]').text()).toContain('Loading 2025 season')
    expect(wrapper.get('[data-test="team-season-select"]').attributes()).toHaveProperty('disabled')
    expect(wrapper.get('.team-profile-shell').attributes('aria-busy')).toBe('true')

    resolveHistoricalRequest({ ok: true, json: async () => payload })
    await flushPromises()

    expect(wrapper.find('[data-test="season-loading"]').exists()).toBe(false)
    expect(wrapper.get('[data-test="team-season-select"]').attributes()).not.toHaveProperty('disabled')
  })

  it('renders a retry state when the profile cannot load', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 500 }))
    const wrapper = mount(TeamProfileView, {
      props: { teamId: '1' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    expect(wrapper.get('[data-test="team-error"]').text()).toContain('Unable to load this team profile')
  })

  it('warns when completed games are missing pitching details', async () => {
    const incompletePayload = structuredClone(payload)
    incompletePayload.data.performance_dashboard.analytics_coverage = {
      complete: false,
      completed_game_count: 96,
      complete_pitching_game_count: 95,
      missing_game_count: 1,
      missing_games: [{ mlb_id: 823632, official_date: '2026-05-12', matchup: 'DET at NYM' }],
    }
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => incompletePayload }))

    const wrapper = mount(TeamProfileView, {
      props: { teamId: '1' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    expect(wrapper.get('[data-test="analytics-coverage-warning"]').text()).toContain('1 of 96 completed games is missing pitching details')
  })
})
