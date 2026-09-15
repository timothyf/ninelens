import { computed, ref, watch } from 'vue'
import { API_BASE_URL } from '../config'

function normalizeLine(line) {
  return {
    ...line,
    player: line.player || null,
    team: line.team || null,
  }
}

function normalizePerformer(performer) {
  if (!performer) return null
  return {
    ...performer,
    player: performer.player || null,
    team: performer.team || null,
    metrics: performer.metrics || {},
  }
}

function normalizeSituation(metrics = {}) {
  return {
    plateAppearances: metrics.plate_appearances ?? 0,
    atBats: metrics.at_bats ?? 0,
    hits: metrics.hits ?? 0,
    walks: metrics.walks ?? 0,
    strikeouts: metrics.strikeouts ?? 0,
    runsBattedIn: metrics.runs_batted_in ?? 0,
    battingAverage: metrics.batting_average ?? null,
    onBasePercentage: metrics.on_base_percentage ?? null,
  }
}

function normalizeBoxScoreNotes(notes = {}) {
  const normalizeTeam = (team = {}) => ({
    batting: (team.batting || []).map((note) => ({
      ...note,
      entries: (note.entries || []).map((entry) => ({ ...entry, player: entry.player || null })),
    })),
    baserunning: (team.baserunning || []).map((note) => ({ ...note })),
    fielding: (team.fielding || []).map((note) => ({
      ...note,
      entries: (note.entries || []).map((entry) => ({ ...entry, player: entry.player || null })),
    })),
  })

  return { away: normalizeTeam(notes.away), home: normalizeTeam(notes.home) }
}

