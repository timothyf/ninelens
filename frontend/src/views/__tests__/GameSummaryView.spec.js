import { flushPromises, mount } from '@vue/test-utils'
import { afterEach, vi } from 'vitest'

import GameSummaryView from '../GameSummaryView.vue'

const RouterLink = {
  props: ['to'],
  template: '<a href="#"><slot /></a>',
}

const situation = (overrides = {}) => ({
  plate_appearances: 0, at_bats: 0, hits: 0, walks: 0, strikeouts: 0,
  runs_batted_in: 0, batting_average: null, on_base_percentage: null, ...overrides,
})

const payload = {
  data: {
    id: 80,
    mlb_id: 823443,
    official_date: '2026-07-14',
    scheduled_at: '2026-07-14T23:10:00Z',
    status: 'final',
    detailed_status: 'Final',
    venue_name: 'Comerica Park',
    away_score: 1,
    home_score: 3,
    away_team: { id: 2, mlb_id: 114, abbreviation: 'CLE', name: 'Cleveland Guardians' },
    home_team: { id: 1, mlb_id: 116, abbreviation: 'DET', name: 'Detroit Tigers' },
    details: {
      synchronized: true,
      last_synced_at: '2026-07-15T02:30:00Z',
      insights: {
        decisions: {
          winning_pitcher: { player: { id: 23, full_name: 'Tarik Skubal' }, decision: '(W, 11-2)' },
          losing_pitcher: { player: { id: 22, full_name: 'Tanner Bibee' }, decision: '(L, 7-5)' },
          save: { player: { id: 24, full_name: 'Will Vest' }, decision: '(S, 1)' },
        },
        teams: {
          away: { run_differential: -2, hits: 5, errors: 0, walks: 2, strikeouts: 9, home_runs: 0, left_on_base: 6, runners_in_scoring_position: { hits: 1, at_bats: 5 } },
          home: { run_differential: 2, hits: 8, errors: 1, walks: 3, strikeouts: 7, home_runs: 1, left_on_base: 7, runners_in_scoring_position: { hits: 2, at_bats: 6 } },
        },
      },
      key_performers: {
        top_hitters: {
          away: {
            player: { id: 20, full_name: 'Steven Kwan' }, team: { id: 2, abbreviation: 'CLE' },
            summary: '2-for-4, 1 RBI, 1 R', metrics: { hits: 2, total_bases: 3 },
          },
          home: {
            player: { id: 21, full_name: 'Riley Greene' }, team: { id: 1, abbreviation: 'DET' },
            summary: '2-for-4, 1 HR, 3 RBI, 1 R', metrics: { hits: 2, home_runs: 1, total_bases: 5 },
          },
        },
        most_impactful_pitcher: {
          player: { id: 23, full_name: 'Tarik Skubal' }, team: { id: 1, abbreviation: 'DET' },
          summary: '7.0 IP, 1 ER, 9 K, W', metrics: { innings_pitched: '7.0', strikeouts: 9 },
        },
        power_hitters: [
          {
            player: { id: 21, full_name: 'Riley Greene' }, team: { id: 1, abbreviation: 'DET' },
            summary: '1 HR', metrics: { home_runs: 1 },
          },
        ],
        scoreless_relievers: [
          {
            player: { id: 24, full_name: 'Will Vest' }, team: { id: 1, abbreviation: 'DET' },
            summary: '1.0 scoreless IP · 2 K', metrics: { innings_pitched: '1.0', strikeouts: 2 },
          },
        ],
        top_run_producers: [
          {
            player: { id: 21, full_name: 'Riley Greene' }, team: { id: 1, abbreviation: 'DET' },
            summary: '3 runs produced · 1 R, 3 RBI', metrics: { runs_responsible_for: 3 },
          },
        ],
      },
      scoring_plays: [
        {
          id: 101,
          plate_appearance_number: 12,
          inning: 1,
          half_inning: 'top',
          inning_label: 'Top 1st',
          event: 'Single',
          event_type: 'single',
          description: 'Steven Kwan singles, scoring a run.',
          runs_scored: 1,
          runs_batted_in: 1,
          away_score: 1,
          home_score: 0,
          batter: { id: 20, full_name: 'Steven Kwan' },
          batting_team: { id: 2, abbreviation: 'CLE' },
        },
        {
          id: 102,
          plate_appearance_number: 24,
          inning: 2,
          half_inning: 'bottom',
          inning_label: 'Bottom 2nd',
          event: 'Double',
          event_type: 'double',
          description: 'Will Vest doubled, scoring a run.',
          runs_scored: 1,
          runs_batted_in: 1,
          away_score: 1,
          home_score: 1,
          batter: { id: 24, full_name: 'Will Vest' },
          batting_team: { id: 1, abbreviation: 'DET' },
        },
        {
          id: 103,
          plate_appearance_number: 38,
          inning: 4,
          half_inning: 'bottom',
          inning_label: 'Bottom 4th',
          event: 'Home Run',
          event_type: 'home_run',
          description: 'Riley Greene homered, scoring two runs.',
          runs_scored: 2,
          runs_batted_in: 2,
          away_score: 1,
          home_score: 3,
          batter: { id: 21, full_name: 'Riley Greene' },
          batting_team: { id: 1, abbreviation: 'DET' },
        },
      ],
      pitching_analysis: [
        {
          player: { id: 22, full_name: 'Tanner Bibee' },
          team: { id: 2, abbreviation: 'CLE', name: 'Cleveland Guardians' },
          home: false,
          starter: true,
          appearance_order: 1,
          innings_pitched: '6.1',
          decision: 'L (7-5)',
          pitch_data_available: true,
          pitch_count: 91,
          analyzed_pitch_count: 91,
          strike_count: 62,
          strike_percentage: 68.1,
          first_pitch_strikes: 17,
          first_pitch_opportunities: 24,
          first_pitch_strike_percentage: 70.8,
          swings: 45,
          whiffs: 12,
          whiff_percentage: 26.7,
          called_strikes: 15,
          csw_count: 27,
          csw_percentage: 29.7,
          average_velocity: 92.8,
          maximum_velocity: 97.1,
          chase_opportunities: 34,
          chases: 10,
          chase_percentage: 29.4,
          batters_faced: 24,
          pitch_usage: [
            {
              pitch_type: 'FF', pitch_name: '4-Seam Fastball', count: 45, percentage: 49.5,
              average_velocity: 94.8, maximum_velocity: 97.1, swings: 24, whiffs: 8,
              whiff_percentage: 33.3, called_strikes: 7, csw_count: 15, csw_percentage: 33.3,
              batted_balls: 6, average_exit_velocity: 88.7,
            },
            {
              pitch_type: 'SL', pitch_name: 'Slider', count: 28, percentage: 30.8,
              average_velocity: 86.2, maximum_velocity: 88.4, swings: 18, whiffs: 6,
              whiff_percentage: 33.3, called_strikes: 4, csw_count: 10, csw_percentage: 35.7,
              batted_balls: 3, average_exit_velocity: 91.4,
            },
          ],
          times_through_order: {
            maximum: 3,
            plate_appearances: [
              { time: 1, batters_faced: 9 },
              { time: 2, batters_faced: 9 },
              { time: 3, batters_faced: 6 },
            ],
          },
        },
        {
          player: { id: 23, full_name: 'Tarik Skubal' },
          team: { id: 1, abbreviation: 'DET', name: 'Detroit Tigers' },
          home: true,
          starter: true,
          appearance_order: 1,
          innings_pitched: '7.0',
          decision: 'W (11-2)',
          pitch_data_available: true,
          pitch_count: 98,
          analyzed_pitch_count: 98,
          strike_count: 67,
          strike_percentage: 68.4,
          first_pitch_strikes: 18,
          first_pitch_opportunities: 25,
          first_pitch_strike_percentage: 72.0,
          swings: 48,
          whiffs: 16,
          whiff_percentage: 33.3,
          called_strikes: 14,
          csw_count: 30,
          csw_percentage: 30.6,
          average_velocity: 95.1,
          maximum_velocity: 99.2,
          chase_opportunities: 36,
          chases: 12,
          chase_percentage: 33.3,
          batters_faced: 25,
          pitch_usage: [
            {
              pitch_type: 'FF', pitch_name: '4-Seam Fastball', count: 52, percentage: 53.1,
              average_velocity: 96.4, maximum_velocity: 99.2, swings: 27, whiffs: 9,
              whiff_percentage: 33.3, called_strikes: 8, csw_count: 17, csw_percentage: 32.7,
              batted_balls: 7, average_exit_velocity: 84.6,
            },
          ],
          times_through_order: {
            maximum: 3,
            plate_appearances: [
              { time: 1, batters_faced: 9 },
              { time: 2, batters_faced: 9 },
              { time: 3, batters_faced: 7 },
            ],
          },
        },
      ],
      batted_ball_analysis: [
        {
          team: { id: 2, abbreviation: 'CLE', name: 'Cleveland Guardians' },
          home: false,
          batted_balls: 21,
          average_exit_velocity: 87.8,
          maximum_exit_velocity: 103.2,
          hard_hit_count: 7,
          hard_hit_percentage: 33.3,
          average_launch_angle: 9.4,
          estimated_woba: 0.286,
          barrel_count: 1,
          barrel_percentage: 4.8,
          distribution: {
            ground_ball: { count: 10, percentage: 47.6 },
            line_drive: { count: 5, percentage: 23.8 },
            fly_ball: { count: 6, percentage: 28.6 },
          },
          leaders: [
            {
              player: { id: 20, full_name: 'Steven Kwan' },
              batted_balls: 4,
              average_exit_velocity: 91.3,
              maximum_exit_velocity: 103.2,
              hard_hit_count: 2,
              hard_hit_percentage: 50.0,
              average_launch_angle: 12.5,
              estimated_woba: 0.412,
              barrel_count: 1,
              barrel_percentage: 25.0,
              distribution: {
                ground_ball: { count: 1, percentage: 25.0 },
                line_drive: { count: 2, percentage: 50.0 },
                fly_ball: { count: 1, percentage: 25.0 },
              },
            },
          ],
        },
        {
          team: { id: 1, abbreviation: 'DET', name: 'Detroit Tigers' },
          home: true,
          batted_balls: 24,
          average_exit_velocity: 92.1,
          maximum_exit_velocity: 108.7,
          hard_hit_count: 12,
          hard_hit_percentage: 50.0,
          average_launch_angle: 15.8,
          estimated_woba: 0.387,
          barrel_count: 3,
          barrel_percentage: 12.5,
          distribution: {
            ground_ball: { count: 8, percentage: 33.3 },
            line_drive: { count: 7, percentage: 29.2 },
            fly_ball: { count: 9, percentage: 37.5 },
          },
          leaders: [
            {
              player: { id: 21, full_name: 'Riley Greene' },
              batted_balls: 4,
              average_exit_velocity: 99.2,
              maximum_exit_velocity: 108.7,
              hard_hit_count: 3,
              hard_hit_percentage: 75.0,
              average_launch_angle: 21.4,
              estimated_woba: 0.621,
              barrel_count: 2,
              barrel_percentage: 50.0,
              distribution: {
                ground_ball: { count: 1, percentage: 25.0 },
                line_drive: { count: 1, percentage: 25.0 },
                fly_ball: { count: 2, percentage: 50.0 },
              },
            },
          ],
        },
      ],
      situational_analysis: {
        high_leverage_definition: 'Plate appearances with an absolute win-probability change of at least 10 percentage points.',
        teams: [
          {
            team: { id: 2, abbreviation: 'CLE', name: 'Cleveland Guardians' },
            home: false,
            situations: {
              runners_in_scoring_position: situation({ plate_appearances: 5, at_bats: 5, hits: 1, strikeouts: 2, runs_batted_in: 1, batting_average: 0.2, on_base_percentage: 0.2 }),
              two_outs: situation({ plate_appearances: 12, at_bats: 10, hits: 2, walks: 2, strikeouts: 4, batting_average: 0.2, on_base_percentage: 0.333 }),
              bases_loaded: situation(),
              leadoff_hitters: situation({ plate_appearances: 5, at_bats: 4, hits: 2, walks: 1, strikeouts: 1, batting_average: 0.5, on_base_percentage: 0.6 }),
              pinch_hitters: situation({ plate_appearances: 1, at_bats: 1, strikeouts: 1, batting_average: 0.0, on_base_percentage: 0.0 }),
              high_leverage: situation({ plate_appearances: 2, at_bats: 2, hits: 1, runs_batted_in: 1, batting_average: 0.5, on_base_percentage: 0.5 }),
            },
            batting_order_trips: [
              { trip: 1, ...situation({ plate_appearances: 9, at_bats: 8, hits: 3, walks: 1, strikeouts: 2, batting_average: 0.375, on_base_percentage: 0.444 }) },
              { trip: 2, ...situation({ plate_appearances: 9, at_bats: 9, hits: 1, strikeouts: 3, batting_average: 0.111, on_base_percentage: 0.111 }) },
            ],
          },
          {
            team: { id: 1, abbreviation: 'DET', name: 'Detroit Tigers' },
            home: true,
            situations: {
              runners_in_scoring_position: situation({ plate_appearances: 6, at_bats: 6, hits: 2, strikeouts: 1, runs_batted_in: 3, batting_average: 0.333, on_base_percentage: 0.333 }),
              two_outs: situation({ plate_appearances: 11, at_bats: 9, hits: 3, walks: 2, strikeouts: 2, runs_batted_in: 2, batting_average: 0.333, on_base_percentage: 0.455 }),
              bases_loaded: situation({ plate_appearances: 1, at_bats: 1, hits: 1, runs_batted_in: 2, batting_average: 1.0, on_base_percentage: 1.0 }),
              leadoff_hitters: situation({ plate_appearances: 4, at_bats: 4, hits: 1, strikeouts: 1, batting_average: 0.25, on_base_percentage: 0.25 }),
              pinch_hitters: situation({ plate_appearances: 1, walks: 1, on_base_percentage: 1.0 }),
              high_leverage: situation({ plate_appearances: 2, at_bats: 2, hits: 1, runs_batted_in: 2, batting_average: 0.5, on_base_percentage: 0.5 }),
            },
            batting_order_trips: [
              { trip: 1, ...situation({ plate_appearances: 9, at_bats: 8, hits: 2, walks: 1, strikeouts: 2, batting_average: 0.25, on_base_percentage: 0.333 }) },
              { trip: 2, ...situation({ plate_appearances: 9, at_bats: 8, hits: 4, walks: 1, strikeouts: 1, runs_batted_in: 3, batting_average: 0.5, on_base_percentage: 0.556 }) },
            ],
          },
        ],
        turning_point: {
          type: 'win_probability', inning_label: 'Bottom 4th',
          description: 'Riley Greene homered, scoring two runs.',
          batter: { id: 21, full_name: 'Riley Greene' },
          batting_team: { id: 1, abbreviation: 'DET', name: 'Detroit Tigers' },
          away_score: 1, home_score: 3, runs_scored: 2,
          home_win_probability_change: 0.287,
          benefiting_team: { id: 1, abbreviation: 'DET', name: 'Detroit Tigers' },
        },
      },
      plate_appearances: [
        {
          id: 101, at_bat_index: 0, plate_appearance_number: 1, inning: 1, half_inning: 'top',
          event: 'Single', event_type: 'single', description: 'Steven Kwan singles, scoring a run.',
          runs_batted_in: 1, away_score: 1, home_score: 0, outs_after: 0, complete: true,
          batter: { id: 20, full_name: 'Steven Kwan' }, pitcher: { id: 23, full_name: 'Tarik Skubal' },
          batting_team: { id: 2, abbreviation: 'CLE' }, fielding_team: { id: 1, abbreviation: 'DET' },
          pitches: [
            { id: 1001, pitch_number: 1, balls: 0, strikes: 0, pitch_type: 'FF', pitch_name: '4-Seam Fastball', description: 'called_strike', release_speed: 96.8 },
            { id: 1002, pitch_number: 2, balls: 0, strikes: 1, pitch_type: 'SL', pitch_name: 'Slider', description: 'hit_into_play', release_speed: 87.2, launch_speed: 101.4, launch_angle: 18.2, hit_distance_sc: 287, bb_type: 'line_drive', estimated_woba_using_speedangle: 0.642 },
          ],
        },
        {
          id: 102, at_bat_index: 1, plate_appearance_number: 2, inning: 1, half_inning: 'bottom',
          event: 'Strikeout', event_type: 'strikeout', description: 'Riley Greene strikes out swinging.',
          runs_batted_in: 0, away_score: 1, home_score: 0, outs_after: 1, complete: true,
          batter: { id: 21, full_name: 'Riley Greene' }, pitcher: { id: 22, full_name: 'Tanner Bibee' },
          batting_team: { id: 1, abbreviation: 'DET' }, fielding_team: { id: 2, abbreviation: 'CLE' },
          pitches: [
            { id: 1003, pitch_number: 1, balls: 0, strikes: 0, pitch_type: 'SL', pitch_name: 'Slider', description: 'swinging_strike', release_speed: 86.7 },
          ],
        },
      ],
      line_score: {
        current_inning: 9,
        current_inning_ordinal: '9th',
        inning_state: 'End',
        innings: [
          { number: 1, ordinal: '1st', away: { runs: 1 }, home: { runs: 0 } },
          { number: 2, ordinal: '2nd', away: { runs: 0 }, home: { runs: 3 } },
        ],
        totals: {
          away: { runs: 1, hits: 5, errors: 0 },
          home: { runs: 3, hits: 8, errors: 1 },
        },
      },
      batting_lines: [
        {
          id: 1, home: false, player: { id: 20, full_name: 'Steven Kwan' }, position: 'LF',
          at_bats: 4, runs: 1, hits: 2, doubles: 1, triples: 0, home_runs: 0,
          runs_batted_in: 1, walks: 0, strikeouts: 1, batting_average: '0.3010', ops: '0.8120',
          season_stats: { atBats: 512, runs: 84, hits: 154, homeRuns: 8, rbi: 54, avg: '.301' },
        },
        {
          id: 2, home: true, player: { id: 21, full_name: 'Riley Greene' }, position: 'CF',
          at_bats: 4, runs: 1, hits: 2, doubles: 0, triples: 0, home_runs: 1,
          runs_batted_in: 3, walks: 0, strikeouts: 1, batting_average: '0.2870', ops: '0.8420',
        },
      ],
      box_score_notes: {
        away: {
          batting: [
            { label: '2B', entries: [{ player: { id: 20, full_name: 'Steven Kwan' }, value: 1, season_value: 12 }], value: '1' },
            { label: 'TB', entries: [{ player: { id: 20, full_name: 'Steven Kwan' }, value: 3, season_value: 999 }], value: '3' },
            { label: 'Team RISP', value: '1-for-5' },
          ],
          fielding: [{ label: 'DP', value: '1' }],
        },
        home: {
          batting: [{ label: 'HR', entries: [{ player: { id: 21, full_name: 'Riley Greene' }, value: 1 }], value: '1' }],
          fielding: [{ label: 'Errors', value: '1' }],
        },
      },
      pitching_lines: [
        {
          id: 3, home: false, player: { id: 22, full_name: 'Tanner Bibee' }, innings_pitched: '6.1',
          hits: 5, runs: 3, earned_runs: 3, walks: 2, strikeouts: 7, home_runs: 1,
          pitches: 91, strikes: 62, era: '3.456', whip: '1.234', decision: 'L (7-5)',
        },
        {
          id: 4, home: true, player: { id: 23, full_name: 'Tarik Skubal' }, innings_pitched: '7.0',
          hits: 4, runs: 1, earned_runs: 1, walks: 1, strikeouts: 9, home_runs: 0,
          pitches: 98, strikes: 67, era: '2.012', whip: '0.987', decision: 'W (11-2)',
        },
      ],
    },
  },
}

