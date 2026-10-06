require "csv"
require "net/http"

class PitchDataDownloader
  VALID_GAME_TYPES = %w[R S F D L W].freeze
  DEFAULT_GAME_TYPES = MlbScheduleDownloader::DEFAULT_GAME_TYPES

  METADATA_COLUMNS = %w[
    source_start_date
    source_end_date
    fetched_at_utc
  ].freeze

  PREFERRED_COLUMNS = METADATA_COLUMNS + %w[
    game_date
    game_pk
    game_type
    home_team
    away_team
    inning
    inning_topbot
    at_bat_number
    pitch_number
    pitcher
    player_name
    batter
    stand
    p_throws
    pitch_type
    pitch_name
    description
    events
    balls
    strikes
    outs_when_up
    release_speed
    release_spin_rate
    release_extension
    release_pos_x
    release_pos_y
    release_pos_z
    pfx_x
    pfx_z
    plate_x
    plate_z
    zone
    launch_speed
    launch_angle
    hit_distance_sc
    bb_type
    estimated_ba_using_speedangle
    estimated_woba_using_speedangle
    woba_value
    delta_run_exp
    bat_score
    fld_score
    post_bat_score
    post_fld_score
    sv_id
  ].freeze

  attr_reader :start_date, :end_date, :game_types, :chunk_days, :delay

  def self.call(start_date:, end_date:, game_types: DEFAULT_GAME_TYPES, chunk_days: nil, delay: 0.0)
    new(
      start_date: start_date,
      end_date: end_date,
      game_types: game_types,
      chunk_days: chunk_days,
      delay: delay
    ).call
  end

  def initialize(start_date:, end_date:, game_types: DEFAULT_GAME_TYPES, chunk_days: nil, delay: 0.0)
    @start_date = parse_date(start_date)
    @end_date = parse_date(end_date)
    @game_types = parse_game_types(game_types)
    @chunk_days = Integer(chunk_days.presence || service_config.fetch(:default_chunk_days), exception: false)
    @delay = delay.to_f
  end

  def call
    return failure("Start date is required") if start_date.nil?
    return failure("End date is required") if end_date.nil?
    return failure("Statcast pitch data is not available before 2008") if start_date < Date.new(2008, 1, 1)
    return failure("End date must be greater than or equal to start date") if end_date < start_date
    return failure("At least one game type is required") if game_types.empty?
    return failure("Unsupported game type(s): #{invalid_game_types.join(', ')}") if invalid_game_types.any?
    return failure("Chunk days must be at least 1") if chunk_days.nil? || chunk_days < 1

    rows = fetch_rows
    return failure("No pitch data rows returned from Baseball Savant") if rows.empty?

    success(
      "Downloaded #{rows.length} pitch data rows from Baseball Savant",
      rows: rows,
      csv_data: build_csv(rows),
      row_count: rows.length,
      start_date: start_date.iso8601,
      end_date: end_date.iso8601,
      game_types: game_types,
      chunk_days: chunk_days
    )
  rescue CSV::MalformedCSVError => e
    failure("Failed to parse Baseball Savant CSV: #{e.message}")
  rescue StandardError => e
    failure("Failed to download pitch data: #{e.message}")
  end

  private

  def parse_date(value)
    return nil if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def parse_game_types(value)
    Array(value.to_s.split(",")).map { |item| item.strip.upcase }.reject(&:blank?).uniq
  end

  def invalid_game_types
    @invalid_game_types ||= game_types - VALID_GAME_TYPES
  end

  def fetch_rows
    date_chunks.flat_map do |chunk_start, chunk_end|
      rows = parse_chunk(fetch_csv(build_url(chunk_start, chunk_end)), chunk_start, chunk_end)
      sleep(delay) if delay.positive?
      rows
    end
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

  def build_url(chunk_start, chunk_end)
    query = {
      all: "true",
      type: "details",
      player_type: "pitcher",
      game_date_gt: (chunk_start - 1.day).iso8601,
      game_date_lt: (chunk_end + 1.day).iso8601,
      hfGT: game_types.map { |game_type| "#{game_type}|" }.join
    }.to_query

    "#{service_config.fetch(:statcast_url)}?#{query}"
  end

  def fetch_csv(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = service_config.fetch(:timeout_seconds).to_i
    http.read_timeout = service_config.fetch(:timeout_seconds).to_i

    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = service_config.fetch(:statcast_user_agent)
    request["Accept"] = "text/csv,text/plain,*/*"
    request["Referer"] = service_config.fetch(:statcast_referer)

    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    text = normalize_response_body(response.body)
    raise "Baseball Savant returned HTML instead of CSV" if text.lstrip.downcase.start_with?("<!doctype html", "<html")

    text
  end

  def service_config
    @service_config ||= NineLensConfig.fetch(:external_services, :baseball_savant).merge(
      default_chunk_days: NineLensConfig.fetch(:operations, :pitch_data, :default_chunk_days)
    )
  end

  def normalize_response_body(body)
    body.to_s
      .dup
      .force_encoding(Encoding::UTF_8)
      .scrub
  end

  def parse_chunk(csv_text, chunk_start, chunk_end)
    csv = CSV.parse(normalize_response_body(csv_text).delete_prefix("\uFEFF"), headers: true)
    return [] if csv.headers.blank?

    fetched_at_utc = Time.current.utc.iso8601

    csv.filter_map do |row|
      normalized = normalize_row(row.to_h)
      next if normalized.values.all?(&:blank?)

      normalized.merge(
        "source_start_date" => chunk_start.iso8601,
        "source_end_date" => chunk_end.iso8601,
        "fetched_at_utc" => fetched_at_utc
      )
    end
  end

  def normalize_row(row_hash)
    row_hash.each_with_object({}) do |(key, value), normalized|
      next if key.nil?

      clean_key = key.to_s.strip
      next if clean_key.empty?

      normalized[clean_key] = value.is_a?(String) ? value.strip : value
    end
  end

  def build_csv(rows)
    columns = preferred_columns(rows)

    CSV.generate(headers: true) do |csv|
      csv << columns
      rows.each { |row| csv << columns.map { |column| row[column] } }
    end
  end

  def preferred_columns(rows)
    available_columns = rows.flat_map(&:keys).compact.uniq
    preferred = PREFERRED_COLUMNS.select { |column| available_columns.include?(column) }
    preferred + available_columns.reject { |column| preferred.include?(column) }.sort
  end

  def success(message, data = {})
    { success: true, message: message, data: data }
  end

  def failure(message)
    { success: false, message: message, data: {} }
  end
end
