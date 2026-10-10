namespace :postseason_data do
  desc "Backfill missing postseason schedules and game details. Usage: bin/rails 'postseason_data:backfill[2022,2025]'"
  task :backfill, [ :start_year, :end_year ] => :environment do |_task, args|
    default_year = Date.current.year - 1
    start_year = args[:start_year].presence || ENV["START_YEAR"].presence || default_year
    end_year = args[:end_year].presence || ENV["END_YEAR"].presence || start_year
    dry_run = ENV["DRY_RUN"].presence || false
    force = ENV["FORCE"].presence || false

    puts "Backfilling postseason data for #{start_year}-#{end_year}#{' (dry run)' if ActiveModel::Type::Boolean.new.cast(dry_run)}..."
    result = PostseasonDataBackfill.call(
      start_year: start_year,
      end_year: end_year,
      dry_run: dry_run,
      force: force,
      progress: ->(message) { puts message }
    )

    data = result.fetch(:data)
    puts result[:message]
    puts "Stored final postseason games: #{data[:stored_game_count]}"
    puts "Games needing details: #{data[:target_game_count]}"
    puts "Games synchronized: #{data[:synchronized_game_count]}"
    puts "Batting lines imported: #{data[:batting_line_count]}"
    puts "Pitching lines imported: #{data[:pitching_line_count]}"
    puts "Failures: #{data[:failed_game_count]}"

    unless result[:success]
      data.fetch(:errors, []).each do |error|
        warn "- #{error[:season]} #{error[:stage]}#{" MLB #{error[:mlb_id]}" if error[:mlb_id]}: #{error[:message]}"
      end
      abort "Postseason data backfill failed"
    end
  end
end
