require "fileutils"

class AdminTaskRunner
  TASKS = {
    "mlb_schedule_sync" => {
      name: "MLB schedule sync",
      description: "Download schedules and upsert games, teams, venues, and probable pitchers."
    },
    "mlb_game_details_sync" => {
      name: "MLB game details sync",
      description: "Download box scores and live feeds, then upsert player lines, lineups, plate appearances, and pitch links."
    },
    "mlb_player_profiles_sync" => {
      name: "MLB player profile sync",
      description: "Download MLB profiles for existing players, including bio, handedness, and position data."
    },
    "mlb_player_team_histories_sync" => {
      name: "MLB player organization history sync",
      description: "Download official MLB transactions, rebuild dated organization tenures, and store complete trade packages."
    },
    "mlb_player_contracts_download" => {
      name: "MLB player salary and contract download",
      description: "Download current player salary and contract rows from FanGraphs RosterResource and save the CSV locally."
    },
    "mlb_roster_sync" => {
      name: "MLB 40-man roster sync",
      description: "Download one or more 40-man rosters and update the current roster state and player profiles."
    },
    "mlb_roster_snapshots_sync" => {
      name: "MLB dated roster snapshots",
      description: "Store independent Active and 40-man snapshots for a team and date without changing membership history."
    },
    "player_positions_backfill" => {
      name: "Player position backfill",
      description: "Rebuild normalized current-position assignments from active team memberships."
    },
    "daily_analytics_refresh" => {
      name: "Daily analytics refresh",
      description: "Incrementally rebuild versioned player, pitch-type, split, and team summaries for a date range."
    },
    "contextual_benchmarks_refresh" => {
      name: "Contextual benchmarks refresh",
      description: "Rebuild cached MLB, position, pitcher-role, and player-percentile context for a date range."
    }
  }.freeze

  def self.catalog
    TASKS.map do |id, definition|
      definition.merge(id: id)
    end
  end

  def self.call(task_name:, params: {})
    new(task_name: task_name, params: params).call
  end

  def initialize(task_name:, params: {})
    @task_name = task_name.to_s
    @params = params.to_h.with_indifferent_access
  end

  def call
    return unknown_task unless TASKS.key?(task_name)

    result = send(task_name)
    result.merge(task: task_name)
  rescue ArgumentError => error
    failure(error.message)
  rescue StandardError => error
    failure("Unable to run #{task_name.humanize.downcase}: #{error.message}")
  end

  private

  attr_reader :params, :task_name

  def mlb_schedule_sync
    start_date = required_date(:start_date)
    end_date = optional_date(:end_date) || start_date
    raise ArgumentError, "End date must be on or after start date" if end_date < start_date

    MlbScheduleSync.call(
      start_date: start_date,
      end_date: end_date,
      game_types: params[:game_types].presence || MlbScheduleDownloader::DEFAULT_GAME_TYPES,
      sport_id: positive_integer(:sport_id, default: 1)
    )
  end

  def mlb_game_details_sync
    mlb_game_id = optional_positive_integer(:mlb_game_id)
    start_date = optional_date(:start_date)
    end_date = optional_date(:end_date) || start_date
    raise ArgumentError, "Start date or MLB game id is required" if start_date.nil? && mlb_game_id.nil?
    raise ArgumentError, "End date must be on or after start date" if start_date && end_date < start_date

    MlbGameDetailsBatchSync.call(start_date: start_date, end_date: end_date, mlb_game_id: mlb_game_id)
  end

  def mlb_player_profiles_sync
    MlbPlayerProfilesSync.call(
      only_missing: params.key?(:only_missing) ? params[:only_missing] : true,
      batch_size: positive_integer(:batch_size, default: NineLensConfig.fetch(:operations, :player_profiles, :batch_size).to_i),
      limit: optional_positive_integer(:limit),
      mlb_ids: params[:mlb_ids].presence
    )
  end

  def mlb_player_team_histories_sync
    MlbPlayerTeamHistoriesSync.call(
      limit: optional_positive_integer(:limit),
      mlb_ids: params[:mlb_ids].presence
    )
  end

  def mlb_player_contracts_download
    season = positive_integer(:season, default: Date.current.year)
    result = MlbPlayerContractsDownloader.call(season: season)
    return result unless result[:success]

    import_result = MlbPlayerContractsImporter.call(csv_data: result.dig(:data, :csv_data))
    return import_result unless import_result[:success]

    output_path = Rails.root.join("tmp", "mlb_contracts_#{season}.csv").to_s
    FileUtils.mkdir_p(File.dirname(output_path))
    File.write(output_path, result.dig(:data, :csv_data).to_s)

    imported_count = import_result.dig(:data, :imported_count).to_i
    result.merge(
      message: "Updated #{imported_count} player contract rows in the database",
      data: result.fetch(:data).merge(
        downloaded_count: result.dig(:data, :row_count),
        imported_count: imported_count,
        unmatched_count: import_result.dig(:data, :unmatched_count)
      ).except(:csv_data)
    )
  end

  def mlb_roster_sync
    scope = params[:team_scope].presence || "team"
    season = positive_integer(:season, default: Date.current.year)

    MlbRosterBatchSync.call(
      scope: scope,
      team_mlb_id: optional_positive_integer(:team_mlb_id),
      season: season,
      roster_type: MlbRosterDownloader::DEFAULT_ROSTER_TYPE,
      as_of: MlbRosterSyncBoundary.call(
        season: season,
        team_mlb_id: optional_positive_integer(:team_mlb_id)
      )
    )
  end

  def player_positions_backfill
    PlayerPositionsBackfill.call
  end

  def mlb_roster_snapshots_sync
    MlbRosterSnapshotSync.call(
      team_mlb_id: positive_integer(:team_mlb_id, required: true),
      snapshot_on: required_date(:snapshot_on)
    )
  end

  def daily_analytics_refresh
    start_date = required_date(:start_date)
    end_date = optional_date(:end_date) || start_date
    raise ArgumentError, "End date must be on or after start date" if end_date < start_date

    DailyAnalyticsRefresh.call(
      start_date: start_date,
      end_date: end_date,
      calculation_version: params[:calculation_version].presence || DailyAnalyticsRefresh::CALCULATION_VERSION
    )
  end

  def contextual_benchmarks_refresh
    start_date = required_date(:start_date)
    end_date = optional_date(:end_date) || start_date
    raise ArgumentError, "End date must be on or after start date" if end_date < start_date

    ContextualBenchmarkRefresh.call(
      start_date: start_date,
      end_date: end_date,
      calculation_version: params[:calculation_version].presence || DailyAnalyticsRefresh::CALCULATION_VERSION
    )
  end

  def required_date(key)
    value = params[key].presence
    raise ArgumentError, "#{key.to_s.humanize} is required" if value.blank?

    parse_date(key, value)
  end

  def optional_date(key)
    value = params[key].presence
    parse_date(key, value) if value.present?
  end

  def parse_date(key, value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    raise ArgumentError, "#{key.to_s.humanize} must be a valid ISO date"
  end

  def positive_integer(key, default: nil, required: false)
    value = params[key].presence
    return default if value.blank? && !required
    raise ArgumentError, "#{key.to_s.humanize} is required" if value.blank?

    parsed = Integer(value, exception: false)
    raise ArgumentError, "#{key.to_s.humanize} must be a positive integer" unless parsed&.positive?

    parsed
  end

  def optional_positive_integer(key)
    positive_integer(key) if params[key].present?
  end

  def unknown_task
    failure("Unknown admin task: #{task_name}", error: :not_found)
  end

  def failure(message, error: :unprocessable_entity)
    {
      success: false,
      message: message,
      data: { errors: [ message ] },
      error: error,
      task: task_name
    }
  end
end
