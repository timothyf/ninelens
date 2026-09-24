import { computed, ref, watch } from 'vue'
import { API_BASE_URL } from '../config'

function normalizeTeam(team) {
  if (!team) return null

  return {
    id: team.id,
    mlbId: team.mlb_id,
    name: team.name,
    abbreviation: team.abbreviation,
    teamName: team.team_name,
    locationName: team.location_name,
    shortName: team.short_name,
  }
}

function normalizeMembership(membership) {
  if (!membership) return null

  return {
    id: membership.id,
    team: normalizeTeam(membership.team),
    startsOn: membership.starts_on,
    endsOn: membership.ends_on,
    current: membership.current,
    rosterStatus: membership.roster_status,
    injured: membership.injured,
    jerseyNumber: membership.jersey_number,
    primaryPosition: membership.primary_position,
    secondaryPositions: membership.secondary_positions || [],
    sourceName: membership.source_name,
    sourceStatusCode: membership.source_status_code,
    sourceStatusDescription: membership.source_status_description,
    lastSyncedAt: membership.last_synced_at,
  }
}

function normalizeTrade(trade) {
  const participants = (trade.participants || []).map((participant) => ({
    player: {
      id: participant.player?.id,
      mlbId: participant.player?.mlb_id,
      fullName: participant.player?.full_name,
    },
    fromTeam: normalizeTeam(participant.from_team),
    toTeam: normalizeTeam(participant.to_team),
  }))
  const sidesByTeam = new Map()

  participants.forEach((participant) => {
    const key = participant.toTeam?.mlbId || participant.toTeam?.name || 'unknown'
    const side = sidesByTeam.get(key) || { team: participant.toTeam, players: [] }
    side.players.push(participant.player)
    sidesByTeam.set(key, side)
  })

  return {
    id: trade.id,
    mlbTransactionId: trade.mlb_transaction_id,
    occurredOn: trade.occurred_on,
    description: trade.description,
    participants,
    sides: Array.from(sidesByTeam.values()),
  }
}

