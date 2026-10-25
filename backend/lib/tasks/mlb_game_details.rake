namespace :mlb_game_details do
  desc "Download and synchronize MLB box scores, lineups, and plate appearances for stored games"
  task :sync, [ :start_date, :end_date ] => :environment do |_task, args|
    start_date = args[:start_date].presence || ENV["START_DATE"].presence
    end_date = args[:end_date].presence || ENV["END_DATE"].presence || start_date
    mlb_game_id = ENV["MLB_GAME_ID"].presence

    if start_date.blank? && mlb_game_id.blank?
      abort "Usage: bin/rails 'mlb_game_details:sync[2026-07-01,2026-07-07]' or MLB_GAME_ID=823443 bin/rails mlb_game_details:sync"
    end

    target = mlb_game_id.present? ? "MLB game #{mlb_game_id}" : "#{start_date}-#{end_date}"
    puts "Synchronizing MLB game details for #{target}..."
    result = MlbGameDetailsBatchSync.call(
      start_date: start_date,
      end_date: end_date,
      mlb_game_id: mlb_game_id
    )

    unless result[:success]
      Array(result.dig(:data, :errors)).each { |error| warn "- #{error.is_a?(Hash) ? error[:message] : error}" }
      abort result[:message]
    end

    data = result.fetch(:data)
    puts result[:message]
    puts "Batting lines: #{data[:batting_line_count]}"
    puts "Pitching lines: #{data[:pitching_line_count]}"
    puts "Lineup entries: #{data[:lineup_entry_count]}"
    puts "Plate appearances: #{data[:plate_appearance_count]}"
    puts "Statcast pitches linked: #{data[:linked_pitch_count]}"
    puts "Failures: #{data[:failed_game_count]}"
  end

  desc "List final games in a season missing game details. Usage: bin/rails 'mlb_game_details:missing[2026]'"
  task :missing, [:season] => :environment do |_task, args|
    season = Integer(args[:season].presence || ENV["SEASON"], exception: false)
    abort "Usage: bin/rails 'mlb_game_details:missing[2026]' or SEASON=2026 bin/rails mlb_game_details:missing" unless season

    games = Game.joins(:schedule)
      .includes(:home_team, :away_team)
      .where(schedules: { season: season }, status: "final", details_last_synced_at: nil)
      .where("games.official_date <= ?", Date.current)
      .without_cancelled
      .order(:official_date, :scheduled_at, :mlb_id)

    if games.empty?
      puts "No final games missing details found for #{season}."
    else
      puts "Final games missing details for #{season}:"
      puts "DATE       MLB_GAME_ID  MATCHUP"
      games.each do |game|
        matchup = "#{game.away_team.abbreviation} @ #{game.home_team.abbreviation}"
        puts "#{game.official_date}  #{game.mlb_id.to_s.rjust(11)}  #{matchup}"
      end
      puts "Total games: #{games.length}"
    end
  end
end
