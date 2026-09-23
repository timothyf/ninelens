require "fileutils"

namespace :mlb_contracts do
  desc "Download MLB player salary and contract data from FanGraphs RosterResource. Usage: bin/rails 'mlb_contracts:download[2026]'"
  task :download, [:season] => :environment do |_task, args|
    season = args[:season].presence || ENV["SEASON"].presence || Date.current.year
    result = MlbPlayerContractsDownloader.call(season: season)
    abort result[:message] unless result[:success]

    output_path = ENV["OUTPUT"].presence || Rails.root.join("tmp", "mlb_contracts_#{season}.csv").to_s
    FileUtils.mkdir_p(File.dirname(output_path))
    File.write(output_path, result.dig(:data, :csv_data))
    puts result[:message]
    puts "Saved #{result.dig(:data, :row_count)} rows to #{output_path}"
  end
end
