class DailyInSeasonSync
  GAME_TYPES = "R"
  SCHEDULE_GAME_TYPES = MlbScheduleDownloader::DEFAULT_GAME_TYPES

  def self.call(start_date:, end_date: start_date, season: nil)
    new(start_date: start_date, end_date: end_date, season: season).call
  end

  def initialize(start_date:, end_date:, season: nil)
    @start_date = parse_date(start_date)
    @end_date = parse_date(end_date)
    @season = Integer(season || @end_date&.year, exception: false)
  end

  def call
    return failure("Start date and end date must be valid ISO dates") if start_date.nil? || end_date.nil?
    return failure("End date must be on or after start date") if end_date < start_date
    return failure("Season must be a valid year") if season.nil? || season <= 1800

    summary = { start_date: start_date.iso8601, end_date: end_date.iso8601, season: season, stages: [] }

    synchronize("schedules", summary) { MlbScheduleSync.call(start_date: start_date, end_date: end_date, game_types: SCHEDULE_GAME_TYPES, sport_id: 1) }
    synchronize("game details", summary) { MlbGameDetailsBatchSync.call(start_date: start_date, end_date: end_date) }
    synchronize("Statcast", summary, continue_on_failure: true) do
      PitchDataBatchSync.call(
        start_date: start_date,
        end_date: end_date,
        game_types: GAME_TYPES,
        chunk_days: NineLensConfig.fetch(:operations, :pitch_data, :default_chunk_days),
        progress_callback: ->(**event) { report_statcast_download_progress(**event) }
      )
    end
    synchronize_season_stats(summary)
    synchronize("40-man rosters", summary) do
      MlbRosterBatchSync.call(
        scope: "all",
        season: season,
        roster_type: MlbRosterDownloader::DEFAULT_ROSTER_TYPE,
        as_of: MlbRosterSyncBoundary.call(season: season)
      )
    end
    synchronize("missing player profiles", summary) { MlbPlayerProfilesSync.call(only_missing: true) }
    #synchronize("MLB transaction histories", summary) { MlbPlayerTeamHistoriesSync.call }
    synchronize("contextual benchmarks", summary) do
      ContextualBenchmarkRefresh.call(start_date: start_date, end_date: end_date)
    end

    failed_stages = summary[:stages].reject { |stage| stage[:success] }
    if failed_stages.any?
      details = failed_stages.map { |stage| stage[:message] }.join("; ")
      return failure("Completed remaining daily in-season refresh stages with failures: #{details}", summary)
    end

    success("Completed daily in-season refresh for #{start_date} through #{end_date}", summary)
  rescue StandardError => error
    failure(error.message, summary || {})
  end

  private

  attr_reader :start_date, :end_date, :season

  def synchronize_season_stats(summary)
    %w[batting pitching].each do |category|
      synchronize("#{category} season stats", summary) do
        download = PlayerStatsDownloader.call(category: category, start_year: season, end_year: season)
        raise download[:message] unless download[:success]

        PlayerStatsImporter.call(
          csv_data: download.dig(:data, :csv_data),
          source_name: "MLB #{category} season stats #{season}",
          replace_season: true
        )
      end
    end
  end

  def synchronize(name, summary, continue_on_failure: false)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    puts "→ Starting #{name}..."
    $stdout.flush

    result = yield
    raise "#{name} failed: #{result[:message]}" unless result[:success]

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    summary[:stages] << { name: name, success: true, message: result[:message], data: result[:data] }
    puts format("✓ Finished %<name>s in %<elapsed>.1fs: %<message>s", name: name, elapsed: elapsed, message: result[:message])
    $stdout.flush
  rescue StandardError => error
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    failure_message = error.message.start_with?("#{name} failed:") ? error.message : "#{name} failed: #{error.message}"
    summary[:stages] << { name: name, success: false, message: failure_message, data: {} }

    puts format("✗ Failed %<name>s in %<elapsed>.1fs: %<message>s", name: name, elapsed: elapsed, message: failure_message)

    if continue_on_failure
      puts "⚠ Continuing with the remaining daily in-season sync stages..."
      $stdout.flush
      return
    end

    $stdout.flush
    raise
  end

  def report_statcast_download_progress(event:, chunk_start:, chunk_end:, chunk_index:, chunk_count:, game_count:, row_count: nil, message: nil)
    range = "#{chunk_start.iso8601} through #{chunk_end.iso8601}"
    prefix = "  [Statcast #{chunk_index}/#{chunk_count}]"

    case event
    when :download_started
      puts "#{prefix} Downloading #{range} (#{game_count} game#{'s' unless game_count == 1})..."
    when :download_finished
      puts "#{prefix} Downloaded #{row_count.to_i} pitch rows for #{range}."
    when :download_failed
      puts "#{prefix} Download failed for #{range}: #{message}"
    end
    $stdout.flush
  end

  def parse_date(value)
    return value if value.is_a?(Date)

    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end

  def success(message, data)
    { success: true, message: message, data: data }
  end

  def failure(message, data = {})
    { success: false, message: message, data: data.merge(errors: [ message ]) }
  end
end
