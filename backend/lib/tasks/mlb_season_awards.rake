namespace :mlb_season_awards do
  desc "Synchronize official award winners. Usage: bin/rails 'mlb_season_awards:sync[2025]'"
  task :sync, [ :season ] => :environment do |_task, args|
    season = args[:season].presence || ENV["SEASON"].presence || ApplicationCalendar.current_date.year
    result = MlbSeasonAwardsSync.call(season: season, force: true)
    puts result[:message]
    abort result[:message] unless result[:success]
  end

  desc "Backfill official award winners. Usage: bin/rails 'mlb_season_awards:backfill[2020,2025]'"
  task :backfill, [ :start_year, :end_year ] => :environment do |_task, args|
    first = Integer(args[:start_year], exception: false)
    last = Integer(args[:end_year], exception: false)
    abort "Provide valid start and end years" unless first && last && first > 1800 && last >= first && last <= ApplicationCalendar.current_date.year

    (first..last).each do |season|
      result = MlbSeasonAwardsSync.call(season: season, force: true)
      puts result[:message]
      abort result[:message] unless result[:success]
    end
  end
end
