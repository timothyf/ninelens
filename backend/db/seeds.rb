# Keep `db:seed` aligned with SeedFu so one command loads app fixtures. The
# test suite creates isolated lookup records in its helpers, so loading the
# development lookup seeds in test would make otherwise independent examples
# collide on names and identifiers.
SeedFu.seed unless Rails.env.test?

player_stats_csv = ENV["PLAYER_STATS_CSV"].to_s.strip

if player_stats_csv.present?
  required_stat_columns = ENV.fetch("REQUIRED_STAT_COLUMNS", "")
    .split(",")
    .map(&:strip)
    .reject(&:blank?)

  result = PlayerStatsImporter.call(
    file_path: player_stats_csv,
    source_name: player_stats_csv,
    required_stat_columns: required_stat_columns
  )

  raise result[:message] unless result[:success]

  puts result[:message]
end

puts "Tip: use `bin/rails player_stats:reimport` to reseed stat types and reimport the latest local CSV in one command." if player_stats_csv.blank?
