import { computed, ref } from 'vue'
import { flushPromises } from '@vue/test-utils'
import { vi } from 'vitest'

import { usePlayerProfile } from '../usePlayerProfile'

describe('usePlayerProfile', () => {
  it('fetches and normalizes the unified player profile', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
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
            bats: 'L',
            throws: 'L',
            formatted_height: `6' 3"`,
            weight_pounds: 200,
            source_name: 'MLB Stats API',
          },
          positions: { primary: { abbreviation: 'CF', name: 'Outfielder' }, secondary: [], assignments: [] },
          season_overview: {
            season: 2026,
            category: 'batting',
            preferred_category: 'batting',
            stats: [{ key: 'homeRuns', label: 'HR', value: '18.0' }],
          },
          career_overview: {
            category: 'batting',
            preferred_category: 'batting',
            first_season: 2022,
            last_season: 2026,
            season_count: 5,
            stats: [{ key: 'homeRuns', label: 'HR', value: '82' }],
          },
          current_membership: {
            id: 8,
            team: { id: 1, mlb_id: 116, name: 'Detroit Tigers', abbreviation: 'DET' },
            roster_status: 'active',
            starts_on: '2026-03-26',
          },
          team_history: [],
          trades: [
            {
              id: 7,
              mlb_transaction_id: 642337,
              occurred_on: '2022-08-02',
              description: 'Two-team trade',
              participants: [
                {
                  player: { id: 9, mlb_id: 665742, full_name: 'Juan Soto' },
                  from_team: { id: 2, mlb_id: 120, name: 'Washington Nationals' },
                  to_team: { id: 3, mlb_id: 135, name: 'San Diego Padres' },
                },
                {
                  player: { id: 10, mlb_id: 695578, full_name: 'James Wood' },
                  from_team: { id: 3, mlb_id: 135, name: 'San Diego Padres' },
                  to_team: { id: 2, mlb_id: 120, name: 'Washington Nationals' },
                },
              ],
            },
          ],
          recent_pitch_indicators: {
            sample_size: 100,
            primary_role: 'batter',
            batting: { pitches_seen: 100, average_exit_velocity: 91.2 },
            pitching: { pitch_count: 0 },
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
                percentile: 82.5,
                sample_size: 480,
              },
            ],
          },
          source_metadata: {
            last_updated_at: '2026-07-14T12:00:00Z',
            sources: ['MLB Stats API'],
            datasets: [
              { name: 'profile', source_name: 'MLB Stats API', last_updated_at: '2026-07-14T12:00:00Z' },
            ],
          },
        },
      }),
    })
    vi.stubGlobal('fetch', fetchMock)

    const { player, loading, error } = usePlayerProfile(computed(() => '42'))
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledWith('/api/players/42?sections=core&view=profile', {
      headers: { Accept: 'application/json' },
    })
    expect(player.value).toMatchObject({
      id: 42,
      mlbId: 680776,
      fullName: 'Riley Greene',
      team: { abbreviation: 'DET' },
      displayTeam: { abbreviation: 'DET' },
      externalIds: { baseballReference: 'greenri03', fangraphs: '25976' },
      currentMembership: { rosterStatus: 'active' },
      seasonOverview: { season: 2026, category: 'batting' },
      careerOverview: { category: 'batting', firstSeason: 2022, lastSeason: 2026, seasonCount: 5 },
      pitchIndicators: { primaryRole: 'batter' },
      trades: [
        {
          mlbTransactionId: 642337,
          sides: [
            { team: { name: 'San Diego Padres' }, players: [{ fullName: 'Juan Soto' }] },
            { team: { name: 'Washington Nationals' }, players: [{ fullName: 'James Wood' }] },
          ],
        },
      ],
      contextualBenchmarks: {
        available: true,
        sourceStartDate: '2026-03-26',
        sourceEndDate: '2026-07-14',
        metrics: [
          expect.objectContaining({ metricKey: 'ops', rawValue: 0.842, mlbAverage: 0.72, percentile: 82.5 }),
        ],
      },
    })
    expect(player.value.sourceMetadata.datasets[0]).toEqual({
      name: 'profile',
      sourceName: 'MLB Stats API',
      lastUpdatedAt: '2026-07-14T12:00:00Z',
    })
    expect(loading.value).toBe(false)
    expect(error.value).toBe('')
  })

  it('exposes a useful not-found message', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 404 }))

    const { player, error } = usePlayerProfile(computed(() => '404'))
    await flushPromises()

    expect(player.value).toBeNull()
    expect(error.value).toBe('That player could not be found.')
  })

  it('reloads only analytics when the analysis range changes', async () => {
    const analysisOptions = ref({ range: 'season', paWindow: 50, pitchWindow: 100 })
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ data: { id: 42, full_name: 'Riley Greene' } }),
    })
    vi.stubGlobal('fetch', fetchMock)

    usePlayerProfile(computed(() => '42'), analysisOptions, { loadAnalyticsAfterInitial: false })
    await flushPromises()
    analysisOptions.value = { range: '7', paWindow: 50, pitchWindow: 100 }
    await flushPromises()

    expect(fetchMock.mock.calls.map(([url]) => url)).toEqual([
      '/api/players/42?sections=core&view=profile',
      '/api/players/42?range=7&pa_window=50&pitch_window=100&sections=analytics&view=section',
    ])
  })

  it('keeps the newest analytics when range requests finish out of order', async () => {
    const analysisOptions = ref({ range: 'season' })
    const pending = new Map()
    vi.stubGlobal('fetch', vi.fn((url) => {
      if (url.includes('sections=core')) {
        return Promise.resolve({ ok: true, json: async () => ({ data: { id: 42 } }) })
      }
      return new Promise((resolve) => pending.set(new URLSearchParams(url.split('?')[1]).get('range'), resolve))
    }))

    const { player } = usePlayerProfile(computed(() => '42'), analysisOptions, { loadAnalyticsAfterInitial: false })
    await flushPromises()
    analysisOptions.value = { range: '7' }
    await flushPromises()
    analysisOptions.value = { range: '14' }
    await flushPromises()

    pending.get('14')({ ok: true, json: async () => ({ data: { analysis: { range: { preset: '14' } } } }) })
    await flushPromises()
    pending.get('7')({ ok: true, json: async () => ({ data: { analysis: { range: { preset: '7' } } } }) })
    await flushPromises()

    expect(player.value.analysis.range.preset).toBe('14')
  })
})
