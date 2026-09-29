class AdminDataHealthCheck
  CALCULATION_VERSION = DailyAnalyticsRefresh::CALCULATION_VERSION
  NON_COMPLETED_GAME_STATUSES = %w[canceled cancelled].freeze

  def self.call
    new.call
  end

  def call
    checks = [
      final_games_missing_scores,
      final_games_missing_details,
      past_games_with_player_lines_not_final,
      final_games_missing_pitch_data,
      synchronized_games_missing_batting_lines,
      synchronized_games_missing_pitching_lines,
      synchronized_games_missing_plate_appearances,
      pitches_missing_games,
      pitches_missing_plate_appearances,
      players_missing_profiles,
      players_missing_primary_positions,
      synchronized_dates_missing_analytics,
      analytics_on_old_versions,
      *MlbTotalsReconciliation.call
    ]

    critical_count = checks.count { |check| check[:status] == "critical" }
    warning_count = checks.count { |check| check[:status] == "warning" }

    {
      status: critical_count.positive? ? "critical" : warning_count.positive? ? "warning" : "healthy",
      checked_at: Time.current,
      calculation_version: CALCULATION_VERSION,
      summary: {
        check_count: checks.length,
        healthy_count: checks.count { |check| check[:status] == "healthy" },
        warning_count: warning_count,
        critical_count: critical_count,
        affected_record_count: checks.sum { |check| check[:affected_count] }
      },
      checks: checks
    }
  end

  private

  def completed_games
    @completed_games ||= Game
      .where(status: "final")
      .where("official_date <= ?", application_date)
      .where.not("LOWER(COALESCE(detailed_status, '')) LIKE ?", "%cancel%")
  end

  def synchronized_games
    @synchronized_games ||= completed_games.where.not(details_last_synced_at: nil)
  end

  def final_games_missing_scores
    scope = completed_games.where(home_score: nil).or(completed_games.where(away_score: nil))
    game_check(
      id: "final_games_missing_scores",
      category: "Games",
      name: "Final games have scores",
      severity: "critical",
      scope: scope,
      description: "Final games should contain both home and away scores.",
      recommendation: "Synchronize the affected schedule dates from MLB."
    )
  end

  def final_games_missing_details
    game_check(
      id: "final_games_missing_details",
      category: "Games",
      name: "Final games have detailed data",
      severity: "critical",
      scope: completed_games.where(details_last_synced_at: nil),
      description: "Final games need detailed synchronization before box scores and analytics are complete.",
      recommendation: "Run Synchronize game details for the affected dates."
    )
  end

  def past_games_with_player_lines_not_final
    scope = Game
      .where("official_date < ?", application_date)
      .where.not(status: [ "final", *NON_COMPLETED_GAME_STATUSES ])
      .where.not("LOWER(COALESCE(detailed_status, '')) LIKE ?", "%cancel%")
      .joins(:game_player_batting_lines)
      .distinct

    game_check(
      id: "past_games_with_player_lines_not_final",
      category: "Games",
      name: "Past games with player lines are final",
      severity: "critical",
      scope: scope,
      description: "Past games with player statistics must be marked final so player and team totals include every completed game.",
      recommendation: "Re-synchronize the affected game details and schedule status from MLB."
    )
  end

  def application_date
    @application_date ||= ApplicationCalendar.current_date
  end

  def final_games_missing_pitch_data
    current_year = Date.current.year
    current_season_games = completed_games.where(
      "EXTRACT(YEAR FROM official_date) = ?", current_year
    )
    games_without_linked_pitches = current_season_games.where.not(
      id: PitchDatum.where.not(game_id: nil).select(:game_id)
    )
    scope = games_without_linked_pitches
      .or(current_season_games.where(pitch_data_complete_at: nil))
      .or(current_season_games.where(pitch_data_row_count: 0))

    game_check(
      id: "final_games_missing_pitch_data",
      category: "Pitch data",
      name: "Final games have pitch data",
      severity: "warning",
      scope: scope,
      description: "Finished games should have linked pitch rows and a completed pitch-data synchronization marker.",
      recommendation: "Run the pitch-data download for the affected game dates, then re-run this health check."
    )
  end

  def synchronized_games_missing_batting_lines
    game_check(
      id: "synchronized_games_missing_batting_lines",
      category: "Game details",
      name: "Synchronized games have batting lines",
      severity: "critical",
      scope: synchronized_games.left_outer_joins(:game_player_batting_lines)
        .where(game_player_batting_lines: { id: nil }),
      description: "A synchronized final game should include at least one player batting line.",
      recommendation: "Re-synchronize game details for the affected games."
    )
  end

  def synchronized_games_missing_pitching_lines
    game_check(
      id: "synchronized_games_missing_pitching_lines",
      category: "Game details",
      name: "Synchronized games have pitching lines",
      severity: "critical",
      scope: synchronized_games.left_outer_joins(:game_player_pitching_lines)
        .where(game_player_pitching_lines: { id: nil }),
      description: "A synchronized final game should include at least one player pitching line.",
      recommendation: "Re-synchronize game details for the affected games."
    )
  end

  def synchronized_games_missing_plate_appearances
    game_check(
      id: "synchronized_games_missing_plate_appearances",
      category: "Game details",
      name: "Synchronized games have plate appearances",
      severity: "warning",
      scope: synchronized_games.left_outer_joins(:plate_appearances).where(plate_appearances: { id: nil }),
      description: "Missing plate appearances can leave pitch links and advanced rate statistics incomplete.",
      recommendation: "Re-synchronize game details for the affected games."
    )
  end

  def pitches_missing_games
    scope = PitchDatum.where(game_id: nil)
    pitch_check(
      id: "pitches_missing_games",
      name: "Pitches are linked to games",
      scope: scope,
      description: "Stored pitches without a game link cannot contribute reliably to game or team analysis.",
      recommendation: "Import the matching schedules, then re-import pitch data for these dates."
    )
  end

  def pitches_missing_plate_appearances
    scope = PitchDatum.where.not(game_id: nil).where(plate_appearance_id: nil)
    pitch_check(
      id: "pitches_missing_plate_appearances",
      name: "Game pitches are linked to plate appearances",
      scope: scope,
      description: "Unlinked pitches may be excluded from plate-appearance and matchup calculations.",
      recommendation: "Re-synchronize game details, then re-import pitch data for the affected dates."
    )
  end

  def players_missing_profiles
    scope = Player.left_outer_joins(:profile).where(player_profiles: { id: nil })
    player_check(
      id: "players_missing_profiles",
      name: "Players have profiles",
      scope: scope,
      description: "Players without MLB profiles may be missing biographical and handedness data.",
      recommendation: "Run Synchronize player profiles with Only missing profiles enabled."
    )
  end

  def players_missing_primary_positions
    scope = Player.where.not(id: PlayerPosition.current.primary_assignments.select(:player_id))
    player_check(
      id: "players_missing_primary_positions",
      name: "Players have current primary positions",
      scope: scope,
      description: "Position-aware rankings and comparisons need a current primary position.",
      recommendation: "Synchronize current rosters, then run Rebuild current player positions."
    )
  end

  def synchronized_dates_missing_analytics
    analytics_dates = TeamDailyMetric.for_version(CALCULATION_VERSION).select(:metric_date)
    scope = synchronized_games.where.not(official_date: analytics_dates)

    game_check(
      id: "synchronized_dates_missing_analytics",
      category: "Analytics",
      name: "Synchronized dates have daily analytics",
      severity: "warning",
      scope: scope,
      description: "Synchronized game dates without current analytics can produce incomplete leaderboards and profiles.",
      recommendation: "Run Refresh daily analytics for the affected date range."
    )
  end

  def analytics_on_old_versions
    affected_count = DailyAnalyticsRefresh::SUMMARY_MODELS.sum do |model|
      model.where.not(calculation_version: CALCULATION_VERSION).count
    end

    build_check(
      id: "analytics_on_old_versions",
      category: "Analytics",
      name: "Analytics use the current calculation version",
      severity: "warning",
      affected_count: affected_count,
      description: "Rows calculated with older formulas can disagree with current rankings.",
      recommendation: "Refresh daily analytics and contextual benchmarks using version #{CALCULATION_VERSION}."
    )
  end

  def game_check(id:, category:, name:, severity:, scope:, description:, recommendation:)
    records = scope.distinct
    build_check(
      id: id,
      category: category,
      name: name,
      severity: severity,
      affected_count: records.count,
      examples: records.order(official_date: :desc).limit(5).pluck(:mlb_id, :official_date).map do |mlb_id, date|
        "MLB game #{mlb_id} · #{date.iso8601}"
      end,
      description: description,
      recommendation: recommendation
    )
  end

  def pitch_check(id:, name:, scope:, description:, recommendation:)
    build_check(
      id: id,
      category: "Pitch data",
      name: name,
      severity: "warning",
      affected_count: scope.count,
      examples: scope.order(game_date: :desc).limit(5).pluck(:game_pk, :game_date, :at_bat_number, :pitch_number).map do |game_pk, date, at_bat, pitch|
        "MLB game #{game_pk} · #{date&.iso8601 || 'unknown date'} · PA #{at_bat}, pitch #{pitch}"
      end,
      description: description,
      recommendation: recommendation
    )
  end

  def player_check(id:, name:, scope:, description:, recommendation:)
    build_check(
      id: id,
      category: "Players",
      name: name,
      severity: "warning",
      affected_count: scope.count,
      examples: scope.order(:last_name, :first_name).limit(5).pluck(:mlb_id, :first_name, :last_name).map do |mlb_id, first_name, last_name|
        "#{first_name} #{last_name} · MLB #{mlb_id}"
      end,
      description: description,
      recommendation: recommendation
    )
  end

  def build_check(id:, category:, name:, severity:, affected_count:, description:, recommendation:, examples: [])
    {
      id: id,
      category: category,
      name: name,
      status: affected_count.positive? ? severity : "healthy",
      affected_count: affected_count,
      description: description,
      recommendation: recommendation,
      examples: examples
    }
  end
end
