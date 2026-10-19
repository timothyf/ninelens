class PitchDataBatchSync
  def self.call(start_date:, end_date:, game_types:, chunk_days:, replace_existing: false, progress_tracker: nil, progress_callback: nil)
    new(
      start_date: start_date,
      end_date: end_date,
      game_types: game_types,
      chunk_days: chunk_days,
      replace_existing: replace_existing,
      progress_tracker: progress_tracker,
      progress_callback: progress_callback
    ).call
  end

  def initialize(start_date:, end_date:, game_types:, chunk_days:, replace_existing: false, progress_tracker: nil, progress_callback: nil)
    @start_date = Date.iso8601(start_date.to_s)
    @end_date = Date.iso8601(end_date.to_s)
    @game_types = game_types.to_s
    @chunk_days = Integer(chunk_days, exception: false)
    @replace_existing = ActiveModel::Type::Boolean.new.cast(replace_existing)
    @progress_tracker = progress_tracker
    @progress_callback = progress_callback
  end

  def call
    chunks = date_chunks
    games_by_chunk = selected_games_by_chunk
    summary = {
      downloaded_count: 0,
      imported_count: 0,
      duplicate_count: 0,
      skipped_count: 0,
      already_complete_game_count: already_complete_games.count,
      cancelled: false,
      chunk_count: chunks.length,
      game_count: games_by_chunk.values.sum(&:length),
      progress_unit: "games",
      errors: []
    }
    analytics_dates = []
    progress_tracker&.start!(total: summary[:game_count])

    chunks.each_with_index do |(chunk_start, chunk_end), chunk_index|
      if progress_tracker&.cancel_requested?
        summary[:cancelled] = true
        break
      end

      targeted_games = games_by_chunk.fetch([ chunk_start, chunk_end ], [])
      next if targeted_games.empty?

      report_download_progress(
        :download_started,
        chunk_start: chunk_start,
        chunk_end: chunk_end,
        chunk_index: chunk_index + 1,
        chunk_count: chunks.length,
        game_count: targeted_games.length
      )
      download_result = download_chunk(chunk_start: chunk_start, chunk_end: chunk_end)
      report_download_progress(
        download_result[:success] ? :download_finished : :download_failed,
        chunk_start: chunk_start,
        chunk_end: chunk_end,
        chunk_index: chunk_index + 1,
        chunk_count: chunks.length,
        game_count: targeted_games.length,
        row_count: Array(download_result.dig(:data, :rows)).length,
        message: download_result[:message]
      )
      unless download_result[:success]
        summary[:errors] << { chunk: "#{chunk_start.iso8601} — #{chunk_end.iso8601}", message: download_result[:message], errors: Array(download_result.dig(:data, :errors)) }
        progress_tracker&.chunk_finished!(
          success: false,
          processed_game_count: targeted_games.length,
          result_data: { progress_unit: "games" },
          message: download_result[:message]
        )
        next
      end

      rows_by_game_pk = group_rows_by_game_pk(download_result.dig(:data, :rows) || [])
      importable_games = []

      targeted_games.each do |game|
        if progress_tracker&.cancel_requested?
          summary[:cancelled] = true
          break
        end

        progress_tracker&.game_started!(game)
        rows, source_name = rows_for_game(game: game, rows: rows_by_game_pk.fetch(game.mlb_id, []), chunk_start: chunk_start, chunk_end: chunk_end)
        if rows.empty?
          result = failure("No pitch data rows were returned for stored game #{game.mlb_id}")
          summary[:errors] << { game_pk: game.mlb_id, message: result[:message], errors: [] }
          progress_tracker&.chunk_finished!(success: false, processed_game_count: 1, result_data: { progress_unit: "games" }, message: result[:message])
        else
          importable_games << { game: game, rows: rows, source_name: source_name }
        end
      end

      import_result = import_chunk_rows(importable_games)
      if import_result[:success]
        result_data = import_result[:data] || {}
        summary[:downloaded_count] += importable_games.sum { |entry| entry[:rows].length }
        summary[:imported_count] += result_data[:imported_count].to_i
        summary[:duplicate_count] += result_data[:duplicate_count].to_i
        summary[:skipped_count] += result_data[:skipped_count].to_i
        analytics_dates.concat(importable_games.flat_map { |entry| entry[:rows].filter_map { |row| row["game_date"] || row[:game_date] } })
        mark_games_complete!(importable_games.map { |entry| entry[:game] })

        importable_games.each do |entry|
          progress_tracker&.chunk_finished!(
            success: true,
            processed_game_count: 1,
            result_data: { downloaded_count: entry[:rows].length, imported_count: entry[:rows].length, progress_unit: "games" },
            message: import_result[:message]
          )
        end
      else
        summary[:errors] << { chunk: "#{chunk_start.iso8601} — #{chunk_end.iso8601}", message: import_result[:message], errors: Array(import_result.dig(:data, :errors)) }
        importable_games.each do |_entry|
          progress_tracker&.chunk_finished!(success: false, processed_game_count: 1, result_data: { progress_unit: "games" }, message: import_result[:message])
        end
      end

      break if summary[:cancelled]
    end

    progress_tracker&.analytics_started!
    summary[:analytics_refresh] = refresh_daily_analytics(analytics_dates)
    progress_tracker&.analytics_finished!(summary[:analytics_refresh])
    if summary[:analytics_refresh].dig(:success) == false
      summary[:errors] << { message: summary[:analytics_refresh][:message], errors: [] }
    end

    if summary[:cancelled]
      success("Cancelled after processing #{summary[:downloaded_count]} Statcast rows", summary)
    elsif summary[:errors].any? && summary[:imported_count].zero?
      failure("Unable to synchronize Statcast pitch data for any chunk", summary[:errors], summary)
    else
      success("Synchronized #{summary[:imported_count]} pitch data rows across #{chunks.length} chunk#{'s' unless chunks.length == 1}", summary)
    end
  rescue Date::Error
    failure("Pitch data sync received invalid dates", [ "Invalid dates" ], {})
  end

  private

  attr_reader :start_date, :end_date, :game_types, :chunk_days, :replace_existing, :progress_tracker, :progress_callback

  def report_download_progress(event, **details)
    progress_callback&.call(event: event, **details)
  end

  def download_chunk(chunk_start:, chunk_end:)
    result = PitchDataDownloader.call(
      start_date: chunk_start,
      end_date: chunk_end,
      game_types: game_types,
      chunk_days: ((chunk_end - chunk_start).to_i + 1)
    )

    return { success: true, data: { rows: [] } } if result[:message] == "No pitch data rows returned from Baseball Savant"

    result
  end

  def rows_for_game(game:, rows:, chunk_start:, chunk_end:)
    source_name = "Baseball Savant pitch data #{chunk_start.iso8601}-#{chunk_end.iso8601}"
    if rows.empty?
      live_result = MlbLivePitchDataDownloader.call(game: game)
      if live_result[:success] && live_result[:rows].present?
        rows = live_result[:rows]
        source_name = "MLB Stats API live pitch data #{game.mlb_id}"
      end
    end

    [ rows, source_name ]
  end

  def import_chunk_rows(importable_games)
    return success("No pitch data rows to import", { imported_count: 0, duplicate_count: 0, skipped_count: 0 }) if importable_games.empty?

    source_names = importable_games.map { |entry| entry[:source_name] }.uniq
    PitchDataImporter.import_raw_rows(
      rows: importable_games.flat_map { |entry| entry[:rows] },
      source_name: source_names.one? ? source_names.first : source_names.join("; "),
      replace_game_ids: (importable_games.map { |entry| entry[:game].id } if replace_existing),
      refresh_analytics: false
    )
  end

  def mark_games_complete!(games)
    return if games.empty?

    timestamp = Time.current
    Game.where(id: games.map(&:id)).update_all(
      pitch_data_complete_at: timestamp,
      pitch_data_row_count: Arel.sql("(SELECT COUNT(*) FROM pitch_data WHERE pitch_data.game_id = games.id)")
    )
  end

  def refresh_daily_analytics(dates)
    unique_dates = dates.filter_map { |date| date.presence && Date.parse(date.to_s) }.uniq.sort
    return { skipped: true, reason: "No imported pitch dates" } if unique_dates.empty?

    DailyAnalyticsRefresh.call(dates: unique_dates)
  rescue StandardError => error
    { success: false, message: "Pitch data was imported, but daily analytics refresh failed: #{error.message}" }
  end

  def date_chunks
    chunks = []
    chunk_start = start_date

    while chunk_start <= end_date
      chunk_end = [ chunk_start + chunk_days.days - 1.day, end_date ].min
      chunks << [ chunk_start, chunk_end ]
      chunk_start = chunk_end + 1.day
    end

    chunks
  end

  def selected_games_by_chunk
    selected_games.group_by do |game|
      chunk_start = game.official_date
      days_from_start = (chunk_start - start_date).to_i
      offset = days_from_start % chunk_days
      actual_start = chunk_start - offset.days
      actual_end = [ actual_start + chunk_days.days - 1.day, end_date ].min
      [ actual_start, actual_end ]
    end
  end

  def group_rows_by_game_pk(rows)
    rows.group_by { |row| Integer(row["game_pk"], exception: false) }
  end

  def selected_games
    @selected_games ||= (replace_existing ? base_games : base_games.where(pitch_data_complete_at: nil)).to_a
  end

  def already_complete_games
    @already_complete_games ||= replace_existing ? Game.none : base_games.where.not(pitch_data_complete_at: nil)
  end

  def base_games
    @base_games ||= Game
      .where(official_date: start_date..end_date, game_type: game_types.split(","))
      .without_cancelled
      .without_unplayed_if_necessary
  end

  def success(message, data)
    { success: true, message: message, data: data }
  end

  def failure(message, errors = [], data = {})
    { success: false, message: message, data: data.merge(errors: errors) }
  end
end