function normalizeGame(data) {
  const details = data.details || {}
  const lineScore = details.line_score || {}
  const keyPerformers = details.key_performers || {}
  const topHitters = keyPerformers.top_hitters || {}
  const situationalAnalysis = details.situational_analysis || {}

  return {
    id: data.id,
    mlbId: data.mlb_id,
    officialDate: data.official_date,
    scheduledAt: data.scheduled_at,
    status: data.status,
    detailedStatus: data.detailed_status,
    venueName: data.venue_name,
    gameNumber: data.game_number,
    homeScore: data.home_score,
    awayScore: data.away_score,
    homeTeam: data.home_team,
    awayTeam: data.away_team,
    homeProbablePitcher: data.home_probable_pitcher,
    awayProbablePitcher: data.away_probable_pitcher,
    details: {
      synchronized: Boolean(details.synchronized),
      lastSyncedAt: details.last_synced_at || null,
      insights: details.insights || {
        decisions: { winning_pitcher: null, losing_pitcher: null, save: null },
        teams: { away: {}, home: {} },
      },
      boxScoreNotes: normalizeBoxScoreNotes(details.box_score_notes),
      gameNotes: details.game_notes || [],
      keyPerformers: {
        topHitters: {
          away: normalizePerformer(topHitters.away),
          home: normalizePerformer(topHitters.home),
        },
        mostImpactfulPitcher: normalizePerformer(keyPerformers.most_impactful_pitcher),
        powerHitters: (keyPerformers.power_hitters || []).map(normalizePerformer),
        scorelessRelievers: (keyPerformers.scoreless_relievers || []).map(normalizePerformer),
        topRunProducers: (keyPerformers.top_run_producers || []).map(normalizePerformer),
      },
      scoringPlays: (details.scoring_plays || []).map((play) => ({
        id: play.id,
        plateAppearanceNumber: play.plate_appearance_number,
        inning: play.inning,
        halfInning: play.half_inning,
        inningLabel: play.inning_label,
        event: play.event,
        eventType: play.event_type,
        description: play.description,
        runsScored: play.runs_scored,
        runsBattedIn: play.runs_batted_in,
        awayScore: play.away_score,
        homeScore: play.home_score,
        batter: play.batter || null,
        battingTeam: play.batting_team || null,
      })),
      pitchingAnalysis: (details.pitching_analysis || []).map((entry) => ({
        player: entry.player || null,
        team: entry.team || null,
        home: Boolean(entry.home),
        starter: Boolean(entry.starter),
        appearanceOrder: entry.appearance_order,
        inningsPitched: entry.innings_pitched,
        decision: entry.decision,
        pitchDataAvailable: Boolean(entry.pitch_data_available),
        pitchCount: entry.pitch_count,
        analyzedPitchCount: entry.analyzed_pitch_count,
        strikeCount: entry.strike_count,
        strikePercentage: entry.strike_percentage,
        firstPitchStrikes: entry.first_pitch_strikes,
        firstPitchOpportunities: entry.first_pitch_opportunities,
        firstPitchStrikePercentage: entry.first_pitch_strike_percentage,
        swings: entry.swings,
        whiffs: entry.whiffs,
        whiffPercentage: entry.whiff_percentage,
        calledStrikes: entry.called_strikes,
        cswCount: entry.csw_count,
        cswPercentage: entry.csw_percentage,
        averageVelocity: entry.average_velocity,
        maximumVelocity: entry.maximum_velocity,
        chaseOpportunities: entry.chase_opportunities,
        chases: entry.chases,
        chasePercentage: entry.chase_percentage,
        battersFaced: entry.batters_faced,
        pitchUsage: (entry.pitch_usage || []).map((usage) => ({
          pitchType: usage.pitch_type,
          pitchName: usage.pitch_name,
          count: usage.count,
          percentage: usage.percentage,
          averageVelocity: usage.average_velocity,
          maximumVelocity: usage.maximum_velocity,
          swings: usage.swings,
          whiffs: usage.whiffs,
          whiffPercentage: usage.whiff_percentage,
          calledStrikes: usage.called_strikes,
          cswCount: usage.csw_count,
          cswPercentage: usage.csw_percentage,
          battedBalls: usage.batted_balls,
          averageExitVelocity: usage.average_exit_velocity,
        })),
        timesThroughOrder: {
          maximum: entry.times_through_order?.maximum ?? null,
          plateAppearances: (entry.times_through_order?.plate_appearances || []).map((turn) => ({
            time: turn.time,
            battersFaced: turn.batters_faced,
          })),
        },
      })),
      battedBallAnalysis: (details.batted_ball_analysis || []).map((entry) => ({
        team: entry.team || null,
        home: Boolean(entry.home),
        battedBalls: entry.batted_balls,
        averageExitVelocity: entry.average_exit_velocity,
        maximumExitVelocity: entry.maximum_exit_velocity,
        hardHitCount: entry.hard_hit_count,
        hardHitPercentage: entry.hard_hit_percentage,
        averageLaunchAngle: entry.average_launch_angle,
        estimatedWoba: entry.estimated_woba,
        barrelCount: entry.barrel_count,
        barrelPercentage: entry.barrel_percentage,
        distribution: {
          groundBall: entry.distribution?.ground_ball || { count: 0, percentage: null },
          lineDrive: entry.distribution?.line_drive || { count: 0, percentage: null },
          flyBall: entry.distribution?.fly_ball || { count: 0, percentage: null },
        },
        leaders: (entry.leaders || []).map((leader) => ({
          player: leader.player || null,
          battedBalls: leader.batted_balls,
          averageExitVelocity: leader.average_exit_velocity,
          maximumExitVelocity: leader.maximum_exit_velocity,
          hardHitCount: leader.hard_hit_count,
          hardHitPercentage: leader.hard_hit_percentage,
          averageLaunchAngle: leader.average_launch_angle,
          estimatedWoba: leader.estimated_woba,
          barrelCount: leader.barrel_count,
          barrelPercentage: leader.barrel_percentage,
          distribution: {
            groundBall: leader.distribution?.ground_ball || { count: 0, percentage: null },
            lineDrive: leader.distribution?.line_drive || { count: 0, percentage: null },
            flyBall: leader.distribution?.fly_ball || { count: 0, percentage: null },
          },
        })),
      })),
      situationalAnalysis: {
        highLeverageDefinition: situationalAnalysis.high_leverage_definition || '',
        teams: (situationalAnalysis.teams || []).map((entry) => ({
          team: entry.team || null,
          home: Boolean(entry.home),
          situations: {
            runnersInScoringPosition: normalizeSituation(entry.situations?.runners_in_scoring_position),
            twoOuts: normalizeSituation(entry.situations?.two_outs),
            basesLoaded: normalizeSituation(entry.situations?.bases_loaded),
            leadoffHitters: normalizeSituation(entry.situations?.leadoff_hitters),
            pinchHitters: normalizeSituation(entry.situations?.pinch_hitters),
            highLeverage: normalizeSituation(entry.situations?.high_leverage),
          },
          battingOrderTrips: (entry.batting_order_trips || []).map((trip) => ({
            ...normalizeSituation(trip),
            trip: trip.trip,
          })),
        })),
        turningPoint: situationalAnalysis.turning_point ? {
          type: situationalAnalysis.turning_point.type,
          inningLabel: situationalAnalysis.turning_point.inning_label,
          description: situationalAnalysis.turning_point.description,
          batter: situationalAnalysis.turning_point.batter || null,
          battingTeam: situationalAnalysis.turning_point.batting_team || null,
          awayScore: situationalAnalysis.turning_point.away_score,
          homeScore: situationalAnalysis.turning_point.home_score,
          runsScored: situationalAnalysis.turning_point.runs_scored,
          homeWinProbabilityChange: situationalAnalysis.turning_point.home_win_probability_change,
          benefitingTeam: situationalAnalysis.turning_point.benefiting_team || null,
        } : null,
      },
      plateAppearances: (details.plate_appearances || []).map((appearance) => ({
        id: appearance.id,
        atBatIndex: appearance.at_bat_index,
        plateAppearanceNumber: appearance.plate_appearance_number,
        inning: appearance.inning,
        halfInning: appearance.half_inning,
        event: appearance.event,
        eventType: appearance.event_type,
        description: appearance.description,
        runsBattedIn: appearance.runs_batted_in,
        awayScore: appearance.away_score,
        homeScore: appearance.home_score,
        outsAfter: appearance.outs_after,
        complete: Boolean(appearance.complete),
        batter: appearance.batter || null,
        pitcher: appearance.pitcher || null,
        battingTeam: appearance.batting_team || null,
        fieldingTeam: appearance.fielding_team || null,
        pitches: (appearance.pitches || []).map((pitch) => ({
          id: pitch.id,
          pitchNumber: pitch.pitch_number,
          balls: pitch.balls,
          strikes: pitch.strikes,
          outsWhenUp: pitch.outs_when_up,
          pitchType: pitch.pitch_type,
          pitchName: pitch.pitch_name,
          description: pitch.description,
          events: pitch.events,
          releaseSpeed: pitch.release_speed,
          releaseSpinRate: pitch.release_spin_rate,
          launchSpeed: pitch.launch_speed,
          launchAngle: pitch.launch_angle,
          hitDistance: pitch.hit_distance_sc,
          battedBallType: pitch.bb_type,
          launchSpeedAngle: pitch.launch_speed_angle,
          estimatedWoba: pitch.estimated_woba_using_speedangle,
        })),
      })),
      lineScore: {
        currentInning: lineScore.current_inning ?? null,
        currentInningOrdinal: lineScore.current_inning_ordinal || null,
        inningState: lineScore.inning_state || null,
        innings: lineScore.innings || [],
        totals: lineScore.totals || {
          away: { runs: data.away_score, hits: null, errors: null },
          home: { runs: data.home_score, hits: null, errors: null },
        },
      },
      battingLines: (details.batting_lines || []).map(normalizeLine),
      pitchingLines: (details.pitching_lines || []).map(normalizeLine),
    },
  }
}

export function useGameSummary(gameIdRef) {
  const game = ref(null)
  const loading = ref(false)
  const error = ref('')
  let requestCounter = 0

  async function load() {
    const gameId = gameIdRef.value
    const requestId = ++requestCounter
    if (!gameId) {
      game.value = null
      error.value = 'A game id is required.'
      return
    }

    loading.value = true
    error.value = ''

    try {
      const response = await fetch(`${API_BASE_URL}/api/games/${encodeURIComponent(gameId)}`, {
        headers: { Accept: 'application/json' },
      })
      if (!response.ok) throw new Error(`Request failed with status ${response.status}`)

      const payload = await response.json()
      if (requestId === requestCounter) game.value = normalizeGame(payload.data || {})
    } catch (fetchError) {
      if (requestId !== requestCounter) return
      game.value = null
      error.value = fetchError.message.includes('404')
        ? 'That game could not be found.'
        : 'Unable to load the game summary. Confirm the Rails API is running and reachable.'
    } finally {
      if (requestId === requestCounter) loading.value = false
    }
  }

  watch(gameIdRef, load, { immediate: true })

  return {
    game: computed(() => game.value),
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    refresh: load,
  }
}
