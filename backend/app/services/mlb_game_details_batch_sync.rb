require "timeout"

class MlbGameDetailsBatchSync
  def self.call(start_date: nil, end_date: nil, mlb_game_id: nil, progress_tracker: nil, worker_count: nil)
    new(
      start_date: start_date,
      end_date: end_date,
      mlb_game_id: mlb_game_id,
      progress_tracker: progress_tracker,
      worker_count: worker_count
    ).call
  end

  def initialize(start_date: nil, end_date: nil, mlb_game_id: nil, progress_tracker: nil, worker_count: nil)
    @start_date = parse_date(start_date)
    @end_date = parse_date(end_date)
    @mlb_game_id_provided = mlb_game_id.present?
    @mlb_game_id = Integer(mlb_game_id, exception: false) if mlb_game_id.present?
    @progress_tracker = progress_tracker
    @worker_count = Integer(worker_count, exception: false) if worker_count.present?
  end

  def call
    errors = validation_errors
    return failure(errors.first, errors) if errors.any?

    games = selected_games.to_a
    summary = empty_summary.merge(game_count: games.length)
    failures = []
    refreshed_dates = []
    progress_tracker&.start!(total: games.length)

    process_games_in_pool!(games: games, summary: summary, failures: failures, refreshed_dates: refreshed_dates)

    summary[:errors] = failures
    processed = summary[:synchronized_game_count] + summary[:failed_game_count]
    incomplete = !summary[:cancelled] && processed < games.length
    if incomplete
      missing_count = games.length - processed
      failures << {
        mlb_id: nil,
        message: "#{missing_count} game#{'s' unless missing_count == 1} were not processed",
        errors: [ "worker_pool_incomplete" ]
      }
      summary[:failed_game_count] += missing_count
      summary[:errors] = failures
    end

    summary[:analytics_refresh] = refresh_daily_analytics_for!(refreshed_dates)
    expire_home_snapshot_cache! if summary[:synchronized_game_count].positive?

    if summary[:cancelled]
      processed = summary[:synchronized_game_count] + summary[:failed_game_count]
      return success("Cancelled after processing #{processed} of #{games.length} MLB games", summary)
    end

    if incomplete
      processed = summary[:synchronized_game_count] + summary[:failed_game_count]
      return failure("Synchronization ended early after processing #{processed} of #{games.length} MLB games", failures, summary)
    end

    if games.any? && summary[:synchronized_game_count].zero?
      failure("Unable to synchronize details for any selected MLB games", failures, summary)
    else
      success("Synchronized details for #{summary[:synchronized_game_count]} of #{games.length} MLB games", summary)
    end
  end

  private

  attr_reader :start_date, :end_date, :mlb_game_id, :mlb_game_id_provided, :progress_tracker, :worker_count

  def selected_games
    scope = Game.includes(:away_team, :home_team).order(:official_date, :scheduled_at, :mlb_id)
    return scope.where(mlb_id: mlb_game_id) if mlb_game_id_provided

    scope
      .where(official_date: start_date..end_date)
      .without_cancelled
      .without_unplayed_if_necessary
  end

  def validation_errors
    errors = []
    if mlb_game_id_provided
      errors << "MLB game id must be a positive integer" unless mlb_game_id&.positive?
      if mlb_game_id&.positive? && !Game.exists?(mlb_id: mlb_game_id)
        errors << "No stored game was found for MLB game id #{mlb_game_id}"
      end
      return errors
    end

    errors << "Start date is required" if start_date.nil?
    errors << "End date is required" if end_date.nil?
    errors << "End date must be on or after start date" if start_date && end_date && end_date < start_date
    if worker_count.present? && (!worker_count.positive? || worker_count > max_worker_count)
      errors << "Worker count must be between 1 and #{max_worker_count}"
    end
    errors
  end

  def process_games_in_pool!(games:, summary:, failures:, refreshed_dates:)
    if games.empty?
      summary[:worker_pool_summary] = {
        configured_workers: resolved_worker_count(0),
        active_workers: 0,
        games_enqueued: 0,
        games_dequeued: 0,
        games_finalized: 0,
        worker_error_count: 0,
        worker_errors: []
      }
      return
    end

    queue = Queue.new
    games.each { |game| queue << game }

    configured_workers = resolved_worker_count(games.length)
    active_workers = [ configured_workers, games.length ].min
    active_workers.times { queue << nil }
    lock = Mutex.new
    diagnostics = {
      configured_workers: configured_workers,
      active_workers: active_workers,
      games_enqueued: games.length,
      games_dequeued: 0,
      games_finalized: 0,
      worker_error_count: 0,
      worker_errors: []
    }

    workers = Array.new(active_workers) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          loop do
            break if cancelled?(summary, lock)

            game = queue.pop
            break if game.nil?
            lock.synchronize { diagnostics[:games_dequeued] += 1 }

            if progress_tracker&.cancel_requested?
              mark_cancelled!(summary, lock)
              break
            end

            finalized = false
            begin
              progress_tracker&.game_started!(game)
              result = Timeout.timeout(per_game_timeout_seconds) { MlbGameDetailsSync.call(game: game) }
              lock.synchronize do
                if result[:success]
                  accumulate!(summary, result.fetch(:data))
                  summary[:synchronized_game_count] += 1
                  refreshed_dates << game.official_date if game.official_date.present?
                else
                  summary[:failed_game_count] += 1
                  failures << { mlb_id: game.mlb_id, message: result[:message], errors: Array(result.dig(:data, :errors)) }
                end
              end
              progress_tracker&.game_finished!(game: game, success: result[:success], message: result[:message])
            rescue Timeout::Error
              timeout_message = "Game details sync timed out after #{per_game_timeout_seconds} seconds"
              lock.synchronize do
                summary[:failed_game_count] += 1
                failures << { mlb_id: game.mlb_id, message: timeout_message, errors: [ "Timeout::Error" ] }
              end
              progress_tracker&.game_finished!(game: game, success: false, message: timeout_message)
            rescue StandardError => error
              lock.synchronize do
                summary[:failed_game_count] += 1
                failures << { mlb_id: game.mlb_id, message: error.message, errors: [ error.class.name ] }
              end
              progress_tracker&.game_finished!(game: game, success: false, message: error.message)
            ensure
              lock.synchronize do
                unless finalized
                  diagnostics[:games_finalized] += 1
                  finalized = true
                end
              end
            end
          end
        end
      rescue StandardError => error
        lock.synchronize do
          failures << { mlb_id: nil, message: error.message, errors: [ error.class.name ] }
          diagnostics[:worker_error_count] += 1
          diagnostics[:worker_errors] << error.message
        end
      end
    end

    workers.each(&:join)
    summary[:worker_pool_summary] = diagnostics
  end

  def resolved_worker_count(game_count)
    return 1 if game_count <= 1

    requested = worker_count || default_worker_count
    count = Integer(requested, exception: false) || default_worker_count
    [ [ count, 1 ].max, max_worker_count ].min
  end

  def game_details_config
    @game_details_config ||= NineLensConfig.fetch(:operations, :game_details)
  end

  def default_worker_count
    game_details_config.fetch(:default_worker_count).to_i
  end

  def max_worker_count
    game_details_config.fetch(:max_worker_count).to_i
  end

  def per_game_timeout_seconds
    game_details_config.fetch(:per_game_timeout_seconds).to_i
  end

  def cancelled?(summary, lock)
    lock.synchronize { summary[:cancelled] }
  end

  def mark_cancelled!(summary, lock)
    lock.synchronize { summary[:cancelled] = true }
  end

  def empty_summary
    {
      game_count: 0,
      synchronized_game_count: 0,
      failed_game_count: 0,
      batting_line_count: 0,
      pitching_line_count: 0,
      lineup_entry_count: 0,
      plate_appearance_count: 0,
      created_player_count: 0,
      linked_pitch_count: 0,
      analytics_refresh: nil,
      worker_pool_summary: nil,
      cancelled: false
    }
  end

  def accumulate!(summary, data)
    empty_summary.except(:game_count, :synchronized_game_count, :failed_game_count, :analytics_refresh, :worker_pool_summary, :cancelled).each_key do |key|
      summary[key] += data.fetch(key, 0)
    end
  end

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end

  def refresh_daily_analytics_for!(dates)
    unique_dates = dates.compact.uniq.sort
    return { success: true, skipped: true, message: "No synchronized games required analytics refresh" } if unique_dates.empty?

    DailyAnalyticsRefresh.call(dates: unique_dates, refresh_contextual_benchmarks: false)
  rescue StandardError => error
    {
      success: false,
      message: "Game details synchronized, but daily analytics refresh failed: #{error.message}",
      data: { errors: [ error.message ] }
    }
  end

  def expire_home_snapshot_cache!
    Rails.cache.delete_matched("home-snapshot/v2/*")
  end

  def success(message, data)
    { success: true, message: message, data: data }
  end

  def failure(message, errors = [], summary = {})
    { success: false, message: message, data: summary.merge(errors: errors) }
  end
end
