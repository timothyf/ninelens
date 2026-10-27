require "csv"

class PitchDataImporter
  UPSERT_INDEX = :idx_pitch_data_unique_pitch
  EXCLUDED_DYNAMIC_COLUMNS = %w[
    id
    created_at
    updated_at
    active_spin
    source_start_date
    source_end_date
    fetched_at_utc
    game_date
    game_pk
    game_id
    plate_appearance_id
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
  ].freeze

  def self.call(csv_data: nil, file_path: nil, source_name: nil)
    new(csv_data: csv_data, file_path: file_path, source_name: source_name).call
  end

  def self.import_rows(rows:, source_name: nil)
    new(source_name: source_name).import_rows(rows)
  end

  def self.import_raw_rows(rows:, source_name: nil, replace_game_id: nil, replace_game_ids: nil, refresh_analytics: true)
    new(
      source_name: source_name,
      replace_game_id: replace_game_id,
      replace_game_ids: replace_game_ids,
      refresh_analytics: refresh_analytics
    ).send(:import_raw_rows, rows)
  end

  def initialize(csv_data: nil, file_path: nil, source_name: nil, replace_game_id: nil, replace_game_ids: nil, refresh_analytics: true)
    @csv_data = csv_data
    @file_path = file_path
    @source_name = source_name
    @replace_game_id = replace_game_id
    @replace_game_ids = replace_game_ids
    @refresh_analytics = refresh_analytics
    @errors = []
  end

  def call
    return failure("CSV data or file path is required") if csv_source.blank?

    csv = CSV.parse(csv_source, headers: true)
    return failure("CSV must include headers") if csv.headers.blank?

    missing = required_headers.reject { |header| csv.headers.include?(header) }
    return failure("Missing required columns: #{missing.join(', ')}") if missing.any?

    rows = build_rows(csv)
    return failure("No valid pitch data rows found in CSV") if rows.empty?

    link_games(rows)
    persist_rows(rows)

    linked_count = rows.count { |row| row[:game_id].present? }
    analytics_refresh = refresh_daily_analytics(rows)

    success(
      "Imported #{rows.length} pitch data rows",
      {
        imported_count: rows.length,
        skipped_count: errors.length,
        duplicate_count: @duplicate_count || 0,
        linked_game_count: linked_count,
        unlinked_game_count: rows.length - linked_count,
        source_name: resolved_source_name,
        analytics_refresh: analytics_refresh,
        errors: errors
      }
    )
  rescue CSV::MalformedCSVError => e
    failure("Failed to parse CSV: #{e.message}")
  rescue Errno::ENOENT => e
    failure("Failed to read CSV file: #{e.message}")
  rescue ActiveRecord::ActiveRecordError => e
    failure("Failed to import pitch data: #{e.message}")
  end

  private

  attr_reader :csv_data, :file_path, :source_name, :replace_game_id, :replace_game_ids, :refresh_analytics, :errors

  def import_rows(rows)
    return failure("No valid pitch data rows found in CSV") if rows.blank?

    link_games(rows)
    persist_rows(rows)

    linked_count = rows.count { |row| row[:game_id].present? }
    analytics_refresh = refresh_analytics ? refresh_daily_analytics(rows) : deferred_analytics_refresh

    success(
      "Imported #{rows.length} pitch data rows",
      {
        imported_count: rows.length,
        skipped_count: errors.length,
        duplicate_count: @duplicate_count || 0,
        linked_game_count: linked_count,
        unlinked_game_count: rows.length - linked_count,
        source_name: resolved_source_name,
        analytics_refresh: analytics_refresh,
        errors: errors
      }
    )
  end

  def import_raw_rows(rows)
    timestamp = Time.current
    @duplicate_count = 0
    rows_by_identity = {}

    rows.each_with_index do |row, index|
      source_row_number = index + 1
      attrs = build_row(row, source_row_number)
      next if attrs.nil?

      row_key = [ attrs[:game_pk], attrs[:at_bat_number], attrs[:pitch_number] ]
      @duplicate_count += 1 if rows_by_identity.key?(row_key)
      rows_by_identity[row_key] = attrs.merge(created_at: timestamp, updated_at: timestamp)
    end

    import_rows(rows_by_identity.values)
  end

  def refresh_daily_analytics(rows)
    dates = rows.filter_map { |row| row[:game_date] }.uniq
    return { skipped: true, reason: "Imported rows did not include game dates" } if dates.empty?

    DailyAnalyticsRefresh.call(dates: dates)
  rescue StandardError => error
    { success: false, message: "Pitch data was imported, but daily analytics refresh failed: #{error.message}" }
  end

  def deferred_analytics_refresh
    { skipped: true, reason: "Daily analytics refresh deferred to the batch sync" }
  end

  def persist_rows(rows)
    PitchDatum.transaction do
      replacement_game_ids = Array(replace_game_ids.presence || replace_game_id).compact
      PitchDatum.where(game_id: replacement_game_ids).delete_all if replacement_game_ids.any?
      PitchDatum.upsert_all(rows, unique_by: UPSERT_INDEX)
    end
  end

  def required_headers
    %w[game_pk at_bat_number pitch_number]
  end

  def csv_source
    @csv_source ||= if csv_data.present?
      csv_data
    elsif file_path.present?
      File.read(file_path)
    end
  end

  def resolved_source_name
    source_name.presence || file_path.to_s.presence || "uploaded_csv"
  end

  def build_rows(csv)
    timestamp = Time.current
    @duplicate_count = 0
    rows_by_identity = {}

    csv.each_with_index do |row, index|
      source_row_number = index + 2
      attrs = build_row(row.to_h, source_row_number)
      next if attrs.nil?

      row_key = [ attrs[:game_pk], attrs[:at_bat_number], attrs[:pitch_number] ]
      @duplicate_count += 1 if rows_by_identity.key?(row_key)
      rows_by_identity[row_key] = attrs.merge(created_at: timestamp, updated_at: timestamp)
    end

    rows_by_identity.values
  end

  def build_row(row_hash, source_row_number)
    normalized = normalize_row(row_hash)

    game_pk = parse_integer(normalized["game_pk"])
    at_bat_number = parse_integer(normalized["at_bat_number"])
    pitch_number = parse_integer(normalized["pitch_number"])

    if game_pk.nil? || at_bat_number.nil? || pitch_number.nil?
      errors << {
        row_number: source_row_number,
        error: "Missing required identifiers (game_pk, at_bat_number, pitch_number)"
      }
      return nil
    end

    {
      source_start_date: parse_date(normalized["source_start_date"]),
      source_end_date: parse_date(normalized["source_end_date"]),
      fetched_at_utc: parse_datetime(normalized["fetched_at_utc"]),
      game_date: parse_date(normalized["game_date"]),
      game_pk: game_pk,
      game_type: normalized["game_type"],
      home_team: normalized["home_team"],
      away_team: normalized["away_team"],
      inning: parse_integer(normalized["inning"]),
      inning_topbot: normalized["inning_topbot"],
      at_bat_number: at_bat_number,
      pitch_number: pitch_number,
      pitcher: parse_integer(normalized["pitcher"]),
      player_name: normalized["player_name"],
      batter: parse_integer(normalized["batter"]),
      stand: normalized["stand"],
      p_throws: normalized["p_throws"],
      pitch_type: normalized["pitch_type"],
      pitch_name: normalized["pitch_name"],
      description: normalized["description"],
      events: normalized["events"],
      **build_dynamic_attributes(normalized),
      active_spin: active_spin_from(normalized)
    }
  end

  def link_games(rows)
    game_ids_by_mlb_id = Game
      .where(mlb_id: rows.map { |row| row[:game_pk] }.uniq)
      .pluck(:mlb_id, :id)
      .to_h

    rows.each do |row|
      row[:game_id] = game_ids_by_mlb_id[row[:game_pk]]
    end


    plate_appearance_ids = PlateAppearance
      .where(game_id: game_ids_by_mlb_id.values)
      .pluck(:game_id, :plate_appearance_number, :id)
      .to_h { |game_id, number, id| [ [ game_id, number ], id ] }

    rows.each do |row|
      row[:plate_appearance_id] = plate_appearance_ids[[ row[:game_id], row[:at_bat_number] ]]
    end
  end

  def build_dynamic_attributes(normalized)
    dynamic_column_types.each_with_object({}) do |(column_name, column_type), attrs|
      value = normalized[column_name]
      attrs[column_name.to_sym] = cast_value(value, column_type)
    end
  end

  def dynamic_column_types
    @dynamic_column_types ||= PitchDatum.columns_hash
      .except(*EXCLUDED_DYNAMIC_COLUMNS)
      .transform_values(&:type)
  end

  def cast_value(value, column_type)
    return nil if value.blank?

    case column_type
    when :integer, :bigint
      parse_integer(value)
    when :float, :decimal
      parse_float(value)
    when :date
      parse_date(value)
    when :datetime
      parse_datetime(value)
    when :boolean
      parse_boolean(value)
    else
      value
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

  def parse_integer(value)
    return nil if value.blank?

    Integer(value.to_s, exception: false)
  end

  def parse_date(value)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def parse_float(value)
    return nil if value.blank?

    Float(value.to_s)
  rescue ArgumentError
    nil
  end

  def active_spin_from(row)
    value = row["active_spin"] || row["spin_efficiency"]
    value&.to_f
  end

  def parse_datetime(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def parse_boolean(value)
    return value if value == true || value == false

    normalized = value.to_s.strip.downcase
    return true if %w[1 true t yes y on].include?(normalized)
    return false if %w[0 false f no n off].include?(normalized)

    nil
  end

  def success(message, data = nil)
    { success: true, message: message, data: data }
  end

  def failure(message)
    { success: false, message: message, data: { errors: errors } }
  end
end
