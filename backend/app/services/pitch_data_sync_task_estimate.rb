class PitchDataSyncTaskEstimate
  TASK_NAME = "pitch_data_sync"
  def self.call(start_date:, end_date:, game_types: PitchDataDownloader::DEFAULT_GAME_TYPES, chunk_days: nil, replace_existing: false)
    new(start_date: start_date, end_date: end_date, game_types: game_types, chunk_days: chunk_days, replace_existing: replace_existing).call
  end

  def initialize(start_date:, end_date:, game_types: "R", chunk_days: nil, replace_existing: false)
    @start_date_input = start_date
    @end_date_input = end_date
    @game_types_input = game_types
    @chunk_days_input = chunk_days
    @replace_existing_input = replace_existing
  end

  def call
    attributes = normalized_attributes
    game_count = selected_games(attributes).count
    timing = historical_timing
    seconds_per_game = timing.fetch(:seconds_per_game, estimate_config.fetch(:pitch_data_seconds_per_game).to_f)

    {
      task_parameters: attributes,
      game_count: game_count,
      already_complete_game_count: already_complete_games(attributes).count,
      estimated_seconds: (game_count * seconds_per_game).round,
      low_estimated_seconds: (game_count * seconds_per_game * estimate_config.fetch(:pitch_data_low_range_factor)).ceil,
      high_estimated_seconds: (game_count * seconds_per_game * estimate_config.fetch(:pitch_data_high_range_factor)).ceil,
      seconds_per_game: seconds_per_game.round(1),
      timing_sample_game_count: timing.fetch(:game_count),
      timing_sample_run_count: timing.fetch(:run_count),
      estimate_source: timing[:seconds_per_game] ? "historical" : "conservative_default"
    }
  end

  private

  attr_reader :start_date_input, :end_date_input, :game_types_input, :chunk_days_input, :replace_existing_input

  def estimate_config
    @estimate_config ||= NineLensConfig.fetch(:operations, :estimates).merge(
      default_chunk_days: NineLensConfig.fetch(:operations, :pitch_data, :default_chunk_days)
    )
  end

  def normalized_attributes
    start_date = parse_required_date(:start_date, start_date_input)
    end_date = parse_required_date(:end_date, end_date_input)
    raise ArgumentError, "Statcast pitch data is not available before 2008" if start_date < Date.new(2008, 1, 1)
    raise ArgumentError, "End date must be on or after start date" if end_date < start_date

    chunk_days = Integer(chunk_days_input.presence || estimate_config.fetch(:default_chunk_days), exception: false)
    raise ArgumentError, "Chunk days must be at least 1" if chunk_days.nil? || chunk_days < 1

    game_types = Array(game_types_input.to_s.split(",")).map { |item| item.strip.upcase }.reject(&:blank?).uniq
    raise ArgumentError, "At least one game type is required" if game_types.empty?

    invalid = game_types - PitchDataDownloader::VALID_GAME_TYPES
    raise ArgumentError, "Unsupported game type(s): #{invalid.join(', ')}" if invalid.any?

    {
      "start_date" => start_date.iso8601,
      "end_date" => end_date.iso8601,
      "game_types" => game_types.join(","),
      "chunk_days" => chunk_days,
      "replace_existing" => ActiveModel::Type::Boolean.new.cast(replace_existing_input)
    }
  end

  def date_chunks(attributes)
    start_date = Date.iso8601(attributes.fetch("start_date"))
    end_date = Date.iso8601(attributes.fetch("end_date"))
    chunk_days = attributes.fetch("chunk_days").to_i
    chunks = []
    chunk_start = start_date

    while chunk_start <= end_date
      chunk_end = [ chunk_start + chunk_days.days - 1.day, end_date ].min
      chunks << [ chunk_start, chunk_end ]
      chunk_start = chunk_end + 1.day
    end

    chunks
  end

  def selected_games(attributes)
    scope = base_games(attributes)
    attributes.fetch("replace_existing") ? scope : scope.where(pitch_data_complete_at: nil)
  end

  def already_complete_games(attributes)
    return Game.none if attributes.fetch("replace_existing")

    base_games(attributes).where.not(pitch_data_complete_at: nil)
  end

  def base_games(attributes)
    Game.where(
      official_date: Date.iso8601(attributes.fetch("start_date"))..Date.iso8601(attributes.fetch("end_date")),
      game_type: attributes.fetch("game_types").split(",")
    )
  end

  def historical_timing
    rows = AdminTaskRun.where(task_name: TASK_NAME, status: %w[completed cancelled])
      .where("result_data ->> 'progress_unit' = ?", "games")
      .where.not(started_at: nil, finished_at: nil)
      .pluck(:completed_items, :failed_items, :started_at, :finished_at)

    completed_runs = rows.filter_map do |completed_items, failed_items, started_at, finished_at|
      processed_items = completed_items + failed_items
      elapsed_seconds = finished_at - started_at
      [ processed_items, elapsed_seconds ] if processed_items.positive? && elapsed_seconds.positive?
    end

    total_games = completed_runs.sum(&:first)
    return { game_count: 0, run_count: 0 } if total_games.zero?

    {
      seconds_per_game: completed_runs.sum(&:last) / total_games,
      game_count: total_games,
      run_count: completed_runs.size
    }
  end

  def parse_required_date(name, value)
    raise ArgumentError, "#{name.to_s.humanize} is required" if value.blank?

    Date.iso8601(value.to_s)
  rescue Date::Error
    raise ArgumentError, "#{name.to_s.humanize} must be a valid ISO date"
  end
end
