class PostseasonDataBackfill
  GAME_TYPES = %w[F D L W].freeze
  GAME_TYPES_PARAM = GAME_TYPES.join(",").freeze
  DEFAULT_START_MONTH = 9
  DEFAULT_START_DAY = 20
  DEFAULT_END_MONTH = 11
  DEFAULT_END_DAY = 15

  def self.call(start_year:, end_year:, dry_run: false, force: false, progress: nil)
    new(
      start_year: start_year,
      end_year: end_year,
      dry_run: dry_run,
      force: force,
      progress: progress
    ).call
  end

  def initialize(start_year:, end_year:, dry_run: false, force: false, progress: nil)
    @start_year = Integer(start_year, exception: false)
    @end_year = Integer(end_year, exception: false)
    @dry_run = ActiveModel::Type::Boolean.new.cast(dry_run)
    @force = ActiveModel::Type::Boolean.new.cast(force)
    @progress = progress
  end

  def call
    errors = validation_errors
    return failure(errors.first, errors: errors, seasons: []) if errors.any?

    season_results = (start_year..end_year).map { |season| backfill_season(season) }
    failures = season_results.flat_map { |result| result[:errors] }
    data = summarize(season_results, failures)

    if failures.any?
      failure("Postseason backfill completed with #{failures.length} failure#{'s' unless failures.length == 1}", data)
    else
      success("Postseason backfill completed for #{season_results.length} season#{'s' unless season_results.length == 1}", data)
    end
  end

  private

  attr_reader :start_year, :end_year, :dry_run, :force, :progress

  def validation_errors
    errors = []
    errors << "Start year must be a valid MLB season" unless start_year&.between?(1876, Date.current.year)
    errors << "End year must be a valid MLB season" unless end_year&.between?(1876, Date.current.year)
    errors << "End year must be on or after start year" if start_year && end_year && end_year < start_year
    errors
  end

  def backfill_season(season)
    notify("#{season}: checking postseason schedule")
    schedule_result = synchronize_schedule(season)
    unless schedule_result[:success]
      message = schedule_result[:message]
      notify("#{season}: schedule sync failed: #{message}")
      return empty_season_result(season).merge(errors: [ { season: season, stage: "schedule", message: message } ])
    end

    games = postseason_games(season).to_a
    targets = force ? games : games.select { |game| missing_details?(game) }
    notify("#{season}: #{games.length} final postseason games stored; #{targets.length} need details")

    result = empty_season_result(season).merge(
      stored_game_count: games.length,
      target_game_count: targets.length,
      schedule_created_game_count: schedule_result.dig(:data, :created_game_count).to_i,
      schedule_updated_game_count: schedule_result.dig(:data, :updated_game_count).to_i
    )
    return result if dry_run

    targets.each_with_index do |game, index|
      notify("#{season}: syncing game #{index + 1}/#{targets.length} (MLB #{game.mlb_id})")
      sync_result = MlbGameDetailsSync.call(game: game)
      if sync_result[:success]
        result[:synchronized_game_count] += 1
        accumulate_detail_counts!(result, sync_result.fetch(:data, {}))
      else
        result[:failed_game_count] += 1
        result[:errors] << {
          season: season,
          stage: "details",
          mlb_id: game.mlb_id,
          message: sync_result[:message]
        }
      end
    rescue StandardError => error
      result[:failed_game_count] += 1
      result[:errors] << {
        season: season,
        stage: "details",
        mlb_id: game.mlb_id,
        message: error.message
      }
    end

    result
  end

  def synchronize_schedule(season)
    return success("Dry run uses stored schedules", {}) if dry_run

    MlbScheduleSync.call(
      start_date: Date.new(season, DEFAULT_START_MONTH, DEFAULT_START_DAY),
      end_date: Date.new(season, DEFAULT_END_MONTH, DEFAULT_END_DAY),
      game_types: GAME_TYPES_PARAM,
      sport_id: 1
    )
  end

  def postseason_games(season)
    Game
      .joins(:schedule)
      .includes(:game_player_batting_lines, :game_player_pitching_lines)
      .where(schedules: { season: season }, game_type: GAME_TYPES, status: "final")
      .order(:official_date, :scheduled_at, :mlb_id)
  end

  def missing_details?(game)
    game.details_last_synced_at.nil? ||
      game.game_player_batting_lines.empty? ||
      game.game_player_pitching_lines.empty?
  end

  def accumulate_detail_counts!(result, data)
    %i[batting_line_count pitching_line_count lineup_entry_count plate_appearance_count created_player_count linked_pitch_count].each do |key|
      result[key] += data.fetch(key, 0).to_i
    end
  end

  def empty_season_result(season)
    {
      season: season,
      stored_game_count: 0,
      target_game_count: 0,
      synchronized_game_count: 0,
      failed_game_count: 0,
      schedule_created_game_count: 0,
      schedule_updated_game_count: 0,
      batting_line_count: 0,
      pitching_line_count: 0,
      lineup_entry_count: 0,
      plate_appearance_count: 0,
      created_player_count: 0,
      linked_pitch_count: 0,
      errors: []
    }
  end

  def summarize(seasons, errors)
    count_keys = %i[
      stored_game_count target_game_count synchronized_game_count failed_game_count
      schedule_created_game_count schedule_updated_game_count batting_line_count pitching_line_count
      lineup_entry_count plate_appearance_count created_player_count linked_pitch_count
    ]
    totals = count_keys.to_h { |key| [key, seasons.sum { |season| season[key].to_i }] }
    totals.merge(
      start_year: start_year,
      end_year: end_year,
      dry_run: dry_run,
      force: force,
      seasons: seasons,
      errors: errors
    )
  end

  def notify(message)
    progress&.call(message)
  end

  def success(message, data)
    { success: true, message: message, data: data }
  end

  def failure(message, data = {})
    { success: false, message: message, data: data }
  end
end
