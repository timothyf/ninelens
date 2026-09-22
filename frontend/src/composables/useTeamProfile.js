import { computed, ref, watch } from 'vue'
import { adminRequestHeaders } from './apiAuth'
import { API_BASE_URL } from '../config'

function normalizeGame(game) {
  return {
    id: game.id,
    mlbId: game.mlb_id,
    officialDate: game.official_date,
    scheduledAt: game.scheduled_at,
    status: game.status,
    detailedStatus: game.detailed_status,
    venueName: game.venue_name,
    gameNumber: game.game_number,
    doubleheader: game.doubleheader,
    homeScore: game.home_score,
    awayScore: game.away_score,
    homeTeam: game.home_team,
    awayTeam: game.away_team,
    homeProbablePitcher: game.home_probable_pitcher,
    awayProbablePitcher: game.away_probable_pitcher,
  }
}

function normalizeMembership(membership) {
  return {
    id: membership.id,
    rosterStatus: membership.roster_status,
    statusDescription: membership.status_description,
    injured: membership.injured,
    jerseyNumber: membership.jersey_number,
    primaryPosition: membership.primary_position,
    pitchingRole: membership.pitching_role,
    startsOn: membership.starts_on,
    lastSyncedAt: membership.last_synced_at,
    player: {
      id: membership.player.id,
      mlbId: membership.player.mlb_id,
      fullName: membership.player.full_name,
      firstName: membership.player.first_name,
      lastName: membership.player.last_name,
      headshotUrl: membership.player.headshot_url,
    },
  }
}

function normalizeProfile(data) {
  const opponentPreparation = data.opponent_preparation || {}
  return {
    id: data.id,
    mlbId: data.mlb_id,
    name: data.name,
    abbreviation: data.abbreviation,
    teamName: data.team_name,
    locationName: data.location_name,
    shortName: data.short_name,
    logoUrl: data.logo_url,
    season: data.season,
    availableSeasons: data.available_seasons || [],
    record: data.record || {},
    divisionRank: data.division_rank || null,
    roster: (data.roster || []).map(normalizeMembership),
    rosters: {
      fortyMan: (data.rosters?.forty_man || data.roster || []).map(normalizeMembership),
      active: (data.rosters?.active || (data.roster || []).filter((membership) => membership.roster_status === 'active')).map(normalizeMembership),
    },
    rosterAsOf: data.roster_as_of,
    rosterSummary: data.roster_summary || {},
    recentGames: (data.recent_games || []).map(normalizeGame),
    upcomingGames: (data.upcoming_games || []).map(normalizeGame),
    scheduleGames: (data.schedule_games || []).map(normalizeGame),
    playerStats: {
      season: data.player_stats?.season || data.season,
      batting: {
        columns: data.player_stats?.batting?.columns || [],
        players: data.player_stats?.batting?.players || [],
      },
      pitching: {
        columns: data.player_stats?.pitching?.columns || [],
        players: data.player_stats?.pitching?.players || [],
      },
    },
    teamStats: {
      season: data.team_stats?.season || data.season,
      batting: {
        columns: data.team_stats?.batting?.columns || [],
        teams: data.team_stats?.batting?.teams || [],
      },
      pitching: {
        columns: data.team_stats?.pitching?.columns || [],
        teams: data.team_stats?.pitching?.teams || [],
      },
    },
    teamStatsSummary: data.team_stats_summary || {
      season: data.season,
      batting: {},
      pitching: {},
    },
    opponentPreparation: {
      opponent: opponentPreparation.opponent || null,
      recentPerformance: opponentPreparation.recent_performance || null,
      probableStarters: (opponentPreparation.probable_starters || []).map((starter) => ({
        player: starter.player,
        throws: starter.throws,
        sampleSize: starter.sample_size || 0,
        repertoire: starter.repertoire || [],
        handednessSplits: starter.handedness_splits || [],
        recentChanges: starter.recent_changes || [],
        evidence: starter.evidence || [],
      })),
    },
    opponentReports: (data.opponent_reports || []).map((report) => ({
      id: report.id,
      owner: report.owner || null,
      title: report.title,
      season: report.season,
      seriesStartsOn: report.series_starts_on,
      seriesEndsOn: report.series_ends_on,
      generatedAt: report.generated_at,
      opponent: report.opponent,
      probableStarterCount: report.probable_starter_count || 0,
    })),
    lineupScenarios: (data.lineup_scenarios || []).map((scenario) => ({
      id: scenario.id,
      owner: scenario.owner || null,
      name: scenario.name,
      scenarioDate: scenario.scenario_date,
      validatedAt: scenario.validated_at,
      entryCount: scenario.entry_count || 0,
      evaluationInputs: scenario.evaluation_inputs || {},
      totalScore: scenario.total_score,
      scoreBreakdown: scenario.score_breakdown || {},
    })),
    teamLeaders: {
      batting: data.team_leaders?.batting || [],
      pitching: data.team_leaders?.pitching || [],
    },
    sourceMetadata: {
      lastUpdatedAt: data.source_metadata?.last_updated_at,
      scheduleLastSyncedAt: data.source_metadata?.schedule_last_synced_at,
      rosterLastSyncedAt: data.source_metadata?.roster_last_synced_at,
      analyticsLastCalculatedAt: data.source_metadata?.analytics_last_calculated_at,
      sources: data.source_metadata?.sources || [],
    },
    performanceDashboard: {
      rankings: data.performance_dashboard?.rankings || { offense: {}, pitching: {}, context: {} },
      recentForm: data.performance_dashboard?.recent_form || {},
      homeRoadSplits: data.performance_dashboard?.home_road_splits || { home: {}, road: {} },
      platoonSplits: data.performance_dashboard?.platoon_splits || { offense: {}, pitching: {} },
      starterBullpen: data.performance_dashboard?.starter_bullpen || { starters: {}, bullpen: {} },
      oneRunPerformance: data.performance_dashboard?.one_run_performance || {},
      analyticsCoverage: data.performance_dashboard?.analytics_coverage || {
        complete: true,
        completed_game_count: 0,
        complete_pitching_game_count: 0,
        missing_game_count: 0,
        missing_games: [],
      },
      strengths: data.performance_dashboard?.strengths || [],
      concerns: data.performance_dashboard?.concerns || [],
    },
  }
}