afterEach(() => vi.unstubAllGlobals())

describe('GameSummaryView', () => {
  it('organizes game details into accessible analytical tabs', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))
    const wrapper = mount(GameSummaryView, {
      props: { gameId: '80' },
      global: { components: { RouterLink } },
    })
    await flushPromises()

    const overviewTab = wrapper.get('[data-test="game-tab-overview"]')
    const boxScoreTab = wrapper.get('[data-test="game-tab-box-score"]')
    const pitchingTab = wrapper.get('[data-test="game-tab-pitching"]')
    const battedBallTab = wrapper.get('[data-test="game-tab-batted-ball"]')
    const situationalTab = wrapper.get('[data-test="game-tab-situational"]')
    const playByPlayTab = wrapper.get('[data-test="game-tab-play-by-play"]')
    expect(overviewTab.attributes('aria-selected')).toBe('true')
    expect(wrapper.find('[data-test="game-panel-overview"]').exists()).toBe(true)
    expect(wrapper.find('[data-test="game-panel-box-score"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="game-panel-pitching"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="game-panel-batted-ball"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="game-panel-situational"]').exists()).toBe(false)
    expect(wrapper.find('[data-test="game-panel-play-by-play"]').exists()).toBe(false)
    expect(wrapper.get('.scoreboard__mlb-id').text()).toBe('MLB Game ID 823443')

    await boxScoreTab.trigger('click')
    expect(boxScoreTab.attributes('aria-selected')).toBe('true')
    expect(wrapper.find('[data-test="game-panel-box-score"]').exists()).toBe(true)
    expect(wrapper.find('[data-test="game-panel-overview"]').exists()).toBe(false)
    expect(wrapper.get('[data-test="game-scoreboard"]').isVisible()).toBe(true)

    await pitchingTab.trigger('click')
    expect(pitchingTab.attributes('aria-selected')).toBe('true')
    expect(wrapper.find('[data-test="game-panel-pitching"]').exists()).toBe(true)

    await battedBallTab.trigger('click')
    expect(battedBallTab.attributes('aria-selected')).toBe('true')
    expect(wrapper.find('[data-test="game-panel-batted-ball"]').exists()).toBe(true)

    await situationalTab.trigger('click')
    expect(situationalTab.attributes('aria-selected')).toBe('true')
    expect(wrapper.find('[data-test="game-panel-situational"]').exists()).toBe(true)

    await playByPlayTab.trigger('click')
    expect(playByPlayTab.attributes('aria-selected')).toBe('true')
    expect(wrapper.find('[data-test="game-panel-play-by-play"]').exists()).toBe(true)

    await playByPlayTab.trigger('keydown', { key: 'Home' })
    expect(overviewTab.attributes('aria-selected')).toBe('true')
    expect(wrapper.find('[data-test="game-panel-overview"]').exists()).toBe(true)
  })

  it('renders the final score, inning line, and team batting and pitching box scores', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => payload }))
    const wrapper = mount(GameSummaryView, {
      props: { gameId: '80' },
      global: { components: { RouterLink } },
    })
    await flushPromises()

    expect(fetch).toHaveBeenCalledWith('/api/games/80', expect.objectContaining({ headers: { Accept: 'application/json' } }))
    expect(wrapper.get('[data-test="game-scoreboard"]').text()).toContain('Cleveland Guardians')
    expect(wrapper.get('[data-test="game-scoreboard"]').text()).toContain('Detroit Tigers')
    const teamLogos = wrapper.findAll('.scoreboard__team-logo')
    const logoBadges = wrapper.findAll('.scoreboard__team-logo-badge')
    expect(logoBadges).toHaveLength(2)
    expect(logoBadges.every((badge) => badge.find('.scoreboard__team-logo').exists())).toBe(true)
    expect(teamLogos).toHaveLength(2)
    expect(teamLogos[0].attributes('src')).toContain('/team-logos/114.svg')
    expect(teamLogos[0].attributes('alt')).toBe('Cleveland Guardians logo')
    expect(teamLogos[1].attributes('src')).toContain('/team-logos/116.svg')
    expect(teamLogos[1].attributes('alt')).toBe('Detroit Tigers logo')

    expect(wrapper.get('[data-test="line-score"]').text()).toContain('End 9th')
    expect(wrapper.get('[data-test="line-score"]').text()).toContain('CLE')
    expect(wrapper.get('[data-test="line-score"]').text()).toContain('DET')
    const insights = wrapper.get('[data-test="game-insights"]').text()
    expect(insights).toContain('Tarik Skubal (W, 11-2)')
    expect(insights).toContain('Tanner Bibee (L, 7-5)')
    expect(insights).toContain('Will Vest (S, 1)')
    expect(insights).toContain('Hits · Errors')
    expect(insights).toContain('Walks · Strikeouts')
    expect(insights).toContain('1-5')
    expect(insights).toContain('2-6')
    const performers = wrapper.get('[data-test="key-performers"]').text()
    expect(performers).toContain('Key performers')
    expect(performers).toContain('Steven Kwan')
    expect(performers).toContain('Riley Greene')
    expect(performers).toContain('Tarik Skubal')
    expect(performers).toContain('Will Vest')
    expect(performers).toContain('1 HR')
    expect(performers).toContain('1.0 scoreless IP · 2 K')
    expect(performers).toContain('3 runs produced')
    const performerLinks = wrapper.findAllComponents(RouterLink).filter((link) => link.props('to')?.name === 'player-profile')
    expect(performerLinks.map((link) => link.props('to').params.id)).toEqual(expect.arrayContaining([20, 21, 23, 24]))
    const scoringTimeline = wrapper.get('[data-test="scoring-play-timeline"]')
    expect(scoringTimeline.text()).toContain('Top 1st')
    expect(scoringTimeline.text()).toContain('Steven Kwan — singles, scoring a run.')
    expect(scoringTimeline.text()).toContain('CLE 1')
    expect(scoringTimeline.text()).toContain('DET 0')
    expect(scoringTimeline.text()).toContain('Bottom 4th')
    expect(scoringTimeline.text()).toContain('Riley Greene — homered, scoring two runs.')
    expect(scoringTimeline.text()).toContain('CLE 1')
    expect(scoringTimeline.text()).toContain('DET 3')
    const scoringLinks = scoringTimeline.findAllComponents(RouterLink)
    expect(scoringLinks.map((link) => link.props('to').params.id)).toEqual([20, 24, 21])
    await wrapper.get('[data-test="game-tab-pitching"]').trigger('click')
    const pitchingAnalysis = wrapper.get('[data-test="pitching-analysis"]')
    expect(pitchingAnalysis.text()).toContain('Pitching analysis')
    expect(pitchingAnalysis.text()).toContain('Tanner Bibee')
    expect(pitchingAnalysis.text()).toContain('Tarik Skubal')
    expect(pitchingAnalysis.text()).toContain('68.1%')
    expect(pitchingAnalysis.text()).toContain('70.8%')
    expect(pitchingAnalysis.text()).toContain('26.7%')
    expect(pitchingAnalysis.text()).toContain('29.7%')
    expect(pitchingAnalysis.text()).toContain('92.8 mph')
    expect(pitchingAnalysis.text()).toContain('97.1 mph')
    expect(pitchingAnalysis.text()).toContain('29.4%')
    expect(pitchingAnalysis.text()).toContain('1st: 9 · 2nd: 9 · 3rd: 6')
    expect(pitchingAnalysis.text()).toContain('4-Seam Fastball')
    expect(pitchingAnalysis.text()).toContain('Slider')
    expect(pitchingAnalysis.text()).toContain('Pitch arsenal')
    expect(pitchingAnalysis.text()).toContain('Whiff%')
    expect(pitchingAnalysis.text()).toContain('CSW%')
    expect(pitchingAnalysis.text()).toContain('Avg EV')
    expect(pitchingAnalysis.text()).toContain('88.7 mph')
    expect(pitchingAnalysis.text()).toContain('8/24 swings')
    expect(pitchingAnalysis.text()).toContain('15/45 pitches')
    const pitcherLinks = pitchingAnalysis.findAllComponents(RouterLink)
    expect(pitcherLinks.map((link) => link.props('to').params.id)).toEqual([22, 23])
    await wrapper.get('[data-test="game-tab-batted-ball"]').trigger('click')
    const battedBallAnalysis = wrapper.get('[data-test="batted-ball-analysis"]')
    expect(battedBallAnalysis.text()).toContain('Batted-ball analysis')
    expect(battedBallAnalysis.text()).toContain('Cleveland Guardians')
    expect(battedBallAnalysis.text()).toContain('Detroit Tigers')
    expect(battedBallAnalysis.text()).toContain('87.8 mph')
    expect(battedBallAnalysis.text()).toContain('108.7 mph')
    expect(battedBallAnalysis.text()).toContain('50.0%')
    expect(battedBallAnalysis.text()).toContain('15.8°')
    expect(battedBallAnalysis.text()).toContain('.387')
    expect(battedBallAnalysis.text()).toContain('Ground balls')
    expect(battedBallAnalysis.text()).toContain('Line drives')
    expect(battedBallAnalysis.text()).toContain('Fly balls')
    const battedBallLinks = battedBallAnalysis.findAllComponents(RouterLink)
    expect(battedBallLinks.map((link) => link.props('to').params.id)).toEqual([20, 21])
    await wrapper.get('[data-test="game-tab-situational"]').trigger('click')
    const situationalAnalysis = wrapper.get('[data-test="situational-analysis"]')
    expect(situationalAnalysis.text()).toContain('Situational performance')
    expect(situationalAnalysis.text()).toContain('Runners in scoring position')
    expect(situationalAnalysis.text()).toContain('Two outs')
    expect(situationalAnalysis.text()).toContain('Bases loaded')
    expect(situationalAnalysis.text()).toContain('Leadoff hitters')
    expect(situationalAnalysis.text()).toContain('Pinch hitters')
    expect(situationalAnalysis.text()).toContain('High leverage')
    expect(situationalAnalysis.text()).toContain('Performance by batting-order trip')
    expect(situationalAnalysis.text()).toContain('1st trip')
    expect(situationalAnalysis.text()).toContain('Turning point · Bottom 4th')
    expect(situationalAnalysis.text()).toContain('28.7 WPA points toward DET')
    expect(situationalAnalysis.text()).toContain('Riley Greene')
    const turningPointLinks = wrapper.get('[data-test="turning-point"]').findAllComponents(RouterLink)
    expect(turningPointLinks.map((link) => link.props('to').params.id)).toEqual([21])
    await wrapper.get('[data-test="game-tab-play-by-play"]').trigger('click')
    const playByPlay = wrapper.get('[data-test="play-by-play"]')
    expect(playByPlay.text()).toContain('Play-by-play')
    expect(playByPlay.text()).toContain('Top 1st')
    expect(playByPlay.text()).toContain('Bottom 1st')
    expect(playByPlay.text()).toContain('Steven Kwan')
    expect(playByPlay.text()).toContain('Tarik Skubal')
    expect(playByPlay.text()).toContain('CLE 1')
    expect(playByPlay.text()).toContain('DET 0')
    expect(playByPlay.text()).toContain('0-0')
    expect(playByPlay.text()).toContain('0-1')
    expect(playByPlay.text()).toContain('4-Seam Fastball')
    expect(playByPlay.text()).toContain('96.8 mph')
    expect(playByPlay.text()).toContain('Hit Into Play')
    expect(playByPlay.text()).toContain('101.4 mph')
    expect(playByPlay.text()).toContain('18.2°')
    expect(playByPlay.text()).toContain('287 ft')
    expect(playByPlay.text()).toContain('.642')
    expect(playByPlay.findAll('details')).toHaveLength(2)
    expect(playByPlay.findAll('summary')).toHaveLength(2)
    const playLinks = playByPlay.findAllComponents(RouterLink)
    expect(playLinks.map((link) => link.props('to').params.id)).toEqual([20, 23, 21, 22])
    await wrapper.get('[data-test="game-tab-box-score"]').trigger('click')
    const boxScore = wrapper.get('[data-test="box-score"]').text()
    expect(boxScore).toContain('Steven Kwan')
    expect(boxScore).toContain('Riley Greene')
    expect(boxScore).toContain('Tanner Bibee')
    expect(boxScore).toContain('Tarik Skubal')
    expect(boxScore).toContain('.842')
    expect(boxScore).not.toContain('0.842')
    expect(boxScore).toContain('2.01')
    expect(boxScore).toContain('0.99')
    expect(boxScore).toContain('Team RISP')
    expect(boxScore).toContain('1-for-5')
    expect(boxScore).toContain('Errors')
    expect(boxScore).toContain('Steven Kwan (12)')
    expect(boxScore).toContain('Steven Kwan 3')
    expect(boxScore).not.toContain('(999)')
    expect(boxScore).not.toContain('Season:')
  })

  it('shows a useful error when the game does not exist', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 404 }))
    const wrapper = mount(GameSummaryView, {
      props: { gameId: '999' },
      global: { components: { RouterLink } },
    })
    await flushPromises()

    expect(wrapper.get('[data-test="game-summary-error"]').text()).toContain('That game could not be found')
  })

  it('renders missing rate statistics as unavailable instead of zero', async () => {
    const missingRatesPayload = structuredClone(payload)
    missingRatesPayload.data.details.batting_lines.forEach((line) => {
      line.batting_average = null
      line.ops = null
    })
    missingRatesPayload.data.details.pitching_lines.forEach((line) => {
      line.era = null
      line.whip = null
    })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => missingRatesPayload }))
    const wrapper = mount(GameSummaryView, {
      props: { gameId: '80' },
      global: { components: { RouterLink } },
    })
    await flushPromises()

    await wrapper.get('[data-test="game-tab-box-score"]').trigger('click')
    const boxScore = wrapper.get('[data-test="box-score"]').text()
    expect(boxScore).not.toContain('0.000')
    expect(boxScore).toContain('—')
  })
})
