import { flushPromises, mount } from '@vue/test-utils'
import { computed, ref } from 'vue'
import { vi } from 'vitest'

import PlayerProfileView from '../PlayerProfile/PlayerProfileView.vue'
import ContextualBenchmarksPanel from '../PlayerProfile/ContextualBenchmarksPanel.vue'
import AddToWatchlistControl from '../../components/AddToWatchlistControl.vue'

function apiPayload() {
  return {
    data: {
      id: 42,
      mlb_id: 680776,
      first_name: 'Riley',
      last_name: 'Greene',
      full_name: 'Riley Greene',
      team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' },
      display_team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' },
      external_ids: { baseball_reference: 'greenri03', fangraphs: '25976' },
      profile: {
        active: true,
        age: 25,
        birth_date: '2000-09-28',
        formatted_height: `6' 3"`,
        weight_pounds: 200,
        bats: 'L',
        throws: 'L',
        draft_year: 2019,
        awards: [
          { id: 'ALSS', name: 'AL Silver Slugger', season: 2025, date: '2025-11-07' },
          { id: 'ALPOW', name: 'AL Player of the Week', season: 2025, date: '2025-05-04' },
        ],
        all_star_selections: [2026, 2025, 2024],
        mlb_debut_date: '2022-06-18',
        headshot_url:
          'https://img.mlbstatic.com/mlb-photos/image/upload/ar_20:23,c_fill,g_north,w_260/c_pad,b_auto:border,w_300,h_300,q_auto:best/v1/people/680776/headshot/67/current',
      },
      positions: {
        primary: { abbreviation: 'CF', name: 'Outfielder' },
        secondary: [],
        assignments: [],
      },
      season_overview: {
        season: 2026,
        category: 'batting',
        mode: 'season',
        preferred_category: 'batting',
        stats: [
          { key: 'homeRuns', label: 'HR', value: '18.0', scope_key: 'DET' },
          { key: 'WAR', label: 'WAR', value: '3.2', scope_key: 'DET' },
          { key: 'ops', label: 'OPS', value: '0.842', scope_key: 'DET' },
        ],
      },
      career_overview: {
        category: 'batting',
        preferred_category: 'batting',
        first_season: 2022,
        last_season: 2026,
        season_count: 5,
        columns: [
          { key: 'gamesPlayed', label: 'G' },
          { key: 'homeRuns', label: 'HR' },
          { key: 'ops', label: 'OPS' },
          { key: 'WAR', label: 'WAR' },
        ],
        seasons: [
          {
            season: 2025,
            batted_ball_count: 100,
            ground_ball_percentage: 46.2,
            fly_ball_percentage: 29.1,
            ground_ball_to_fly_ball_ratio: 1.59,
            line_drive_percentage: 24.7,
            infield_fly_percentage: 10.1,
            pull_percentage: 35.4,
            hard_hit_percentage: 36.2,
            barrel_percentage: 8.1,
            home_run_per_fly_ball: 12.8,
            average_launch_angle: 10.6,
          },
          {
            season: 2022,
            teams: [{ id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' }],
            stats: [
              { key: 'gamesPlayed', label: 'G', value: '93' },
              { key: 'homeRuns', label: 'HR', value: '5' },
              { key: 'ops', label: 'OPS', value: '0.740' },
              { key: 'WAR', label: 'WAR', value: '2.1' },
            ],
          },
          {
            season: 2026,
            teams: [{ id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' }],
            stats: [
              { key: 'gamesPlayed', label: 'G', value: '120' },
              { key: 'homeRuns', label: 'HR', value: '18' },
              { key: 'ops', label: 'OPS', value: '0.842' },
              { key: 'WAR', label: 'WAR', value: '3.2' },
            ],
          },
        ],
        stats: [
          { key: 'gamesPlayed', label: 'G', value: '590' },
          { key: 'homeRuns', label: 'HR', value: '82' },
          { key: 'ops', label: 'OPS', value: '0.821' },
          { key: 'WAR', label: 'WAR', value: '12.4' },
        ],
      },
      advanced_stats: {
        category: 'batting',
        groups: [
          {
            key: 'rate_statistics',
            label: 'Rate statistics',
            columns: [
              { key: 'bb_percentage', label: 'BB%', unit: 'percent' },
              { key: 'k_percentage', label: 'K%', unit: 'percent' },
              { key: 'bb_per_k', label: 'BB/K', unit: 'ratio' },
              { key: 'iso', label: 'ISO', unit: 'rate' },
              { key: 'babip', label: 'BABIP', unit: 'rate' },
              { key: 'hr_per_fly_ball', label: 'HR/FB%', unit: 'percent' },
            ],
          },
          {
            key: 'run_creation_value',
            label: 'Run Creation & Value',
            columns: [
              { key: 'woba', label: 'wOBA', unit: 'rate' },
              { key: 'wrc_plus', label: 'wRC+', unit: 'index' },
              { key: 'ops_plus', label: 'OPS+', unit: 'index' },
              { key: 'offensive_runs', label: 'Offensive Runs', unit: 'runs' },
              { key: 'baserunning_runs', label: 'Baserunning Runs', unit: 'runs' },
              { key: 'defensive_value', label: 'Defensive Value', unit: 'runs' },
              { key: 'war', label: 'WAR', unit: 'war' },
            ],
          },
          {
            key: 'batted_ball_profile',
            label: 'Batted-ball profile',
            columns: [
              { key: 'ground_ball_percentage', label: 'GB%', unit: 'percent' },
              { key: 'fly_ball_percentage', label: 'FB%', unit: 'percent' },
              { key: 'line_drive_percentage', label: 'LD%', unit: 'percent' },
              { key: 'pull_percentage', label: 'Pull%', unit: 'percent' },
              { key: 'center_percentage', label: 'Center%', unit: 'percent' },
              { key: 'opposite_field_percentage', label: 'Opposite-field%', unit: 'percent' },
            ],
          },
          {
            key: 'plate_discipline',
            label: 'Plate discipline',
            columns: [
              { key: 'swing_percentage', label: 'Swing%', unit: 'percent' },
              { key: 'chase_percentage', label: 'Chase%', unit: 'percent' },
              { key: 'contact_percentage', label: 'Contact%', unit: 'percent' },
              { key: 'zone_contact_percentage', label: 'Zone Contact%', unit: 'percent' },
              { key: 'swinging_strike_percentage', label: 'SwStr%', unit: 'percent' },
            ],
          },
        ],
        seasons: [
          {
            season: 2022,
            teams: [{ id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' }],
            values: { bb_percentage: 0.086, k_percentage: 0.287, bb_per_k: 0.3, iso: 0.141, babip: 0.354, hr_per_fly_ball: 0.238, woba: 0.326, wrc_plus: 98, ops_plus: 101, offensive_runs: -0.8, baserunning_runs: 0.4, defensive_value: 1.2, war: 1.0, ground_ball_percentage: 0.421, fly_ball_percentage: 0.355, line_drive_percentage: 0.224, pull_percentage: 0.401, center_percentage: 0.347, opposite_field_percentage: 0.252, swing_percentage: 0.521, chase_percentage: 0.298, contact_percentage: 0.741, zone_contact_percentage: 0.812, swinging_strike_percentage: 0.135 },
          },
          {
            season: 2026,
            teams: [{ id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' }],
            values: { bb_percentage: 0.102, k_percentage: 0.241, bb_per_k: 0.42, iso: 0.218, babip: 0.331, hr_per_fly_ball: 0.2778, woba: 0.368, wrc_plus: 132, ops_plus: 128, offensive_runs: 18.4, baserunning_runs: 1.7, defensive_value: -2.3, war: 4.6, ground_ball_percentage: 0.389, fly_ball_percentage: 0.401, line_drive_percentage: 0.21, pull_percentage: 0.428, center_percentage: 0.321, opposite_field_percentage: 0.251, swing_percentage: 0.487, chase_percentage: 0.263, contact_percentage: 0.782, zone_contact_percentage: 0.845, swinging_strike_percentage: 0.106 },
          },
        ],
        career: {
          values: { bb_percentage: 0.094, k_percentage: 0.262, bb_per_k: 0.36, iso: 0.181, babip: 0.342, hr_per_fly_ball: 0.2632, woba: 0.348, wrc_plus: 115, ops_plus: 114, offensive_runs: 17.6, baserunning_runs: 2.1, defensive_value: -1.1, war: 5.6, ground_ball_percentage: 0.4, fly_ball_percentage: 0.385, line_drive_percentage: 0.215, pull_percentage: 0.417, center_percentage: 0.331, opposite_field_percentage: 0.252, swing_percentage: 0.499, chase_percentage: 0.276, contact_percentage: 0.768, zone_contact_percentage: 0.833, swinging_strike_percentage: 0.116 },
        },
      },
      similar_players: {
        season: 2026,
        category: 'batting',
        methodology: 'Standardized same-season statistical distance with a position-role adjustment.',
        position_mismatch_penalty: 0.35,
        controls: {
          available_seasons: [2026, 2025, 2024],
          mode: 'season',
          selected_season: 2026,
          min_age: null,
          max_age: null,
          target_age: 25,
          position_match: 'any',
          position_options: [
            { value: 'any', label: 'Any position' },
            { value: 'same_type', label: 'Same position group' },
            { value: 'same_position', label: 'Same primary position' },
          ],
        },
        model_metrics: [
          { key: 'avg', label: 'AVG', weight: 0.1 },
          { key: 'ops', label: 'OPS', weight: 0.2 },
          { key: 'hr_rate', label: 'HR / PA', weight: 0.15 },
        ],
        matches: [
          {
            player: {
              id: 84,
              mlb_id: 666185,
              full_name: 'Julio Rodríguez',
              headshot_url: null,
            },
            team: { id: 12, mlb_id: 136, name: 'Seattle Mariners', abbreviation: 'SEA' },
            position: { abbreviation: 'CF', name: 'Center Fielder', position_type: 'outfielder' },
            similarity_score: 91.4,
            shared_metric_count: 8,
            same_position_type: true,
            why_similar: [
              'Closest statistical alignment: AVG, HR / PA, and OPS.',
              'Same position group: Outfielder.',
            ],
            metrics_used: [
              { key: 'ops', label: 'OPS', target_value: 0.842, candidate_value: 0.835, weight: 0.2, normalized_weight: 0.4444, standardized_difference: 0.1 },
              { key: 'hr_rate', label: 'HR / PA', target_value: 4.1, candidate_value: 4.0, weight: 0.15, normalized_weight: 0.3333, standardized_difference: 0.2 },
              { key: 'avg', label: 'AVG', target_value: 0.281, candidate_value: 0.278, weight: 0.1, normalized_weight: 0.2222, standardized_difference: 0.15 },
            ],
            closest_metrics: [
              { key: 'avg', label: 'AVG', target_value: 0.281, candidate_value: 0.278 },
              { key: 'hr_rate', label: 'HR / PA', target_value: 4.1, candidate_value: 4.0 },
              { key: 'ops', label: 'OPS', target_value: 0.842, candidate_value: 0.835 },
            ],
          },
        ],
      },
      current_membership: {
        id: 8,
        team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' },
        starts_on: '2026-03-26',
        roster_status: 'active',
        source_status_description: 'Active',
        jersey_number: '31',
      },
      team_history: [
        {
          id: 8,
          team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' },
          starts_on: '2026-03-26',
          current: true,
          roster_status: 'active',
          source_status_description: 'Active',
        },
      ],
      recent_pitch_indicators: {
        sample_size: 100,
        primary_role: 'batter',
        batting: {
          pitches_seen: 100,
          game_count: 8,
          batted_ball_count: 22,
          average_exit_velocity: 91.2,
          max_exit_velocity: 109.5,
          hard_hit_percentage: 45.5,
        },
        pitching: { pitch_count: 0, game_count: 0 },
      },
      batted_ball_profile: {
        available: true,
        contact_count: 3,
        spray_points: [
          { x: 95, y: 125, event: 'single', batted_ball_type: 'ground_ball', exit_velocity: 98.4, hit_distance: 287, game_date: '2026-07-14' },
          { x: 145, y: 105, event: 'field_out', batted_ball_type: 'fly_ball', exit_velocity: 101.2, game_date: '2026-07-12' },
          { x: 175, y: 75, event: 'home_run', batted_ball_type: 'fly_ball', exit_velocity: 109.4, game_date: '2026-07-10' },
        ],
        hit_points: [
          { x: 95, y: 125, event: 'single', batted_ball_type: 'ground_ball', exit_velocity: 98.4, game_date: '2026-07-14' },
          { x: 175, y: 75, event: 'home_run', batted_ball_type: 'fly_ball', exit_velocity: 109.4, game_date: '2026-07-10' },
        ],
      },
      contextual_benchmarks: {
        available: true,
        source_start_date: '2026-03-26',
        source_end_date: '2026-07-14',
        calculation_version: '1.0.0',
        metrics: [
          {
            metric_key: 'ops',
            metric_group: 'batting',
            display_name: 'OPS',
            unit: 'rate',
            raw_value: 0.842,
            mlb_average: 0.72,
            position_average: 0.745,
            position_key: 'CF',
            percentile: 82.5,
            sample_size: 480,
            mlb_player_count: 280,
          },
          {
            metric_key: 'batter_strikeout_percentage',
            metric_group: 'batting',
            display_name: 'K%',
            unit: 'percent',
            raw_value: 21.7,
            mlb_average: 22.5,
            position_average: 23.1,
            position_key: 'CF',
            percentile: 55,
            sample_size: 480,
            mlb_player_count: 280,
          },
          {
            metric_key: 'batter_walk_percentage',
            metric_group: 'batting',
            display_name: 'BB%',
            unit: 'percent',
            raw_value: 9.8,
            mlb_average: 8.4,
            position_average: 8.1,
            position_key: 'CF',
            percentile: 66,
            sample_size: 480,
            mlb_player_count: 280,
          },
          {
            metric_key: 'average_exit_velocity',
            metric_group: 'batting',
            display_name: 'Average exit velocity',
            unit: 'mph',
            raw_value: 91.2,
            mlb_average: 88.4,
            position_average: 89.1,
            position_key: 'CF',
            percentile: 74,
            sample_size: 224,
            mlb_player_count: 280,
          },
          {
            metric_key: 'maximum_exit_velocity',
            metric_group: 'batting',
            display_name: 'Max exit velocity',
            unit: 'mph',
            raw_value: 111.2,
            mlb_average: 109.3,
            position_average: 109.6,
            position_key: 'CF',
            percentile: 77,
            sample_size: 224,
            mlb_player_count: 280,
          },
          {
            metric_key: 'barrel_percentage',
            metric_group: 'batting',
            display_name: 'Barrel rate',
            unit: 'percent',
            raw_value: 14.7,
            mlb_average: 7.8,
            position_average: 8.2,
            position_key: 'CF',
            percentile: 92,
            sample_size: 224,
            mlb_player_count: 280,
          },
          {
            metric_key: 'average_bat_speed',
            metric_group: 'batting',
            display_name: 'Bat speed',
            unit: 'mph',
            raw_value: 75.6,
            mlb_average: 72.1,
            position_average: 72.5,
            position_key: 'CF',
            percentile: 90,
            sample_size: 421,
            mlb_player_count: 280,
          },
        ],
      },
      trend_events: {
        active_count: 1,
        events: [
          {
            id: 17,
            event_type: 'chase_rate_movement',
            role: 'batter',
            metric_key: 'chase_percentage',
            direction: 'increase',
            severity: 'warning',
            status: 'active',
            unit: 'percentage_points',
            baseline_value: 24,
            current_value: 34,
            change_value: 10,
            threshold_value: 8,
            thresholds: { warning: 8, critical: 15 },
            baseline_sample_size: 30,
            sample_size: 32,
            onset_date: '2026-07-01',
            supporting_pitches: [{ game_pk: 123, pitch_number: 4 }],
          },
        ],
      },
      analysis: {
        range: {
          preset: 'season',
          start_date: '2026-01-01',
          end_date: '2026-07-14',
          previous_start_date: '2025-06-20',
          previous_end_date: '2025-12-31',
          plate_appearance_window: 50,
          pitch_window: 100,
        },
        summary: {
          current: {
            batting: { average_exit_velocity: 91.2, hard_hit_percentage: 45.5, whiff_percentage: 24.0, chase_percentage: 28.0 },
            pitching: { average_velocity: null, whiff_percentage: null, chase_percentage: null },
          },
          previous: {
            batting: { average_exit_velocity: 89.8, hard_hit_percentage: 40.0, whiff_percentage: 26.0, chase_percentage: 30.0 },
            pitching: { average_velocity: null, whiff_percentage: null, chase_percentage: null },
          },
          changes: {},
        },
        batting: {
          window_type: 'plate_appearances',
          window_size: 50,
          total_observations: 480,
          charts: [
            {
              key: 'exit_velocity', title: 'Exit velocity', unit: 'mph',
              series: [{ key: 'exit_velocity', label: 'Exit velocity', points: [
                { date: '2026-04-01', sequence: 1, value: 89.0, sample_size: 1 },
                { date: '2026-07-14', sequence: 480, value: 91.2, sample_size: 18 },
              ] }],
            },
          ],
        },
        pitching: { window_type: 'pitches', window_size: 100, total_observations: 0, charts: [] },
      },
      source_metadata: {
        last_updated_at: '2026-07-14T12:00:00Z',
        sources: ['MLB Stats API', 'Baseball Savant'],
        datasets: [
          { name: 'profile', source_name: 'MLB Stats API', last_updated_at: '2026-07-14T12:00:00Z' },
          { name: 'pitch_data', source_name: 'Baseball Savant', last_updated_at: '2026-07-14T11:00:00Z' },
        ],
      },
    },
  }
}

function apiPayloadWith(mutator) {
  const payload = structuredClone(apiPayload())
  mutator(payload)
  return payload
}

describe('PlayerProfileView', () => {
  it('shows a loading indicator while benchmark context is refreshing', () => {
    const wrapper = mount(ContextualBenchmarksPanel, {
      global: {
        provide: {
          'player-profile-context': {
            player: ref({ contextualBenchmarks: { metrics: [] } }),
            sectionLoading: () => computed(() => true),
          },
        },
      },
    })

    const indicator = wrapper.get('[data-test="contextual-benchmarks-loading"]')
    expect(indicator.text()).toContain('Loading benchmark context…')
    expect(indicator.attributes('role')).toBe('status')
    expect(indicator.find('.contextual-benchmarks-loading__spinner').exists()).toBe(true)
  })

  it('opens data provenance from the profile header in a modal', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => apiPayload() }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    expect(wrapper.find('[data-test="player-data-provenance-modal"]').exists()).toBe(false)
    await wrapper.get('[data-test="player-data-provenance-link"]').trigger('click')

    const modal = wrapper.get('[data-test="player-data-provenance-modal"]')
    expect(modal.get('[role="dialog"]').attributes('aria-modal')).toBe('true')
    expect(modal.text()).toContain('Sources & freshness')
    expect(modal.text()).toContain('MLB Stats API')

    await modal.get('[aria-label="Close data provenance"]').trigger('click')
    expect(wrapper.find('[data-test="player-data-provenance-modal"]').exists()).toBe(false)
  })

  it('uses the longest-served team in a retired player header', async () => {
    const payload = apiPayloadWith((response) => {
      response.data.team = { id: 2, mlb_id: 146, name: 'Miami Marlins', abbreviation: 'MIA' }
      response.data.display_team = { id: 3, mlb_id: 110, name: 'Baltimore Orioles', abbreviation: 'BAL' }
      response.data.current_membership = null
    })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } },
    })
    await flushPromises()

    expect(wrapper.get('.profile-teamline').text()).toContain('Baltimore Orioles')
    expect(wrapper.get('.profile-teamline').text()).not.toContain('Miami Marlins')
  })

  it('labels completed team-history windows as organization tenures instead of active', async () => {
    const payload = apiPayloadWith((response) => {
      response.data.team_history.push({
        id: 7,
        team: { id: 2, mlb_id: 120, name: 'Washington Nationals', abbreviation: 'WSH' },
        starts_on: '2022-08-07',
        ends_on: '2025-07-30',
        current: false,
        roster_status: 'active',
        source_status_description: 'Active',
      })
    })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } },
    })
    await flushPromises()

    expect(wrapper.findAll('.team-timeline small').map((status) => status.text())).toEqual([
      'Active',
      'Organization tenure',
    ])
  })

  it('renders the unified player workflow', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => apiPayload(),
      }),
    )

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: {
        stubs: {
          RouterLink: { template: '<a><slot /></a>' },
        },
      },
    })
    await flushPromises()

    expect(wrapper.text()).toContain('Riley Greene')
    expect(wrapper.text()).toContain('Detroit Tigers')
    expect(wrapper.text()).toContain('Active')
    expect(wrapper.get('.profile-hero').attributes('style')).toContain('--profile-team-primary: #0c2340')
    expect(wrapper.findAll('.profile-summary-metric')).toHaveLength(4)
    expect(wrapper.get('[data-test="summary-metric-home-runs"] strong').text()).toBe('18')
    expect(wrapper.get('[data-test="summary-metric-war"] strong').text()).toBe('3.2')
    expect(wrapper.get('.profile-summary-metric').text()).not.toContain('Recent form')
    expect(wrapper.text()).toContain('Games played')
    expect(wrapper.get('.profile-summary-insight').text()).toBe(
      'Chase rate rose 10.0 pts (24.0 to 34.0) across 32 observations, shaping his results.',
    )
    expect(wrapper.get('.profile-explore-links__label').text()).toBe('Explore this player')
    expect(wrapper.find('[data-test="player-last-season"]').exists()).toBe(false)
    expect(wrapper.findComponent(AddToWatchlistControl).exists()).toBe(true)
    expect(wrapper.get('[data-test="compare-player-link"]').text()).toContain('Compare player')
    expect(wrapper.get('[data-test="external-profile-mlb"]').attributes()).toMatchObject({
      href: 'https://www.mlb.com/player/riley-greene-680776',
      target: '_blank',
      rel: 'noopener noreferrer',
    })
    expect(wrapper.get('[data-test="external-profile-fangraphs"]').attributes('href')).toBe(
      'https://www.fangraphs.com/players/riley-greene/25976/stats',
    )
    expect(wrapper.get('[data-test="external-profile-baseball-reference"]').attributes('href')).toBe(
      'https://www.baseball-reference.com/players/g/greenri03.shtml',
    )
    expect(wrapper.get('[data-test="external-profile-baseball-savant"]').attributes('href')).toBe(
      'https://baseballsavant.mlb.com/savant-player/riley-greene-680776?stats=statcast-r-hitting-mlb',
    )
    expect(wrapper.text()).toContain('Batting by season')
    expect(wrapper.text()).toContain('2022–2026 · 5 seasons')
    const careerTable = wrapper.get('[data-test="career-season-table"]')
    expect(careerTable.text()).toContain('2022')
    expect(careerTable.text()).toContain('2026')
    expect(careerTable.text()).toContain('DET')
    expect(careerTable.text()).toContain('0.740')
    expect(careerTable.text()).toContain('WAR')
    expect(careerTable.text()).toContain('3.2')
    expect(careerTable.text()).toContain('Career')
    expect(careerTable.text()).toContain('0.821')
    expect(wrapper.text()).not.toContain('Season snapshot')
    expect(wrapper.text()).toContain('Player history')
    const organizationMilestones = wrapper.get('[data-test="organization-milestones"]')
    expect(organizationMilestones.text()).toContain('Draft information')
    expect(organizationMilestones.text()).toContain('2019 MLB Draft')
    expect(organizationMilestones.text()).toContain('MLB debut')
    expect(organizationMilestones.text()).toContain('Jun 18, 2022')
    expect(organizationMilestones.text()).toContain('Awards')
    expect(organizationMilestones.text()).toContain('AL Silver Slugger (2025)')
    expect(organizationMilestones.text()).toContain('All-Star selections')
    expect(organizationMilestones.text()).toContain('2026, 2025, 2024 · 3× MLB All-Star')
    await wrapper.get('[data-test="player-page-tab-performance-trends"]').trigger('click')
    expect(wrapper.get('[data-test="recent-pitch-indicators"]').text()).toContain('Recent pitch indicators')
    expect(wrapper.get('[data-test="recent-pitch-indicators"]').text()).toContain('91.2 mph')
    expect(wrapper.get('[data-test="player-date-range-controls"]').text()).toContain('Full season')
    expect(wrapper.get('[data-test="player-date-range-controls"]').text()).toContain('Last 30 days')
    expect(wrapper.get('[data-test="player-trends"]').text()).toContain('Performance trends')
    expect(wrapper.get('[data-test="player-trends"]').text()).toContain('Batting · Exit velocity')
    expect(wrapper.get('[data-test="trend-events"]').text()).toContain('Chase-rate movement')
    expect(wrapper.get('[data-test="trend-events"]').text()).toContain('warning · active')
    expect(wrapper.get('[data-test="trend-events"]').text()).toContain('Sample 32 vs 30 baseline')
    expect(wrapper.get('[data-test="trend-events"]').text()).toContain('Onset Jul 1, 2026')
    expect(wrapper.get('[data-test="player-trends"] svg').attributes('aria-label')).toBe('Batting · Exit velocity rolling trend')
    await wrapper.get('[data-test="player-page-tab-overview"]').trigger('click')
    const benchmarks = wrapper.get('[data-test="contextual-benchmarks"]')
    expect(benchmarks.text()).toContain('Benchmarks & percentiles')
    expect(benchmarks.text()).toContain('Max exit velocity')
    expect(benchmarks.text()).toContain('Barrel rate')
    expect(benchmarks.text()).toContain('Bat speed')
    expect(benchmarks.text()).toContain('K%')
    expect(benchmarks.text()).toContain('BB%')
    expect(benchmarks.text()).toContain('21.7%')
    expect(benchmarks.text()).toContain('9.8%')
    const benchmarkLabels = benchmarks.findAll('.context-percentile-row__metric > strong').map((element) => element.text())
    expect(benchmarkLabels).toEqual([
      'OPS', 'K%', 'BB%', 'Average exit velocity', 'Barrel rate', 'Max exit velocity', 'Bat speed',
    ])
    expect(benchmarks.text()).toContain('0.842')
    expect(benchmarks.text()).toContain('0.720')
    expect(benchmarks.text()).toContain('CF')
    expect(benchmarks.text()).toContain('83')
    expect(benchmarks.text()).toContain('480')
    expect(wrapper.text()).toContain('Baseball Savant')
    expect(wrapper.get('.profile-portrait img').attributes()).toMatchObject({
      src: 'https://img.mlbstatic.com/mlb-photos/image/upload/ar_20:23,c_fill,g_north,w_260/c_pad,b_auto:border,w_300,h_300,q_auto:best/v1/people/680776/headshot/67/current',
      alt: 'Riley Greene headshot',
    })
    expect(wrapper.get('.profile-portrait').classes()).toContain('profile-portrait--photo')

    await wrapper.get('[data-test="player-page-tab-performance-trends"]').trigger('click')
    await wrapper.get('.range-presets button:nth-child(2)').trigger('click')
    await flushPromises()
    expect(fetch).toHaveBeenCalledWith('/api/players/42?range=7&pa_window=50&pitch_window=100&sections=core', {
      headers: { Accept: 'application/json' },
    })
  })

  it('shows the final MLB season in the bio for an inactive player', async () => {
    const payload = apiPayload()
    payload.data.profile.active = false
    payload.data.profile.last_played_date = '2023-10-01'
    payload.data.career_overview.last_season = null
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } },
    })
    await flushPromises()

    expect(wrapper.get('[data-test="player-last-season"]').text()).toContain('Last season')
    expect(wrapper.get('[data-test="player-last-season"]').text()).toContain('2023')
  })

  it('renders favorable pitcher chase movement as a green improvement', async () => {
    const payload = apiPayloadWith((response) => {
      response.data.trend_events.events[0] = {
        ...response.data.trend_events.events[0],
        role: 'pitcher',
        baseline_value: 38.9,
        current_value: 51.8,
        change_value: 12.9,
        baseline_sample_size: 54,
        sample_size: 56,
        onset_date: '2026-07-18',
      }
    })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } },
    })
    await flushPromises()

    await wrapper.get('[data-test="player-page-tab-performance-trends"]').trigger('click')
    const event = wrapper.get('[data-test="trend-events"] article')
    expect(event.classes()).toContain('trend-event--favorable')
    expect(event.text()).toContain('improvement · active')
    expect(event.text()).not.toContain('warning · active')
    expect(event.text()).toContain('38.9 pts → 51.8 pts')
  })

  it('renders batter spray and hit-location charts on the Batted Ball Profile tab', async () => {
    const corePayload = apiPayload()
    delete corePayload.data.batted_ball_profile
    vi.stubGlobal('fetch', vi.fn()
      .mockResolvedValueOnce({ ok: true, json: async () => corePayload })
      .mockResolvedValue({ ok: true, json: async () => apiPayload() }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    await wrapper.get('[data-test="player-page-tab-batted-ball-profile"]').trigger('click')
    const panel = wrapper.get('[data-test="batted-ball-profile"]')
    expect(panel.get('[data-test="batted-ball-spray-chart"]').text()).toContain('Spray chart')
    expect(panel.get('[data-test="batted-ball-hit-location-chart"]').text()).toContain('Hit-location chart')
    expect(panel.text()).toContain('3 tracked contacts')
    expect(panel.text()).toContain('2 tracked hits')
    expect(panel.findAll('.spray-point')).toHaveLength(3)
    expect(panel.find('.spray-point--single').exists()).toBe(true)
    expect(panel.find('.spray-point--home-run').exists()).toBe(true)
    expect(panel.get('circle.spray-point--single title').text()).toContain('SINGLE')
    expect(panel.get('circle.spray-point--single title').text()).toContain('287 ft')

    await panel.get('[data-test="spray-chart-outs-toggle"]').setValue(false)

    expect(panel.findAll('.spray-point')).toHaveLength(2)
  })

  it('renders pitcher batted-ball metrics on the Batted Ball Profile tab', async () => {
    const payload = apiPayloadWith((response) => {
      response.data.recent_pitch_indicators.primary_role = 'pitcher'
      response.data.pitch_arsenal = {
        available: true,
        pitches: [{
          pitch_type: 'FF',
          pitch_name: '4-Seam Fastball',
          usage_percentage: 54.2,
          pitch_count: 64,
          average_velocity: 96.4,
          maximum_velocity: 98.1,
          spin_rate: 2380,
          active_spin: 91.2,
          vertical_movement: 16.4,
          horizontal_movement: -7.1,
          zone_percentage: 49.5,
          chase_percentage: 31.2,
          whiff_percentage: 27.8,
          hard_hit_percentage: 28.4,
          run_value: -1.24,
        }],
      }
      response.data.contextual_benchmarks.metrics.push({
        metric_key: 'pitch_usage_percentage',
        metric_group: 'pitch_type',
        display_name: 'Pitch usage',
        unit: 'percent',
        dimension_type: 'pitch_type',
        dimension_value: 'FF',
        raw_value: 54.2,
        mlb_average: 48.5,
        pitcher_role_average: 51.2,
        pitcher_role_key: 'starter',
        percentile: 68,
        sample_size: 64,
        mlb_player_count: 280,
      })
      response.data.batted_ball_profile.pitcher_metrics = {
        available: true,
        batted_ball_count: 118,
        ground_ball_percentage: 44.1,
        fly_ball_percentage: 31.4,
        line_drive_percentage: 24.5,
        infield_fly_percentage: 12.2,
        pull_percentage: 37.6,
        hard_hit_percentage: 34.8,
        barrel_percentage: 7.6,
        home_run_per_fly_ball: 13.5,
        average_launch_angle: 11.8,
        seasons: [
          {
            season: 2025,
            batted_ball_count: 100,
            ground_ball_percentage: 46.2,
            fly_ball_percentage: 29.1,
            ground_ball_to_fly_ball_ratio: 1.59,
            line_drive_percentage: 24.7,
            infield_fly_percentage: 10.1,
            pull_percentage: 35.4,
            hard_hit_percentage: 36.2,
            barrel_percentage: 8.1,
            home_run_per_fly_ball: 12.8,
            average_launch_angle: 10.6,
          },
          {
            season: 2026,
            batted_ball_count: 118,
            ground_ball_percentage: 44.1,
            fly_ball_percentage: 31.4,
            ground_ball_to_fly_ball_ratio: 1.40,
            line_drive_percentage: 24.5,
            infield_fly_percentage: 12.2,
            pull_percentage: 37.6,
            hard_hit_percentage: 34.8,
            barrel_percentage: 7.6,
            home_run_per_fly_ball: 13.5,
            average_launch_angle: 11.8,
          },
        ],
      }
    })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    expect(wrapper.get('[data-test="contextual-benchmarks"]').text()).not.toContain('Pitch usage')

    await wrapper.get('[data-test="player-page-tab-batted-ball-profile"]').trigger('click')
    const table = wrapper.get('[data-test="pitcher-batted-ball-table"]')
    expect(table.text()).toContain('GB%')
    expect(table.text()).toContain('IFFB%')
    expect(table.text()).toContain('HR/FB')
    expect(table.text()).toContain('GB/FB')
    expect(table.text()).toContain('44.1%')
    expect(table.text()).toContain('11.8°')
    expect(table.text()).toContain('1.40')
    expect(table.get('thead').text()).toContain('Season')
    expect(table.get('tbody').text()).toContain('2026')
    expect(table.get('tbody').text()).toContain('2025')

    await wrapper.get('[data-test="player-page-tab-pitch-arsenal"]').trigger('click')
    await flushPromises()
    const arsenal = wrapper.get('[data-test="player-page-panel-pitch-arsenal"]')
    expect(arsenal.text()).toContain('Pitch arsenal and effectiveness')
    expect(arsenal.text()).toContain('4-Seam Fastball')
    expect(arsenal.text()).toContain('Usage%')
    expect(arsenal.text()).toContain('Active spin')
    expect(arsenal.text()).toContain('54.2%')
    expect(arsenal.text()).toContain('-1.24')
    const pitchUsagePercentiles = arsenal.get('[data-test="pitch-usage-percentiles"]')
    expect(pitchUsagePercentiles.text()).toContain('Pitch usage benchmarks & percentiles')
    expect(pitchUsagePercentiles.text()).toContain('Pitch usage · FF')
    expect(pitchUsagePercentiles.text()).toContain('54.2%')

    await arsenal.get('[data-test="tab-analysis-period-controls"] button').trigger('click')
    await flushPromises()
    expect(fetch.mock.calls.at(-1)[0]).toContain('sections=analytics')
    expect(fetch.mock.calls.at(-1)[0]).toContain('range=season')
  })

  it('uses Savant-inspired percentile markers with readable text contrast', async () => {
    const payload = apiPayloadWith((response) => {
      const benchmark = response.data.contextual_benchmarks.metrics[0]
      response.data.contextual_benchmarks.metrics = [
        { ...benchmark, metric_key: 'low', display_name: 'Low', percentile: 10 },
        { ...benchmark, metric_key: 'middle', display_name: 'Middle', percentile: 50 },
        { ...benchmark, metric_key: 'high', display_name: 'High', percentile: 90 },
      ]
    })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    const rows = wrapper.findAll('.context-percentile-row')
    const pills = wrapper.findAll('.percentile-pill')
    expect(pills.map((pill) => pill.text())).toEqual(['10', '50', '90'])
    expect(rows[0].attributes('style')).toContain('--percentile-background: #5076b4')
    expect(rows[0].attributes('style')).toContain('--percentile-foreground: #f9fafb')
    expect(rows[0].attributes('style')).toContain('--percentile-position: 10%')
    expect(rows[1].attributes('style')).toContain('--percentile-background: #c2bfbc')
    expect(rows[1].attributes('style')).toContain('--percentile-foreground: #1f2937')
    expect(rows[2].attributes('style')).toContain('--percentile-background: #df594c')
    expect(rows[2].attributes('style')).toContain('--percentile-foreground: #f9fafb')
  })

  it('renders batter and pitcher split dimensions as grouped table rows', async () => {
    const payload = apiPayloadWith((response) => {
      response.data.positions.primary.position_type = 'two_way'
      response.data.batter_splits = {
        available: true,
        dimensions: [
          {
            key: 'pitcher_hand',
            label: 'Vs. pitcher handedness',
            options: [
              { value: 'L', label: 'Left-handed', metrics: { plate_appearances: 10, batting_average: 0.300 } },
              { value: 'R', label: 'Right-handed', metrics: { plate_appearances: 12, batting_average: 0.250 } },
            ],
          },
          {
            key: 'home_away',
            label: 'Home / away',
            options: [
              { value: 'home', label: 'Home', metrics: { plate_appearances: 20, batting_average: 0.275 } },
              { value: 'away', label: 'Away', metrics: { plate_appearances: 15, batting_average: 0.250 } },
            ],
          },
        ],
      }
      response.data.pitcher_splits = {
        available: true,
        dimensions: [
          {
            key: 'batter_hand',
            label: 'Vs. batter handedness',
            options: [
              { value: 'L', label: 'Left-handed', metrics: { batters_faced: 18, earned_run_average: 2.50 } },
              { value: 'R', label: 'Right-handed', metrics: { batters_faced: 22, earned_run_average: 3.10 } },
            ],
          },
        ],
      }
    })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()
    await wrapper.get('[data-test="player-profile-tab-splits"]').trigger('click')
    await flushPromises()

    const panel = wrapper.get('[data-test="batter-splits"]')
    expect(panel.findAll('.split-tabs')).toHaveLength(0)
    expect(panel.findAll('.split-category-row')).toHaveLength(3)
    expect(panel.text()).toContain('Vs. pitcher handedness')
    expect(panel.text()).toContain('Home / away')
    expect(panel.text()).toContain('Vs. batter handedness')
    expect(panel.text()).toContain('Left-handed')
    expect(panel.findAll('.split-role')).toHaveLength(2)
  })

  it('shows grouped rate and run-creation tables on the Advanced Stats tab', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => apiPayload() }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    const advancedTab = wrapper.get('[data-test="player-profile-tab-advanced-stats"]')
    expect(advancedTab.attributes('role')).toBe('tab')
    expect(advancedTab.attributes('aria-selected')).toBe('false')
    const profileRequestCount = fetch.mock.calls.length

    await advancedTab.trigger('click')
    await flushPromises()

    expect(advancedTab.attributes('aria-selected')).toBe('true')
    expect(fetch).toHaveBeenCalledTimes(profileRequestCount + 1)
    expect(wrapper.find('#player-profile-panel-overview').exists()).toBe(false)
    const panel = wrapper.get('[data-test="advanced-stats-panel"]')
    expect(panel.isVisible()).toBe(true)
    expect(wrapper.find('[data-test="similar-players"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="player-trends"]').exists()).toBe(false)
    expect(panel.get('[data-test="advanced-stat-group-rate_statistics"]').text()).toContain('BB%')
    expect(panel.get('[data-test="advanced-stat-group-rate_statistics"]').text()).toContain('10.2%')
    expect(panel.get('[data-test="advanced-stat-group-rate_statistics"]').text()).toContain('.331')
    expect(panel.get('[data-test="advanced-stat-group-rate_statistics"]').text()).toContain('HR/FB%')
    expect(panel.get('[data-test="advanced-stat-group-run_creation_value"]').text()).toContain('wRC+')
    expect(panel.get('[data-test="advanced-stat-group-run_creation_value"]').text()).toContain('132')
    expect(panel.get('[data-test="advanced-stat-group-run_creation_value"]').text()).toContain('Offensive Runs')
    expect(panel.get('[data-test="advanced-stat-group-run_creation_value"]').text()).toContain('18.4')
    expect(panel.get('[data-test="advanced-stat-group-run_creation_value"]').text()).toContain('Career')
    expect(panel.get('[data-test="advanced-stat-group-batted_ball_profile"]').text()).toContain('Opposite-field%')
    expect(panel.get('[data-test="advanced-stat-group-batted_ball_profile"]').text()).toContain('42.8%')
    const battingLongHeader = panel
      .get('[data-test="advanced-stat-group-batted_ball_profile"]')
      .findAll('thead th')
      .find((header) => header.text() === 'Opposite-field%')
    expect(battingLongHeader.classes()).toContain('advanced-table__metric-heading')
    expect(panel.get('[data-test="advanced-stat-group-plate_discipline"]').text()).toContain('Zone Contact%')
    expect(panel.get('[data-test="advanced-stat-group-plate_discipline"]').text()).toContain('10.6%')
  })

  it('shows defensive rows by position followed by a season total', async () => {
    const payload = apiPayloadWith((response) => {
      response.data.defensive_stats = {
        season: 2026,
        seasons: [
          {
            season: 2026,
            games: 79,
            fielding_percentage: 0.9766,
            defensive_runs_saved: -4,
            outs_above_average: -9,
            positions: [
              {
                position: '2B',
                games: 56,
                innings: '360.2',
                fielding_percentage: 0.981928,
                defensive_runs_saved: -3,
                outs_above_average: -4,
              },
              {
                position: '3B',
                games: 24,
                innings: '131.1',
                fielding_percentage: 0.977778,
                defensive_runs_saved: -1,
                outs_above_average: -4,
              },
              {
                position: 'DH',
                games: 10,
                innings: null,
                fielding_percentage: null,
                defensive_runs_saved: null,
                outs_above_average: null,
              },
            ],
          },
        ],
      }
    })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    await wrapper.get('[data-test="player-profile-tab-defensive-stats"]').trigger('click')
    await flushPromises()

    const panel = wrapper.get('[data-test="defensive-stats-panel"]')
    const rows = panel.findAll('tbody tr')
    expect(rows).toHaveLength(3)
    expect(rows[0].text()).toContain('2B')
    expect(rows[0].text()).toContain('360.2')
    expect(rows[0].text()).toContain('-3.00')
    expect(rows[1].text()).toContain('3B')
    expect(panel.text()).not.toContain('DH')
    expect(rows[2].classes()).toContain('advanced-table__season-total')
    expect(rows[2].text()).toContain('Season total')
    expect(rows[2].text()).toContain('79')
    expect(rows[2].text()).toContain('-4.00')
    expect(rows[2].text()).toContain('-9.00')
  })

  it('omits the season-total row and OAA column for a pitcher', async () => {
    const payload = apiPayloadWith((response) => {
      response.data.defensive_stats = {
        season: 2026,
        seasons: [
          {
            season: 2026,
            games: 19,
            outs_above_average_applicable: false,
            fielding_percentage: 1,
            defensive_runs_saved: -1,
            outs_above_average: null,
            positions: [
              {
                position: 'P',
                games: 19,
                innings: '113.2',
                fielding_percentage: 1,
                defensive_runs_saved: -1,
                outs_above_average: null,
              },
            ],
          },
        ],
      }
    })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    await wrapper.get('[data-test="player-profile-tab-defensive-stats"]').trigger('click')
    await flushPromises()

    const rows = wrapper.get('[data-test="defensive-stats-panel"]').findAll('tbody tr')
    expect(rows).toHaveLength(1)
    expect(rows[0].text()).toContain('P')
    expect(rows[0].text()).toContain('113.2')
    expect(rows[0].text()).toContain('1.000')
    expect(rows[0].text()).toContain('-1.00')
    expect(rows[0].text()).not.toContain('Season total')
    expect(wrapper.get('[data-test="defensive-stats-panel"]').text()).not.toContain('Outs Above Average')
    expect(rows[0].findAll('td')).toHaveLength(5)
  })
  it('shows pitcher rate and outcome statistics on the Advanced Stats tab', async () => {
    const payload = apiPayloadWith((response) => {
      response.data.positions = {
        primary: { abbreviation: 'SP', name: 'Starting Pitcher', position_type: 'pitcher' },
        secondary: [],
        assignments: [],
      }
      response.data.advanced_stats = {
        category: 'pitching',
        groups: [
          {
            key: 'rate_and_outcome_statistics',
            label: 'Rate and outcome statistics',
            columns: [
              { key: 'k_percentage', label: 'K%', unit: 'percent' },
              { key: 'bb_percentage', label: 'BB%', unit: 'percent' },
              { key: 'k_minus_bb_percentage', label: 'K-BB%', unit: 'percent' },
              { key: 'k_per_bb', label: 'K/BB', unit: 'ratio' },
              { key: 'hbp_percentage', label: 'HBP%', unit: 'percent' },
              { key: 'hr_percentage', label: 'HR%', unit: 'percent' },
              { key: 'babip', label: 'BABIP', unit: 'rate' },
              { key: 'lob_percentage', label: 'LOB%', unit: 'percent' },
              { key: 'era', label: 'ERA', unit: 'pitching_rate' },
              { key: 'fip', label: 'FIP', unit: 'pitching_rate' },
              { key: 'xfip', label: 'xFIP', unit: 'pitching_rate' },
            ],
          },
          {
            key: 'run_prevention_and_expected_performance',
            label: 'Run prevention and expected performance',
            columns: [
              { key: 'era', label: 'ERA', unit: 'pitching_rate' },
              { key: 'era_minus', label: 'ERA-', unit: 'index' },
              { key: 'era_plus', label: 'ERA+', unit: 'index' },
              { key: 'fip', label: 'FIP', unit: 'pitching_rate' },
              { key: 'fip_minus', label: 'FIP-', unit: 'index' },
              { key: 'xfip', label: 'xFIP', unit: 'pitching_rate' },
              { key: 'xfip_minus', label: 'xFIP-', unit: 'index' },
              { key: 'siera', label: 'SIERA', unit: 'pitching_rate' },
              { key: 'xera', label: 'xERA', unit: 'pitching_rate' },
              { key: 'ra9', label: 'RA9', unit: 'pitching_rate' },
              { key: 'runs_allowed_per_nine', label: 'Runs allowed per 9', unit: 'pitching_rate' },
              { key: 'earned_runs_allowed_per_nine', label: 'Earned runs allowed per 9', unit: 'pitching_rate' },
              { key: 'expected_woba_allowed', label: 'Expected wOBA allowed', unit: 'rate' },
              { key: 'woba_allowed', label: 'wOBA allowed', unit: 'rate' },
            ],
          },
          {
            key: 'pitcher_value',
            label: 'Pitcher value',
            description: 'A high-level summary of how much value the pitcher produced.',
            columns: [
              { key: 'war', label: 'WAR', unit: 'war' },
              { key: 'ra9_war', label: 'RA9-WAR', unit: 'war' },
              { key: 'wpa', label: 'WPA', unit: 'war' },
              { key: 'wpa_per_li', label: 'WPA/LI', unit: 'war' },
              { key: 're24', label: 'RE24', unit: 'runs' },
              { key: 'clutch', label: 'Clutch', unit: 'ratio' },
              { key: 'runs_above_replacement', label: 'Runs above replacement', unit: 'runs' },
              { key: 'runs_above_average', label: 'Runs above average', unit: 'runs' },
              { key: 'pitching_runs', label: 'Pitching runs', unit: 'runs' },
              { key: 'leverage_index', label: 'Leverage index', unit: 'ratio' },
              { key: 'shutdowns', label: 'Shutdowns', unit: 'count' },
              { key: 'meltdowns', label: 'Meltdowns', unit: 'count' },
            ],
          },
        ],
        seasons: [
          {
            season: 2026,
            teams: [{ id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' }],
            values: { k_percentage: 0.3, bb_percentage: 0.05, k_minus_bb_percentage: 0.25, k_per_bb: 6, hbp_percentage: 0.01, hr_percentage: 0.025, babip: 0.25, lob_percentage: 0.8, era: 1.8, era_minus: 60, era_plus: 167, fip: 3, fip_minus: 70, xfip: 3.2, xfip_minus: 75, siera: 2.9, xera: 2.7, ra9: 2.7, runs_allowed_per_nine: 2.7, earned_runs_allowed_per_nine: 1.8, expected_woba_allowed: 0.27, woba_allowed: 0.25, war: 2, ra9_war: 2.5, wpa: 1, wpa_per_li: 1.5, re24: 15, clutch: 0.2, runs_above_replacement: 20, runs_above_average: 10, pitching_runs: 9, leverage_index: 1.1, shutdowns: 2, meltdowns: 1 },
          },
        ],
        career: {
          values: { k_percentage: 0.267, bb_percentage: 0.083, k_minus_bb_percentage: 0.184, k_per_bb: 3.2, hbp_percentage: 0.012, hr_percentage: 0.042, babip: 0.283, lob_percentage: 0.747, era: 2.4, era_minus: 73, era_plus: 136, fip: 3.67, fip_minus: 80, xfip: 3.87, xfip_minus: 85, siera: 3.5, xera: 3.3, ra9: 3.3, runs_allowed_per_nine: 3.3, earned_runs_allowed_per_nine: 2.4, expected_woba_allowed: 0.29, woba_allowed: 0.29, war: 6, ra9_war: 7, wpa: 4, wpa_per_li: 5, re24: 45, clutch: -0.3, runs_above_replacement: 60, runs_above_average: 35, pitching_runs: 32, leverage_index: 0.97, shutdowns: 5, meltdowns: 3 },
        },
      }
    })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()
    await wrapper.get('[data-test="player-profile-tab-advanced-stats"]').trigger('click')
    await flushPromises()

    const table = wrapper.get('[data-test="advanced-stat-group-rate_and_outcome_statistics"]')
    expect(table.text()).toContain('K-BB%')
    expect(table.text()).toContain('HBP%')
    expect(table.text()).toContain('BABIP')
    expect(table.text()).toContain('xFIP')
    expect(table.text()).toContain('30.0%')
    expect(table.text()).toContain('1.80')
    expect(table.text()).toContain('3.20')
    const preventionTable = wrapper.get('[data-test="advanced-stat-group-run_prevention_and_expected_performance"]')
    expect(preventionTable.text()).toContain('ERA-')
    expect(preventionTable.text()).toContain('SIERA')
    expect(preventionTable.text()).toContain('Expected wOBA allowed')
    expect(preventionTable.text()).toContain('167')
    expect(preventionTable.text()).toContain('0.270')
    const valueTable = wrapper.get('[data-test="advanced-stat-group-pitcher_value"]')
    expect(valueTable.text()).toContain('A high-level summary of how much value the pitcher produced.')
    expect(valueTable.text()).toContain('RA9-WAR')
    expect(valueTable.text()).toContain('WPA/LI')
    expect(valueTable.text()).toContain('Runs above replacement')
    expect(valueTable.text()).toContain('Shutdowns')
    expect(valueTable.text()).toContain('2.5')
    const pitcherLongHeader = valueTable
      .findAll('thead th')
      .find((header) => header.text() === 'Runs above replacement')
    expect(pitcherLongHeader.classes()).toContain('advanced-table__metric-heading')
  })

  it('shows pitching trends for primary pitchers', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => apiPayloadWith((payload) => {
          payload.data.positions = {
            primary: { abbreviation: 'SP', name: 'Starting Pitcher', position_type: 'pitcher' },
            secondary: [],
            assignments: [],
          }
          payload.data.recent_pitch_indicators.primary_role = 'pitcher'
          payload.data.analysis.batting.charts = [
            {
              key: 'exit_velocity', title: 'Exit velocity', unit: 'mph',
              series: [{ key: 'exit_velocity', label: 'Exit velocity', points: [
                { date: '2026-04-01', sequence: 1, value: 89.0, sample_size: 1 },
                { date: '2026-07-14', sequence: 480, value: 91.2, sample_size: 18 },
              ] }],
            },
          ]
          payload.data.analysis.pitching = {
            window_type: 'pitches',
            window_size: 100,
            total_observations: 320,
            charts: [
              {
                key: 'velocity', title: 'Velocity', unit: 'mph',
                series: [{ key: 'velocity', label: 'Velocity', points: [
                  { date: '2026-04-01', sequence: 1, value: 96.1, sample_size: 20 },
                  { date: '2026-07-14', sequence: 320, value: 97.3, sample_size: 25 },
                ] }],
              },
            ],
          }
        }),
      }),
    )

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    await wrapper.get('[data-test="player-page-tab-performance-trends"]').trigger('click')
    const trends = wrapper.get('[data-test="player-trends"]')
    expect(trends.text()).toContain('Pitching · Velocity')
    expect(trends.text()).not.toContain('Batting · Exit velocity')
    expect(trends.find('svg').attributes('aria-label')).toBe('Pitching · Velocity rolling trend')
    expect(wrapper.find('[data-test="indicator-card-batting"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="indicator-card-pitching"]').exists()).toBe(true)
    expect(wrapper.get('[data-test="external-profile-baseball-savant"]').attributes('href')).toBe(
      'https://baseballsavant.mlb.com/savant-player/riley-greene-680776?stats=statcast-r-pitching-mlb',
    )
  })

  it('shows both batting and pitching trends for two-way players', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => apiPayloadWith((payload) => {
          payload.data.positions = {
            primary: { abbreviation: 'TWP', name: 'Two-Way Player', position_type: 'two_way' },
            secondary: [
              { abbreviation: 'DH', name: 'Designated Hitter', position_type: 'designated_hitter' },
              { abbreviation: 'SP', name: 'Starting Pitcher', position_type: 'pitcher' },
            ],
            assignments: [
              { current: true, primary: true, position: { abbreviation: 'TWP', name: 'Two-Way Player', position_type: 'two_way', sort_order: 1 } },
              { current: true, primary: false, position: { abbreviation: 'SP', name: 'Starting Pitcher', position_type: 'pitcher', sort_order: 2 } },
            ],
          }
          payload.data.analysis.pitching = {
            window_type: 'pitches',
            window_size: 100,
            total_observations: 320,
            charts: [
              {
                key: 'velocity', title: 'Velocity', unit: 'mph',
                series: [{ key: 'velocity', label: 'Velocity', points: [
                  { date: '2026-04-01', sequence: 1, value: 96.1, sample_size: 20 },
                  { date: '2026-07-14', sequence: 320, value: 97.3, sample_size: 25 },
                ] }],
              },
            ],
          }
        }),
      }),
    )

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    await wrapper.get('[data-test="player-page-tab-performance-trends"]').trigger('click')
    const trends = wrapper.get('[data-test="player-trends"]')
    expect(trends.text()).toContain('Batting · Exit velocity')
    expect(trends.text()).toContain('Pitching · Velocity')
    expect(wrapper.find('[data-test="indicator-card-batting"]').exists()).toBe(true)
    expect(wrapper.find('[data-test="indicator-card-pitching"]').exists()).toBe(true)
  })

  it('shows a pitcher walk rate as BB/9 in the pitching indicators', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: async () => apiPayloadWith((payload) => {
        payload.data.positions = {
          primary: { abbreviation: 'P', name: 'Pitcher', position_type: 'pitcher' },
          secondary: [],
          assignments: [],
        }
        payload.data.season_overview = {
          season: 2026,
          category: 'pitching',
          preferred_category: 'pitching',
          stats: [
            { key: 'baseOnBalls', label: 'BB', value: '20' },
            { key: 'inningsPitched', label: 'IP', value: '90.0' },
          ],
        }
      }),
    }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    await wrapper.get('[data-test="player-page-tab-performance-trends"]').trigger('click')
    expect(wrapper.get('[data-test="indicator-card-pitching"]').text()).toContain('Walk rate')
    expect(wrapper.get('[data-test="indicator-card-pitching"]').text()).toContain('2.00 BB/9')
  })

  it('falls back to player initials when the headshot cannot load', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => apiPayload(),
      }),
    )

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    await wrapper.get('.profile-portrait img').trigger('error')

    expect(wrapper.find('.profile-portrait img').exists()).toBe(false)
    expect(wrapper.get('.profile-portrait').classes()).not.toContain('profile-portrait--photo')
    expect(wrapper.get('.profile-portrait span').text()).toBe('RG')
  })

  it('shows statistically similar players and the metrics behind each match', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => apiPayload() }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } },
    })
    await flushPromises()

    const similarPlayersTab = wrapper.get('[data-test="player-page-tab-similar-players"]')
    expect(similarPlayersTab.attributes('aria-selected')).toBe('false')

    await similarPlayersTab.trigger('click')
    await flushPromises()

    expect(similarPlayersTab.attributes('aria-selected')).toBe('true')
    const panel = wrapper.get('[data-test="similar-players"]')
    expect(panel.text()).toContain('Julio Rodríguez')
    expect(panel.text()).toContain('91.4%')
    expect(panel.text()).toContain('AVG')
    expect(panel.text()).toContain('HR / PA')
    expect(panel.text()).toContain('Metrics used in the model')
    expect(panel.text()).toContain('Age and season controls')
    expect(panel.text()).toContain('Position controls')
    expect(panel.text()).toContain('Current season')
    expect(panel.text()).toContain('Career')
    expect(panel.text()).toContain('Why this player is similar')
    expect(panel.text()).toContain('Same position group: Outfielder.')
    expect(panel.text()).toContain('All 3 metrics used')
    expect(panel.text()).toContain('20%')
    expect(panel.text()).toContain('Compare side by side')

    await panel.get('[data-test="similar-season-control"]').setValue('2025')
    await panel.get('[data-test="similar-min-age-control"]').setValue('23')
    await panel.get('[data-test="similar-max-age-control"]').setValue('29')
    await panel.get('[data-test="similar-position-control"]').setValue('same_type')
    await panel.get('[data-test="similar-player-controls"]').trigger('submit')
    await flushPromises()

    const requestUrl = fetch.mock.calls.at(-1)[0]
    expect(requestUrl).toContain('similar_season=2025')
    expect(requestUrl).toContain('similar_min_age=23')
    expect(requestUrl).toContain('similar_max_age=29')
    expect(requestUrl).toContain('similar_position=same_type')

    await panel.get('[data-test="similar-mode-career"]').setValue(true)
    await flushPromises()
    expect(fetch.mock.calls.at(-1)[0]).toContain('similar_mode=career')
  })

  it('renders a retry state when loading fails', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 500 }))

    const wrapper = mount(PlayerProfileView, {
      props: { playerId: '42' },
      global: { stubs: { RouterLink: true } },
    })
    await flushPromises()

    expect(wrapper.get('[data-test="profile-error"]').text()).toContain('Unable to load this player profile')
    expect(wrapper.get('button').text()).toBe('Try again')
  })
})
