import { computed, nextTick, ref } from 'vue'
import { flushPromises } from '@vue/test-utils'

import { usePlayerSeasonStats } from '../usePlayerSeasonStats'

describe('usePlayerSeasonStats', () => {
  function deferredResponse(payload) {
    let resolve
    const promise = new Promise((promiseResolve) => {
      resolve = promiseResolve
    })

    return {
      promise,
      resolve: () =>
        resolve({
          ok: true,
          json: async () => payload,
        }),
    }
  }

  it('fetches rows and normalizes metadata from the API', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        data: [
          {
            id: 1,
            value: '3.2',
          },
        ],
        meta: {
          page: 2,
          per_page: 12,
          total_count: 45,
          total_pages: 4,
          sort: '-homeRuns',
          filters: { category: 'batting' },
          category: 'batting',
          data_range: { type: 'season', start: 1970, end: 2026 },
          available_seasons: [2026, 2025, 2024],
          available_teams: [{ id: 1, abbreviation: 'DET', short_name: 'Tigers' }],
          columns: [{ key: 'homeRuns', label: 'HR', align: 'numeric' }],
        },
      }),
    })

    vi.stubGlobal('fetch', fetchMock)

    const query = computed(() => ({
      view: 'leaderboard',
      page: 2,
      perPage: 12,
      sort: '-homeRuns',
      filters: {
        category: 'batting',
        player_name: 'miguel',
      },
    }))

    const { rows, meta, loading, error } = usePlayerSeasonStats(query)

    await flushPromises()

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/player_season_stats?view=leaderboard&page=2&per_page=12&sort=-homeRuns&defer_facets=true&filter%5Bcategory%5D=batting&filter%5Bplayer_name%5D=miguel',
      {
        headers: {
          Accept: 'application/json',
        },
      },
    )
    expect(rows.value).toEqual([{ id: 1, value: '3.2' }])
    expect(meta.value).toEqual({
      page: 2,
      perPage: 12,
      totalCount: 45,
      totalPages: 4,
      sort: '-homeRuns',
      filters: { category: 'batting' },
      category: 'batting',
      dataRange: { type: 'season', start: 1970, end: 2026 },
      availableSeasons: [2026, 2025, 2024],
      availableTeams: [{ id: 1, abbreviation: 'DET', short_name: 'Tigers' }],
      availablePositions: [],
      columns: [{ key: 'homeRuns', label: 'HR', align: 'numeric' }],
      facetsComplete: true,
    })
    expect(loading.value).toBe(false)
    expect(error.value).toBe('')
  })

  it('renders rows before loading deferred leaderboard facets', async () => {
    const rowsResponse = deferredResponse({
      data: [{ id: 1, player: { full_name: 'Barry Bonds' } }],
      meta: {
        page: 1,
        per_page: 15,
        sort: '-homeRuns',
        category: 'batting',
        columns: [{ key: 'homeRuns', label: 'HR', align: 'numeric' }],
        facets_complete: false,
      },
    })
    const facetsResponse = deferredResponse({
      data: [],
      meta: {
        page: 1,
        per_page: 15,
        total_count: 57355,
        total_pages: 3824,
        sort: '-homeRuns',
        category: 'batting',
        available_seasons: [2026, 2025],
        available_teams: [{ id: 1, abbreviation: 'DET' }],
        columns: [{ key: 'homeRuns', label: 'HR', align: 'numeric' }],
        facets_complete: true,
      },
    })
    vi.stubGlobal('fetch', vi.fn().mockReturnValueOnce(rowsResponse.promise).mockReturnValueOnce(facetsResponse.promise))

    const query = computed(() => ({
      view: 'leaderboard',
      page: 1,
      perPage: 15,
      sort: '-homeRuns',
      filters: { category: 'batting' },
    }))
    const { rows, meta, loading } = usePlayerSeasonStats(query)

    rowsResponse.resolve()
    await flushPromises()

    expect(rows.value[0].player.full_name).toBe('Barry Bonds')
    expect(loading.value).toBe(false)
    expect(meta.value.facetsComplete).toBe(false)

    facetsResponse.resolve()
    await flushPromises()

    expect(meta.value.totalCount).toBe(57355)
    expect(meta.value.availableSeasons).toEqual([2026, 2025])
    expect(meta.value.facetsComplete).toBe(true)
  })

  it('ignores stale responses when the player filter changes quickly', async () => {
    const broadSearch = deferredResponse({
      data: [
        {
          id: 1,
          player: { full_name: 'Kal Daniels' },
        },
      ],
      meta: {
        page: 1,
        per_page: 15,
        total_count: 1,
        total_pages: 1,
        filters: { player_name: 'Al' },
      },
    })
    const preciseSearch = deferredResponse({
      data: [
        {
          id: 2,
          player: { full_name: 'Al Kaline' },
        },
      ],
      meta: {
        page: 1,
        per_page: 15,
        total_count: 1,
        total_pages: 1,
        filters: { player_name: 'Al Kaline' },
      },
    })
    const fetchMock = vi.fn().mockReturnValueOnce(broadSearch.promise).mockReturnValueOnce(preciseSearch.promise)
    vi.stubGlobal('fetch', fetchMock)

    const playerName = ref('Al')
    const query = computed(() => ({
      view: 'leaderboard',
      page: 1,
      perPage: 15,
      sort: '-homeRuns',
      filters: {
        category: 'batting',
        player_name: playerName.value,
      },
    }))

    const { rows, meta, loading, error } = usePlayerSeasonStats(query)
    playerName.value = 'Al Kaline'
    await nextTick()

    preciseSearch.resolve()
    await flushPromises()

    expect(rows.value).toEqual([{ id: 2, player: { full_name: 'Al Kaline' } }])
    expect(meta.value.filters).toEqual({ player_name: 'Al Kaline' })
    expect(loading.value).toBe(false)
    expect(error.value).toBe('')

    broadSearch.resolve()
    await flushPromises()

    expect(rows.value).toEqual([{ id: 2, player: { full_name: 'Al Kaline' } }])
    expect(meta.value.filters).toEqual({ player_name: 'Al Kaline' })
    expect(loading.value).toBe(false)
  })

  it('exposes a friendly error when the request fails', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: false,
        status: 500,
      }),
    )
    const query = computed(() => ({
      view: 'leaderboard',
      page: 1,
      perPage: 12,
      sort: 'season',
      filters: {},
    }))

    const { rows, meta, error } = usePlayerSeasonStats(query)

    await flushPromises()
    await nextTick()

    expect(rows.value).toEqual([])
    expect(meta.value.totalCount).toBe(0)
    expect(error.value).toContain('Unable to load player season stats')
  })
})