function normalizeProfile(data = {}) {
  const profile = data.profile
    ? {
        ...data.profile,
        birthDate: data.profile.birth_date,
        formattedHeight: data.profile.formatted_height,
        weightPounds: data.profile.weight_pounds,
        active: data.profile.active,
        lastPlayedDate: data.profile.last_played_date,
        draftYear: data.profile.draft_year,
        draftRound: data.profile.draft_round,
        draftRoundPickNumber: data.profile.draft_round_pick_number,
        draftPickNumber: data.profile.draft_pick_number,
        draftTeam: data.profile.draft_team,
        awards: (data.profile.awards || []).map((award) => ({
          id: award.id,
          name: award.name,
          season: award.season,
          date: award.date,
        })),
        allStarSelections: data.profile.all_star_selections || [],
        mlbDebutDate: data.profile.mlb_debut_date,
        headshotUrl: data.profile.headshot_url,
        sourceName: data.profile.source_name,
        lastSyncedAt: data.profile.last_synced_at,
      }
    : null
  const season = data.season_overview || {}
  const career = data.career_overview || {}
  const advancedStats = data.advanced_stats || {}
  const defensiveStats = data.defensive_stats || {}
  const indicators = data.recent_pitch_indicators || {}
  const benchmarks = data.contextual_benchmarks || {}
  const battedBallProfile = data.batted_ball_profile || {}
  const pitchArsenal = data.pitch_arsenal || {}
  const analysis = data.analysis || {}
  const trendEvents = data.trend_events || {}
  const similarPlayers = data.similar_players || {}
  const analysisRange = analysis.range || {}
  const source = data.source_metadata || {}

  return {
    id: data.id,
    mlbId: data.mlb_id,
    firstName: data.first_name,
    lastName: data.last_name,
    fullName: data.full_name,
    currentSalary: data.current_salary,
    currentSalarySeason: data.current_salary_season,
    team: normalizeTeam(data.team),
    displayTeam: normalizeTeam(data.display_team),
    externalIds: {
      baseballReference: data.external_ids?.baseball_reference,
      fangraphs: data.external_ids?.fangraphs,
    },
    profile,
    positions: data.positions || { primary: null, secondary: [], assignments: [] },
    seasonOverview: {
      season: season.season,
      category: season.category,
      preferredCategory: season.preferred_category,
      stats: season.stats || [],
      comparisonStats: season.comparison_stats || [],
    },
    careerOverview: {
      category: career.category,
      preferredCategory: career.preferred_category,
      firstSeason: career.first_season,
      lastSeason: career.last_season,
      seasonCount: career.season_count || 0,
      columns: career.columns || [],
      seasons: (career.seasons || []).map((seasonRow) => ({
        season: seasonRow.season,
        teams: (seasonRow.teams || []).map(normalizeTeam),
        stats: seasonRow.stats || [],
        statValues: Object.fromEntries((seasonRow.stats || []).map((stat) => [stat.key, stat.value])),
        teamRows: (seasonRow.team_rows || []).map((teamRow) => ({
          team: normalizeTeam(teamRow.team),
          stats: teamRow.stats || [],
          statValues: Object.fromEntries((teamRow.stats || []).map((stat) => [stat.key, stat.value])),
        })),
        totalStats: seasonRow.total_stats || seasonRow.stats || [],
        totalStatValues: Object.fromEntries((seasonRow.total_stats || seasonRow.stats || []).map((stat) => [stat.key, stat.value])),
      })),
      stats: career.stats || [],
      comparisonStats: career.comparison_stats || [],
      statValues: Object.fromEntries((career.stats || []).map((stat) => [stat.key, stat.value])),
    },
    gameLogs: {
      category: data.game_logs?.category || season.category || 'batting',
      batting: (data.game_logs?.batting || []).map(normalizeGameLog),
      pitching: (data.game_logs?.pitching || []).map(normalizeGameLog),
    },
    advancedStats: {
      category: advancedStats.category,
      groups: advancedStats.groups || [],
      seasons: (advancedStats.seasons || []).map((seasonRow) => ({
        season: seasonRow.season,
        teams: (seasonRow.teams || []).map(normalizeTeam),
        values: seasonRow.values || {},
        teamRows: (seasonRow.team_rows || []).map((teamRow) => ({
          team: normalizeTeam(teamRow.team),
          values: teamRow.values || {},
        })),
        totalValues: seasonRow.total_values || seasonRow.values || {},
      })),
      career: advancedStats.career || { values: {} },
    },
    defensiveStats: {
      season: defensiveStats.season,
      seasons: (defensiveStats.seasons || []).map((seasonRow) => ({
        outsAboveAverageApplicable: seasonRow.outs_above_average_applicable !== false,
        season: seasonRow.season,
        games: seasonRow.games,
        positions: (seasonRow.positions || [])
          .filter((positionRow) => positionRow.position?.trim().toUpperCase() !== 'DH')
          .map((positionRow) => ({
            position: positionRow.position,
            games: positionRow.games,
            innings: positionRow.innings,
            fieldingPercentage: positionRow.fielding_percentage,
            defensiveRunsSaved: positionRow.defensive_runs_saved,
            outsAboveAverage: positionRow.outs_above_average,
          })),
        fieldingPercentage: seasonRow.fielding_percentage,
        defensiveRunsSaved: seasonRow.defensive_runs_saved,
        outsAboveAverage: seasonRow.outs_above_average,
      })),
      positions: defensiveStats.positions || [],
      fieldingPercentage: defensiveStats.fielding_percentage,
      defensiveRunsSaved: defensiveStats.defensive_runs_saved,
      outsAboveAverage: defensiveStats.outs_above_average,
    },
    similarPlayers: {
      season: similarPlayers.season,
      category: similarPlayers.category,
      mode: similarPlayers.mode || similarPlayers.controls?.mode || 'season',
      methodology: similarPlayers.methodology,
      positionMismatchPenalty: similarPlayers.position_mismatch_penalty,
      controls: {
        availableSeasons: similarPlayers.controls?.available_seasons || [],
        mode: similarPlayers.controls?.mode || 'season',
        selectedSeason: similarPlayers.controls?.selected_season,
        minAge: similarPlayers.controls?.min_age,
        maxAge: similarPlayers.controls?.max_age,
        targetAge: similarPlayers.controls?.target_age,
        positionMatch: similarPlayers.controls?.position_match || 'any',
        positionOptions: (similarPlayers.controls?.position_options || []).map((option) => ({
          value: option.value,
          label: option.label,
        })),
      },
      modelMetrics: (similarPlayers.model_metrics || []).map((metric) => ({
        key: metric.key,
        label: metric.label,
        weight: metric.weight,
      })),
      matches: (similarPlayers.matches || []).map((match) => ({
        player: {
          id: match.player?.id,
          mlbId: match.player?.mlb_id,
          fullName: match.player?.full_name,
          headshotUrl: match.player?.headshot_url,
        },
        team: normalizeTeam(match.team),
        position: match.position,
        similarityScore: match.similarity_score,
        age: match.age,
        sharedMetricCount: match.shared_metric_count,
        samePositionType: match.same_position_type,
        whySimilar: match.why_similar || [],
        metricsUsed: (match.metrics_used || []).map((metric) => ({
          key: metric.key,
          label: metric.label,
          targetValue: metric.target_value,
          candidateValue: metric.candidate_value,
          weight: metric.weight,
          normalizedWeight: metric.normalized_weight,
          standardizedDifference: metric.standardized_difference,
        })),
        closestMetrics: (match.closest_metrics || []).map((metric) => ({
          key: metric.key,
          label: metric.label,
          targetValue: metric.target_value,
          candidateValue: metric.candidate_value,
          weight: metric.weight,
          normalizedWeight: metric.normalized_weight,
          standardizedDifference: metric.standardized_difference,
        })),
      })),
    },
    currentMembership: normalizeMembership(data.current_membership),
    teamHistory: (data.team_history || []).map(normalizeMembership),
    trades: (data.trades || []).map(normalizeTrade),
    pitchIndicators: {
      sampleSize: indicators.sample_size || 100,
      primaryRole: indicators.primary_role || 'batter',
      pitching: indicators.pitching || {},
      batting: indicators.batting || {},
    },
    battedBallProfile: {
      available: battedBallProfile.available === true,
      contactCount: battedBallProfile.contact_count || 0,
      pitcherMetrics: {
        available: battedBallProfile.pitcher_metrics?.available === true,
        battedBallCount: battedBallProfile.pitcher_metrics?.batted_ball_count || 0,
        groundBallPercentage: battedBallProfile.pitcher_metrics?.ground_ball_percentage,
        flyBallPercentage: battedBallProfile.pitcher_metrics?.fly_ball_percentage,
        groundBallToFlyBallRatio: battedBallProfile.pitcher_metrics?.ground_ball_to_fly_ball_ratio,
        lineDrivePercentage: battedBallProfile.pitcher_metrics?.line_drive_percentage,
        infieldFlyPercentage: battedBallProfile.pitcher_metrics?.infield_fly_percentage,
        pullPercentage: battedBallProfile.pitcher_metrics?.pull_percentage,
        hardHitPercentage: battedBallProfile.pitcher_metrics?.hard_hit_percentage,
        barrelPercentage: battedBallProfile.pitcher_metrics?.barrel_percentage,
        homeRunPerFlyBall: battedBallProfile.pitcher_metrics?.home_run_per_fly_ball,
        averageLaunchAngle: battedBallProfile.pitcher_metrics?.average_launch_angle,
        seasons: (battedBallProfile.pitcher_metrics?.seasons || []).map((season) => ({
          season: season.season,
          battedBallCount: season.batted_ball_count,
          groundBallPercentage: season.ground_ball_percentage,
          flyBallPercentage: season.fly_ball_percentage,
          groundBallToFlyBallRatio: season.ground_ball_to_fly_ball_ratio,
          lineDrivePercentage: season.line_drive_percentage,
          infieldFlyPercentage: season.infield_fly_percentage,
          pullPercentage: season.pull_percentage,
          hardHitPercentage: season.hard_hit_percentage,
          barrelPercentage: season.barrel_percentage,
          homeRunPerFlyBall: season.home_run_per_fly_ball,
          averageLaunchAngle: season.average_launch_angle,
        })),
      },
      sprayPoints: (battedBallProfile.spray_points || []).map((point) => ({
        x: point.x,
        y: point.y,
        event: point.event,
        battedBallType: point.batted_ball_type,
        exitVelocity: point.exit_velocity,
        launchAngle: point.launch_angle,
        hitDistance: point.hit_distance,
        gameDate: point.game_date,
      })),
      hitPoints: (battedBallProfile.hit_points || []).map((point) => ({
        x: point.x,
        y: point.y,
        event: point.event,
        battedBallType: point.batted_ball_type,
        exitVelocity: point.exit_velocity,
        launchAngle: point.launch_angle,
        hitDistance: point.hit_distance,
        gameDate: point.game_date,
      })),
    },
    pitchArsenal: {
      available: pitchArsenal.available === true,
      pitches: (pitchArsenal.pitches || []).map((pitch) => ({
        pitchType: pitch.pitch_type,
        pitchName: pitch.pitch_name,
        usagePercentage: pitch.usage_percentage,
        pitchCount: pitch.pitch_count,
        averageVelocity: pitch.average_velocity,
        maximumVelocity: pitch.maximum_velocity,
        spinRate: pitch.spin_rate,
        activeSpin: pitch.active_spin,
        verticalMovement: pitch.vertical_movement,
        horizontalMovement: pitch.horizontal_movement,
        zonePercentage: pitch.zone_percentage,
        chasePercentage: pitch.chase_percentage,
        whiffPercentage: pitch.whiff_percentage,
        hardHitPercentage: pitch.hard_hit_percentage,
        runValue: pitch.run_value,
      })),
    },
    batterSplits: {
      available: data.batter_splits?.available === true,
      dimensions: (data.batter_splits?.dimensions || []).map((dimension) => ({
        key: dimension.key,
        label: dimension.label,
        options: (dimension.options || []).map((option) => ({
          value: option.value,
          label: option.label,
          metrics: option.metrics || {},
        })),
      })),
    },
    pitcherSplits: {
      available: data.pitcher_splits?.available === true,
      dimensions: (data.pitcher_splits?.dimensions || []).map((dimension) => ({
        key: dimension.key,
        label: dimension.label,
        options: (dimension.options || []).map((option) => ({
          value: option.value,
          label: option.label,
          metrics: option.metrics || {},
        })),
      })),
    },
    contextualBenchmarks: {
      available: benchmarks.available === true,
      unavailableReason: benchmarks.unavailable_reason,
      sourceStartDate: benchmarks.source_start_date,
      sourceEndDate: benchmarks.source_end_date,
      calculationVersion: benchmarks.calculation_version,
      calculatedAt: benchmarks.calculated_at,
      metrics: (benchmarks.metrics || []).map((metric) => ({
        metricKey: metric.metric_key,
        metricGroup: metric.metric_group,
        displayName: metric.display_name,
        unit: metric.unit,
        directionality: metric.directionality,
        dimensionType: metric.dimension_type,
        dimensionValue: metric.dimension_value,
        rawValue: metric.raw_value,
        mlbAverage: metric.mlb_average,
        positionAverage: metric.position_average,
        positionKey: metric.position_key,
        pitcherRoleAverage: metric.pitcher_role_average,
        pitcherRoleKey: metric.pitcher_role_key,
        percentile: metric.percentile,
        positionPercentile: metric.position_percentile,
        pitcherRolePercentile: metric.pitcher_role_percentile,
        sampleSize: metric.sample_size,
        mlbSampleSize: metric.mlb_sample_size,
        mlbPlayerCount: metric.mlb_player_count,
        positionPlayerCount: metric.position_player_count,
        pitcherRolePlayerCount: metric.pitcher_role_player_count,
      })),
    },
    analysis: {
      range: {
        preset: analysisRange.preset || 'season',
        startDate: analysisRange.start_date,
        endDate: analysisRange.end_date,
        previousStartDate: analysisRange.previous_start_date,
        previousEndDate: analysisRange.previous_end_date,
        plateAppearanceWindow: analysisRange.plate_appearance_window || 50,
        pitchWindow: analysisRange.pitch_window || 100,
      },
      summary: analysis.summary || { current: { batting: {}, pitching: {} }, previous: { batting: {}, pitching: {} }, changes: {} },
      batting: normalizeTrendGroup(analysis.batting),
      pitching: normalizeTrendGroup(analysis.pitching),
    },
    trendEvents: {
      activeCount: trendEvents.active_count || 0,
      events: (trendEvents.events || []).map((event) => ({
        id: event.id,
        eventType: event.event_type,
        role: event.role,
        metricKey: event.metric_key,
        pitchType: event.pitch_type,
        direction: event.direction,
        severity: event.severity,
        status: event.status,
        unit: event.unit,
        baselineValue: event.baseline_value,
        currentValue: event.current_value,
        changeValue: event.change_value,
        thresholdValue: event.threshold_value,
        thresholds: event.thresholds || {},
        baselineSampleSize: event.baseline_sample_size,
        sampleSize: event.sample_size,
        baselineStartDate: event.baseline_start_date,
        baselineEndDate: event.baseline_end_date,
        currentStartDate: event.current_start_date,
        currentEndDate: event.current_end_date,
        onsetDate: event.onset_date,
        detectedAt: event.detected_at,
        lastObservedAt: event.last_observed_at,
        resolvedAt: event.resolved_at,
        supportingPitches: event.supporting_pitches || [],
        metadata: event.metadata || {},
      })),
    },
    sourceMetadata: {
      lastUpdatedAt: source.last_updated_at,
      sources: source.sources || [],
      datasets: (source.datasets || []).map((dataset) => ({
        name: dataset.name,
        sourceName: dataset.source_name,
        lastUpdatedAt: dataset.last_updated_at,
      })),
    },
  }
}

