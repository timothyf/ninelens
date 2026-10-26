namespace :mlb_schedule do
  desc "Count stored MLB schedule games for a season. Usage: bin/rails 'mlb_schedule:count[2026]'"
  task :count, [ :season ] => :environment do |_task, args|
    season = args[:season].presence || ENV["SEASON"].presence
    abort "Usage: bin/rails 'mlb_schedule:count[2026]' or SEASON=2026 bin/rails mlb_schedule:count" unless season.present?
    abort "Season must be a four-digit year" unless season.match?(/\A\d{4}\z/)

    game_count = Game.joins(:schedule).where(schedules: { season: season.to_i }).count
    puts "Stored schedule games for #{season}: #{game_count}"
  end

  desc "Download and synchronize MLB games. Usage: bin/rails 'mlb_schedule:sync[2026-04-01,2026-04-07]' GAME_TYPES=R"
  task :sync, [ :start_date, :end_date ] => :environment do |_task, args|
    start_date = args[:start_date].presence || ENV["START_DATE"].presence
    end_date = args[:end_date].presence || ENV["END_DATE"].presence || start_date
    game_types = ENV["GAME_TYPES"].presence || MlbScheduleDownloader::DEFAULT_GAME_TYPES
    sport_id = ENV["SPORT_ID"].presence || 1

    if start_date.blank?
      abort "Usage: bin/rails 'mlb_schedule:sync[2026-04-01,2026-04-07]' or START_DATE=2026-04-01 END_DATE=2026-04-07 bin/rails mlb_schedule:sync"
    end

    puts "Synchronizing MLB schedule for #{start_date}-#{end_date}..."
    result = MlbScheduleSync.call(
      start_date: start_date,
      end_date: end_date,
      game_types: game_types,
      sport_id: sport_id
    )

    unless result[:success]
      Array(result.dig(:data, :errors)).each { |error| warn "- #{error}" }
      abort result[:message]
    end

    data = result.fetch(:data)
    puts result[:message]
    puts "Created games: #{data[:created_game_count]}"
    puts "Updated games: #{data[:updated_game_count]}"
    puts "Created teams: #{data[:created_team_count]}"
    puts "Created probable pitchers: #{data[:created_player_count]}"
    puts "Schedule source key: #{data[:source_key]}"
  end
end
