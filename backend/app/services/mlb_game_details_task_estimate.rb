class MlbGameDetailsTaskEstimate
  TASK_NAME = "mlb_game_details_sync"
  def self.call(start_date: nil, end_date: nil, mlb_game_id: nil)
    new(start_date: start_date, end_date: end_date, mlb_game_id: mlb_game_id).call
  end

  def initialize(start_date: nil, end_date: nil, mlb_game_id: nil)
    @start_date_input = start_date
    @end_date_input = end_date
    @mlb_game_id_input = mlb_game_id
  end

  def call
    attributes = normalized_attributes
    game_count = selected_games(attributes).count
    timing = historical_timing
    seconds_per_game = timing.fetch(:seconds_per_game, estimate_config.fetch(:game_details_seconds_per_game).to_f)

    {
      task_parameters: attributes,
      game_count: game_count,
      estimated_seconds: (game_count * seconds_per_game).round,
      low_estimated_seconds: (game_count * seconds_per_game * estimate_config.fetch(:game_details_low_range_factor)).ceil,
      high_estimated_seconds: (game_count * seconds_per_game * estimate_config.fetch(:game_details_high_range_factor)).ceil,
      seconds_per_game: seconds_per_game.round(1),
      timing_sample_game_count: timing.fetch(:game_count),
      timing_sample_run_count: timing.fetch(:run_count),
      estimate_source: timing[:seconds_per_game] ? "historical" : "conservative_default"
    }
  end

  private

  attr_reader :start_date_input, :end_date_input, :mlb_game_id_input

  def estimate_config
    @estimate_config ||= NineLensConfig.fetch(:operations, :estimates)
  end

  def normalized_attributes
    if mlb_game_id_input.present?
      mlb_game_id = Integer(mlb_game_id_input, exception: false)
      raise ArgumentError, "MLB game id must be a positive integer" unless mlb_game_id&.positive?
      raise ArgumentError, "No stored game was found for MLB game id #{mlb_game_id}" unless Game.exists?(mlb_id: mlb_game_id)

      return { "mlb_game_id" => mlb_game_id }
    end

    start_date = parse_required_date(:start_date, start_date_input)
    end_date = parse_required_date(:end_date, end_date_input)
    raise ArgumentError, "End date must be on or after start date" if end_date < start_date

    { "start_date" => start_date.iso8601, "end_date" => end_date.iso8601 }
  end

  def selected_games(attributes)
    return Game.where(mlb_id: attributes.fetch("mlb_game_id")) if attributes["mlb_game_id"]

    Game
      .where(official_date: Date.iso8601(attributes.fetch("start_date"))..Date.iso8601(attributes.fetch("end_date")))
      .without_cancelled
      .without_unplayed_if_necessary
  end

  def historical_timing
    rows = AdminTaskRun.where(task_name: TASK_NAME, status: %w[completed cancelled])
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
