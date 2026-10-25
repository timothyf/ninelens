namespace :pitch_data do
  def resolve_pitch_data_path(explicit_path = nil)
    candidate_paths = [
      explicit_path,
      ENV["PITCH_DATA_CSV"],
      Rails.root.join("..", "data", "mlb_pitch_data_april_2026.csv").to_s,
      Rails.root.join("data", "mlb_pitch_data_april_2026.csv").to_s
    ].compact

    candidate_paths.find { |path| File.file?(path) }
  end

  def import_pitch_data_from!(file_path)
    result = PitchDataImporter.call(file_path: file_path, source_name: file_path)

    puts result[:message]

    if result[:success]
      data = result[:data] || {}
      puts "Imported pitch rows: #{data[:imported_count]}"
      puts "Skipped rows: #{data[:skipped_count]}"
      puts "Duplicate rows collapsed: #{data[:duplicate_count]}"
    else
      Array(result.dig(:data, :errors)).each do |error|
        puts "Row #{error[:row_number]}: #{error[:error]}"
      end

      abort "Pitch data import failed"
    end
  end

  desc "Import pitch data from CSV. Usage: bin/rails 'pitch_data:import[path/to/file.csv]' or PITCH_DATA_CSV=/path/file.csv bin/rails pitch_data:import"
  task :import, [:file_path] => :environment do |_task, args|
    file_path = resolve_pitch_data_path(args[:file_path])

    if file_path.blank?
      abort <<~MESSAGE
        Unable to find a pitch data CSV file.
        Try:
          bin/rails 'pitch_data:import[/absolute/path/to/file.csv]'
          PITCH_DATA_CSV=/absolute/path/to/file.csv bin/rails pitch_data:import
      MESSAGE
    end

    puts "Using pitch CSV source: #{file_path}"
    import_pitch_data_from!(file_path)
  end

  desc "Download Baseball Savant pitch data and import it. Usage: bin/rails 'pitch_data:download[2026-04-01,2026-04-07]' GAME_TYPES=R CHUNK_DAYS=7"
  task :download, [:start_date, :end_date] => :environment do |_task, args|
    start_date = args[:start_date].presence || ENV["START_DATE"].presence
    end_date = args[:end_date].presence || ENV["END_DATE"].presence || start_date
    game_types = ENV["GAME_TYPES"].presence || "R"
    chunk_days = ENV["CHUNK_DAYS"].presence || PitchDataDownloader::DEFAULT_CHUNK_DAYS

    if start_date.blank? || end_date.blank?
      abort "Usage: bin/rails 'pitch_data:download[2026-04-01,2026-04-07]' or START_DATE=2026-04-01 END_DATE=2026-04-07 bin/rails pitch_data:download"
    end

    puts "Downloading pitch data from Baseball Savant for #{start_date}-#{end_date}..."
    download_result = PitchDataDownloader.call(
      start_date: start_date,
      end_date: end_date,
      game_types: game_types,
      chunk_days: chunk_days
    )

    unless download_result[:success]
      abort download_result[:message]
    end

    puts download_result[:message]
    result = PitchDataImporter.call(
      csv_data: download_result.dig(:data, :csv_data),
      source_name: "Baseball Savant pitch data #{download_result.dig(:data, :start_date)}-#{download_result.dig(:data, :end_date)}"
    )

    puts result[:message]

    unless result[:success]
      Array(result.dig(:data, :errors)).each do |error|
        puts "Row #{error[:row_number]}: #{error[:error]}"
      end

      abort "Pitch data download import failed"
    end

    data = result[:data] || {}
    puts "Downloaded pitch rows: #{download_result.dig(:data, :row_count)}"
    puts "Imported pitch rows: #{data[:imported_count]}"
    puts "Skipped rows: #{data[:skipped_count]}"
    puts "Duplicate rows collapsed: #{data[:duplicate_count]}"
  end

  desc "Report dates with completed games missing Statcast pitches. Usage: bin/rails 'pitch_data:missing_dates[2026]'"
  task :missing_dates, [:season] => :environment do |_task, args|
    season = Integer(args[:season].presence || ENV["SEASON"], exception: false)
    abort "Usage: bin/rails 'pitch_data:missing_dates[2026]' or SEASON=2026 bin/rails pitch_data:missing_dates" unless season

    rows = Game.joins(:schedule)
      .joins("LEFT JOIN pitch_data ON pitch_data.game_pk = games.mlb_id")
      .where(schedules: { season: season })
      .where(status: %w[final complete])
      .without_cancelled
      .group("games.official_date")
      .having("COUNT(DISTINCT CASE WHEN pitch_data.id IS NULL THEN games.id END) > 0")
      .order("games.official_date")
      .pluck(
        "games.official_date",
        Arel.sql("COUNT(DISTINCT games.id)"),
        Arel.sql("COUNT(DISTINCT CASE WHEN pitch_data.id IS NULL THEN games.id END)")
      )

    if rows.empty?
      puts "No completed games missing Statcast pitches found for #{season}."
    else
      puts "Dates with completed games missing Statcast pitches for #{season}:"
      puts "DATE       GAMES  MISSING"
      rows.each { |date, game_count, missing_count| puts "#{date}  #{game_count.to_s.rjust(5)}  #{missing_count.to_s.rjust(7)}" }
      puts "Total affected dates: #{rows.length}"
    end
  end
end