function normalizeGameLog(log = {}) {
  return {
    date: log.date,
    team: log.team,
    opponent: log.opponent,
    ...log,
  }
}

function normalizeTrendGroup(group = {}) {
  return {
    windowType: group.window_type,
    windowSize: group.window_size,
    totalObservations: group.total_observations || 0,
    charts: (group.charts || []).map((chart) => ({
      key: chart.key,
      title: chart.title,
      unit: chart.unit,
      series: (chart.series || []).map((series) => ({
        key: series.key,
        label: series.label,
        points: (series.points || []).map((point) => ({
          date: point.date,
          sequence: point.sequence,
          value: point.value,
          sampleSize: point.sample_size,
        })),
      })),
    })),
  }
}

export function usePlayerProfile(playerIdRef, analysisOptionsRef = null, { includeCoreSection = true } = {}) {
  const player = ref(null)
  const loading = ref(false)
  const error = ref('')
  const loadingSections = ref({})
  const loadedSections = new Set()
  const requestedSections = new Set()
  let requestCounter = 0

  async function load() {
    const playerId = playerIdRef.value
    const requestId = requestCounter + 1
    requestCounter = requestId

    if (!playerId) {
      player.value = null
      error.value = 'A player id is required.'
      return
    }

    loading.value = true
    error.value = ''
    loadedSections.clear()
    requestedSections.clear()
    loadingSections.value = {}

    try {
      const query = analysisQuery(analysisOptionsRef?.value, includeCoreSection ? 'core' : null)
      const response = await fetch(`${API_BASE_URL}/api/players/${encodeURIComponent(playerId)}${query}`, {
        headers: { Accept: 'application/json' },
      })

      if (!response.ok) {
        const errorPayload = typeof response.json === 'function' ? await response.json().catch(() => ({})) : {}
        const requestError = new Error(errorPayload?.message || `Request failed with status ${response.status}`)
        requestError.status = response.status
        throw requestError
      }

      const payload = await response.json()
      if (requestId !== requestCounter) return

      player.value = normalizeProfile(payload.data)
      window.setTimeout(() => {
        if (requestId !== requestCounter) return

        void loadSection('analytics', requestId)
      }, 0)
    } catch (fetchError) {
      if (requestId !== requestCounter) return

      player.value = null
      error.value = responseMessage(fetchError)
      console.error(fetchError)
    } finally {
      if (requestId === requestCounter) loading.value = false
    }
  }

  async function loadSection(section, requestId = requestCounter, sectionOptions = {}) {
    const playerId = playerIdRef.value
    if (!playerId || requestId !== requestCounter || loadedSections.has(section) || requestedSections.has(section)) return

    requestedSections.add(section)
    loadingSections.value = { ...loadingSections.value, [section]: true }

    try {
      const hasSectionAnalysisRange = sectionOptions?.range !== undefined
      const query = analysisQuery(
        hasSectionAnalysisRange ? sectionOptions : analysisOptionsRef?.value,
        section,
        hasSectionAnalysisRange ? {} : sectionOptions,
      )
      const response = await fetch(`${API_BASE_URL}/api/players/${encodeURIComponent(playerId)}${query}`, {
        headers: { Accept: 'application/json' },
      })
      if (!response.ok) throw new Error(`Request failed with status ${response.status}`)

      const payload = await response.json()
      if (requestId !== requestCounter || !player.value) return

      player.value = { ...player.value, ...normalizedSection(payload.data, section) }
      loadedSections.add(section)
    } catch (fetchError) {
      if (requestId === requestCounter) console.error(fetchError)
    } finally {
      requestedSections.delete(section)
      if (requestId === requestCounter) {
        loadingSections.value = { ...loadingSections.value, [section]: false }
      }
    }
  }

  async function reloadSection(section, sectionOptions = {}) {
    loadedSections.delete(section)
    requestedSections.delete(section)
    return loadSection(section, requestCounter, sectionOptions)
  }

  analysisOptionsRef
    ? watch([playerIdRef, analysisOptionsRef], load, { immediate: true, deep: true })
    : watch(playerIdRef, load, { immediate: true })

  return {
    player: computed(() => player.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    sectionLoading: (section) => computed(() => loadingSections.value[section] === true),
    loadSection,
    reloadSection,
    refresh: load,
  }
}

function normalizedSection(data, section) {
  const normalized = normalizeProfile(data)
  if (section === 'advanced_stats') return { advancedStats: normalized.advancedStats }
  if (section === 'defensive_stats') return { defensiveStats: normalized.defensiveStats }
  if (section === 'splits') return { batterSplits: normalized.batterSplits, pitcherSplits: normalized.pitcherSplits }
  if (section === 'similar_players') return { similarPlayers: normalized.similarPlayers }
  if (section === 'analytics') {
    return {
      pitchIndicators: normalized.pitchIndicators,
      battedBallProfile: normalized.battedBallProfile,
      pitchArsenal: normalized.pitchArsenal,
      contextualBenchmarks: normalized.contextualBenchmarks,
      trendEvents: normalized.trendEvents,
      analysis: normalized.analysis,
    }
  }

  return {}
}

function analysisQuery(options, sections = null, extraParams = {}) {
  const params = new URLSearchParams()
  if (options?.range) params.set('range', options.range)
  if (options?.startDate) params.set('start_date', options.startDate)
  if (options?.endDate) params.set('end_date', options.endDate)
  if (options?.paWindow) params.set('pa_window', options.paWindow)
  if (options?.pitchWindow) params.set('pitch_window', options.pitchWindow)
  if (sections) params.set('sections', sections)
  Object.entries(extraParams).forEach(([key, value]) => {
    if (value !== null && value !== undefined && value !== '') params.set(key, value)
  })
  const query = params.toString()
  return query ? `?${query}` : ''
}

function responseMessage(error) {
  if (error.status === 404 || error.message.includes('404')) return 'That player could not be found.'
  if (error.status === 422) return error.message
  return 'Unable to load this player profile. Confirm the Rails API is running and reachable.'
}