export function useTeamProfile(teamIdRef, seasonRef, tabRef) {
  const team = ref(null)
  const loading = ref(false)
  const error = ref('')
  let requestCounter = 0

  async function load() {
    const teamId = teamIdRef.value
    const requestId = ++requestCounter
    if (!teamId) {
      error.value = 'A team id is required.'
      team.value = null
      return
    }

    loading.value = true
    error.value = ''
    const season = seasonRef?.value
    const params = new URLSearchParams({ include: tabRef?.value || "overview" })
    if (season) params.set("season", season)
    const query = `?${params}`

    try {
      const response = await fetch(`${API_BASE_URL}/api/teams/${encodeURIComponent(teamId)}${query}`, {
        headers: adminRequestHeaders({ Accept: 'application/json' }),
      })
      if (!response.ok) throw new Error(`Request failed with status ${response.status}`)

      const payload = await response.json()
      if (requestId === requestCounter) team.value = normalizeProfile(payload.data)
    } catch (fetchError) {
      if (requestId !== requestCounter) return
      team.value = null
      error.value = fetchError.message.includes('404')
        ? 'That team could not be found.'
        : 'Unable to load this team profile. Confirm the Rails API is running and reachable.'
      console.error(fetchError)
    } finally {
      if (requestId === requestCounter) loading.value = false
    }
  }

  watch([teamIdRef, ...(seasonRef ? [seasonRef] : []), ...(tabRef ? [tabRef] : [])], load, { immediate: true })

  return {
    team: computed(() => team.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    refresh: load,
  }
}
