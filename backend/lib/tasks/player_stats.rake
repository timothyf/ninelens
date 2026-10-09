namespace :player_stats do
  def resolve_import_paths(explicit_path = nil)
    path = explicit_path.presence || ENV["PLAYER_STATS_CSV"].presence
    return csv_paths_from(path) if path.present?

    preferred_directory_paths = PlayerStatsCsvLocator.all(search_roots: [PlayerStatsCsvLocator.preferred_output_directory])
    return preferred_directory_paths if preferred_directory_paths.any?

    located_path = PlayerStatsCsvLocator.call
    located_path.present? ? [located_path] : []
  end

  def csv_paths_from(path)
    pathname = Pathname(path)

    if pathname.directory?
      PlayerStatsCsvLocator.all(search_roots: [pathname])
    elsif pathname.file?
      [pathname.to_s]
    else
      []
    end
  end

  def import_player_stats_from!(file_path)
    required_stat_columns = ENV.fetch("REQUIRED_STAT_COLUMNS", "")
      .split(",")
      .map(&:strip)
      .reject(&:blank?)

    result = PlayerStatsImporter.call(
      file_path: file_path,
      source_name: file_path,
      required_stat_columns: required_stat_columns
    )

    puts result[:message]

    if result[:success]
      data = result[:data] || {}
      puts "Imported season stat records: #{data[:imported_count]}"
      puts "Created teams: #{data[:created_team_count]}"
      puts "Created players: #{data[:created_player_count]}"
      puts "Skipped rows: #{data[:skipped_count]}"
      puts "Duplicate rows collapsed: #{data[:duplicate_count]}"

      Array(data[:errors]).each do |error|
        puts "Row #{error[:row_number]}: #{error[:error]}"
      end
    else
      Array(result.dig(:data, :errors)).each do |error|
        puts "Row #{error[:row_number]}: #{error[:error]}"
      end

      abort "Player season stats import failed"
    end
  end

  desc "Import player season stats from CSV. Usage: bin/rails 'player_stats:seed[path/to/file.csv]' REQUIRED_STAT_COLUMNS=gamesPlayed,ops"
  task :seed, [:file_path] => :environment do |_task, args|
    file_path = args[:file_path].presence || ENV["PLAYER_STATS_CSV"]

    if file_path.blank?
      abort "Usage: bin/rails 'player_stats:seed[path/to/file.csv]' or PLAYER_STATS_CSV=path bin/rails player_stats:seed"
    end

    import_player_stats_from!(file_path)
  end

  desc "Download MLB player season stats and import them. Usage: bin/rails 'player_stats:download[batting,2025,2026]' REPLACE_SEASON=1"
  task :download, [:category, :start_year, :end_year] => :environment do |_task, args|
    category = args[:category].presence || ENV["CATEGORY"].presence || "batting"
    start_year = args[:start_year].presence || ENV["START_YEAR"].presence
    end_year = args[:end_year].presence || ENV["END_YEAR"].presence || start_year

    if start_year.blank?
      abort "Usage: bin/rails 'player_stats:download[batting,2025,2026]' or START_YEAR=2025 CATEGORY=pitching bin/rails player_stats:download"
    end

    puts "Downloading #{category} stats from MLB for #{start_year}-#{end_year}..."
    download_result = PlayerStatsDownloader.call(category: category, start_year: start_year, end_year: end_year)

    unless download_result[:success]
      abort download_result[:message]
    end

    puts download_result[:message]
    import_result = PlayerStatsImporter.call(
      csv_data: download_result.dig(:data, :csv_data),
      source_name: "MLB #{download_result.dig(:data, :category)} #{download_result.dig(:data, :seasons).join('-')}",
      replace_season: %w[1 true t yes y on].include?(ENV["REPLACE_SEASON"].to_s.strip.downcase)
    )

    puts import_result[:message]

    unless import_result[:success]
      Array(import_result.dig(:data, :errors)).each do |error|
        puts "Row #{error[:row_number]}: #{error[:error]}"
      end

      abort "Player season stats download import failed"
    end

    data = import_result[:data] || {}
    puts "Downloaded MLB rows: #{download_result.dig(:data, :row_count)}"
    puts "Imported season stat records: #{data[:imported_count]}"
    puts "Created teams: #{data[:created_team_count]}"
    puts "Created players: #{data[:created_player_count]}"
    puts "Skipped rows: #{data[:skipped_count]}"
    puts "Duplicate rows collapsed: #{data[:duplicate_count]}"
    puts "Replaced rows: #{data[:replaced_rows_count]}" if data[:replace_season]
  end

  desc "Backfill season-level defensive stats from the MLB fielding feed. Usage: bin/rails 'player_stats:backfill_fielding[1977,1996]' PLAYER_STATS_PLAYER_IDS=123,456"
  task :backfill_fielding, [:start_year, :end_year] => :environment do |_task, args|
    start_year = args[:start_year].presence || ENV["START_YEAR"].presence
    end_year = args[:end_year].presence || ENV["END_YEAR"].presence || start_year

    if start_year.blank? || end_year.blank?
      abort "Usage: bin/rails 'player_stats:backfill_fielding[1977,1996]' or START_YEAR=1977 END_YEAR=1996 bin/rails player_stats:backfill_fielding"
    end

    player_ids = ENV.fetch("PLAYER_STATS_PLAYER_IDS", "")
      .split(",")
      .filter_map { |value| Integer(value.strip, exception: false) }
      .uniq

    puts "Downloading historical fielding rows from #{start_year}-#{end_year}..."
    download_result = PlayerStatsDownloader.call(
      category: "batting",
      start_year: start_year,
      end_year: end_year
    )

    abort download_result[:message] unless download_result[:success]

    csv_data = download_result.dig(:data, :csv_data)
    if player_ids.any?
      csv = CSV.parse(csv_data, headers: true)
      filtered_rows = csv.select do |row|
        player_id = Integer(row["playerId"] || row["mlb_id"], exception: false)
        player_ids.include?(player_id)
      end
      csv_data = CSV.generate(headers: true) do |output|
        output << csv.headers
        filtered_rows.each { |row| output << row }
      end
      puts "Restricting import to MLB player IDs: #{player_ids.join(', ')}"
      puts "Matching season rows: #{filtered_rows.length}"
    end

    import_result = PlayerStatsImporter.call(
      csv_data: csv_data,
      source_name: "MLB historical fielding #{start_year}-#{end_year}",
      fielding_only: true
    )

    puts import_result[:message]
    abort "Historical fielding backfill failed" unless import_result[:success]

    data = import_result[:data] || {}
    puts "Imported fielding position rows: #{data[:fielding_imported_count]}"
    puts "Imported season stat records: #{data[:imported_count]}"
    puts "Created players: #{data[:created_player_count]}"
    puts "Skipped rows: #{data[:skipped_count]}"
  end

  desc "Import normalized Total Zone Runs CSV. Usage: bin/rails 'player_stats:import_total_zone[path/to/total_zone.csv]'"
  task :import_total_zone, [:file_path] => :environment do |_task, args|
    file_path = args[:file_path].presence || ENV["TOTAL_ZONE_CSV"].presence
    abort "Usage: bin/rails 'player_stats:import_total_zone[path/to/total_zone.csv]' or TOTAL_ZONE_CSV=/absolute/path/to/total_zone.csv bin/rails player_stats:import_total_zone" if file_path.blank?

    result = PlayerStatsImporter.call(
      file_path: file_path,
      source_name: "Total Zone Runs #{file_path}",
      required_stat_columns: ["TZR"]
    )

    puts result[:message]
    abort "Total Zone Runs import failed" unless result[:success]

    data = result[:data] || {}
    puts "Imported Total Zone/player-season stat records: #{data[:imported_count]}"
    puts "Skipped rows: #{data[:skipped_count]}"
  end

  desc "Import Total Zone Runs from a remote CSV or JSON API. Usage: bin/rails 'player_stats:import_total_zone_remote[https://example.test/total-zone.json]' with optional REMOTE_QUERY and REMOTE_HEADERS JSON"
  task :import_total_zone_remote, [:url] => :environment do |_task, args|
    url = args[:url].presence || ENV["TOTAL_ZONE_REMOTE_URL"].presence
    abort "Usage: bin/rails 'player_stats:import_total_zone_remote[https://example.test/total-zone.json]' or TOTAL_ZONE_REMOTE_URL=https://example.test/total-zone.json bin/rails player_stats:import_total_zone_remote" if url.blank?

    query = ENV["REMOTE_QUERY"].present? ? JSON.parse(ENV.fetch("REMOTE_QUERY")) : {}
    headers = ENV["REMOTE_HEADERS"].present? ? JSON.parse(ENV.fetch("REMOTE_HEADERS")) : {}
    remote_result = TotalZoneRunsRemoteImporter.call(
      url: url,
      source_name: "Remote Total Zone Runs #{url}",
      query: query,
      headers: headers
    )
    abort remote_result[:message] unless remote_result[:success]

    import_result = PlayerStatsImporter.call(
      csv_data: remote_result.dig(:data, :csv_data),
      source_name: remote_result.dig(:data, :source_name) || "Remote Total Zone Runs #{url}",
      required_stat_columns: ["TZR"]
    )
    puts import_result[:message]
    abort "Remote Total Zone Runs import failed" unless import_result[:success]

    data = import_result[:data] || {}
    puts "Downloaded remote rows: #{remote_result.dig(:data, :row_count)}"
    puts "Imported Total Zone/player-season stat records: #{data[:imported_count]}"
    puts "Skipped rows: #{data[:skipped_count]}"
  end

  desc "Import Total Zone Runs directly from Baseball-Reference. Usage: bin/rails 'player_stats:import_total_zone_baseball_reference[1977,1996]'"
  task :import_total_zone_baseball_reference, [:start_year, :end_year] => :environment do |_task, args|
    start_year = args[:start_year].presence || ENV["START_YEAR"].presence
    end_year = args[:end_year].presence || ENV["END_YEAR"].presence || start_year
    abort "Usage: bin/rails 'player_stats:import_total_zone_baseball_reference[1977,1996]'" if start_year.blank? || end_year.blank?

    result = BaseballReferenceTotalZoneRunsImporter.call(
      start_year: start_year,
      end_year: end_year,
      delay: ENV.fetch("BBREF_DELAY", "0.5").to_f
    )
    abort result[:message] unless result[:success]

    import_result = PlayerStatsImporter.call(
      csv_data: result.dig(:data, :csv_data),
      source_name: "Baseball-Reference Total Zone #{start_year}-#{end_year}",
      required_stat_columns: ["TZR"]
    )
    puts import_result[:message]
    abort "Baseball-Reference Total Zone import failed" unless import_result[:success]

    data = import_result[:data] || {}
    puts "Downloaded Baseball-Reference rows: #{result.dig(:data, :row_count)}"
    puts "Imported Total Zone/player-season stat records: #{data[:imported_count]}"
    puts "Skipped rows: #{data[:skipped_count]}"
  end

  desc "Seed stat_types and reimport player season stats from the preferred local CSV source. Usage: bin/rails player_stats:reimport or PLAYER_STATS_CSV=/path/file.csv bin/rails player_stats:reimport"
  task :reimport, [:file_path] => :environment do |_task, args|
    file_paths = resolve_import_paths(args[:file_path])

    if file_paths.blank?
      abort <<~MESSAGE
        Unable to find a player season stats CSV automatically.
        Try:
          PLAYER_STATS_CSV=/absolute/path/to/file.csv bin/rails player_stats:reimport
      MESSAGE
    end

    puts "Seeding stat types..."
    SeedFu.seed
    puts "Using CSV source#{'s' if file_paths.many?}:"
    file_paths.each { |file_path| puts "- #{file_path}" }

    file_paths.each do |file_path|
      import_player_stats_from!(file_path)
    end
  end

  desc "Verify player_season_stats.team_id values against MLB source data. Usage: bin/rails 'player_stats:verify_team_ids[pitching,1968,1968]' FIX=1"
  task :verify_team_ids, [:category, :start_year, :end_year] => :environment do |_task, args|
    category = args[:category].presence || ENV["CATEGORY"].presence || "pitching"
    start_year = args[:start_year].presence || ENV["START_YEAR"].presence
    end_year = args[:end_year].presence || ENV["END_YEAR"].presence || start_year

    if start_year.blank?
      abort "Usage: bin/rails 'player_stats:verify_team_ids[pitching,1968,1968]' or START_YEAR=1968 CATEGORY=pitching bin/rails player_stats:verify_team_ids"
    end

    fix = %w[1 true t yes y on].include?(ENV["FIX"].to_s.strip.downcase)
    puts "#{fix ? 'Repairing' : 'Verifying'} #{category} team ids from MLB for #{start_year}-#{end_year}..."

    result = PlayerSeasonStatsTeamVerifier.call(
      category: category,
      start_year: start_year,
      end_year: end_year,
      fix: fix
    )

    abort result[:message] unless result[:success]

    data = result[:data] || {}
    puts result[:message]
    puts "Checked player-season groups: #{data[:checked_groups]}"
    puts "Missing players: #{data[:missing_player_groups]}"
    puts "Missing stat groups: #{data[:missing_stat_groups]}"
    puts "Mismatched groups: #{data[:mismatched_groups]}"
    puts "Mismatched stat rows: #{data[:mismatched_rows]}"
    puts "Updated rows: #{data[:updated_rows]}" if fix

    Array(data[:samples]).each do |sample|
      puts [
        "#{sample[:player]} #{sample[:season]}",
        "expected #{sample[:expected_team]} (#{sample[:expected_team_mlb_id]})",
        "stored team mlb ids #{sample[:stored_team_mlb_ids].inspect}",
        "#{sample[:row_count]} rows"
      ].join(" - ")
    end

    puts "Dry run only. Rerun with FIX=1 to update mismatched rows." unless fix
  end
end
