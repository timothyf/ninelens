require "bigdecimal"
require "csv"
require "json"

class PlayerStatsImporter
  PLAYER_ID_FIELDS = %w[player_id playerid playerId id].freeze
  USE_NAME_FIELDS = %w[use_name usename playerusename playerUseName].freeze
  FIRST_NAME_FIELDS = %w[first_name firstname playerfirstname playerFirstName].freeze
  LAST_NAME_FIELDS = %w[last_name lastname playerlastname playerLastName].freeze
  FULL_NAME_FIELDS = %w[name full_name fullname playerfullname playerFullName playername playerName].freeze

  TEAM_NAME_FIELDS = %w[teamname teamName].freeze
  TEAM_ABBREVIATION_FIELDS = %w[teamabbrev teamAbbrev abbreviation abbrev].freeze
  TEAM_SHORT_NAME_FIELDS = %w[teamshortname teamShortName short_name shortname].freeze
  TEAM_ID_FIELDS = %w[teamid teamId].freeze

  SEASON_FIELDS = %w[season year source_season sourceSeason].freeze
  STAT_GROUP_FIELDS = %w[stat_type statType].freeze
  FIELDING_BY_POSITION_FIELDS = %w[fieldingByPosition fielding_by_position].freeze

  CATEGORY_MAP = {
    "batter" => "batting",
    "batting" => "batting",
    "hitting" => "batting",
    "pitcher" => "pitching",
    "pitching" => "pitching",
    "pitchstats" => "pitchStats",
    "pitch_stats" => "pitchStats"
  }.freeze

  STAT_IMPORT_ALIASES = {
    "pitching" => {
      "W" => %w[W wins],
      "L" => %w[L losses],
      "ERA" => %w[ERA era earnedRunAverage],
      "G" => %w[G gamesPitched gamesPlayed],
      "GS" => %w[GS gamesStarted],
      "CG" => %w[CG completeGames],
      "ShO" => %w[ShO shutouts shutout],
      "SV" => %w[SV saves],
      "SVO" => %w[SVO saveOpportunities],
      "IP" => %w[IP inningsPitched],
      "inningsPitched" => %w[inningsPitched IP],
      "H" => %w[H hits],
      "hits" => %w[hits H],
      "R" => %w[R runs],
      "runs" => %w[runs R],
      "ER" => %w[ER earnedRuns],
      "HR" => %w[HR homeRuns],
      "homeRuns" => %w[homeRuns HR],
      "HBP" => %w[HBP hitByPitch hitBatsmen],
      "hitByPitch" => %w[hitByPitch hitBatsmen HBP],
      "BB" => %w[BB baseOnBalls walks],
      "baseOnBalls" => %w[baseOnBalls BB walks],
      "SO" => %w[SO strikeOuts strikeouts],
      "strikeOuts" => %w[strikeOuts strikeouts SO],
      "WHIP" => %w[WHIP whip],
      "whip" => %w[whip WHIP],
      "AVG" => %w[AVG avg],
      "avg" => %w[avg AVG],
      "WAR" => %w[WAR war],
      "TBF" => %w[TBF battersFaced],
      "battersFaced" => %w[battersFaced TBF],
      "K/9" => %w[K/9 strikeoutsPer9Inn],
      "BB/9" => %w[BB/9 walksPer9Inn],
      "K/BB" => %w[K/BB strikeoutWalkRatio],
      "HR/9" => %w[HR/9 homeRunsPer9],
      "H/9" => %w[H/9 hitsPer9Inn]
    }
  }.freeze

  UPSERT_SCOPE_INDEX = :idx_player_season_stats_unique_scope
  LEAGUE_SCOPE_KEYS = %w[AL NL MLB].freeze

  def self.call(csv_data: nil, file_path: nil, source_name: nil, required_stat_columns: [], replace_season: false)
    new(
      csv_data: csv_data,
      file_path: file_path,
      source_name: source_name,
      required_stat_columns: required_stat_columns,
      replace_season: replace_season
    ).call
  end

  def initialize(csv_data: nil, file_path: nil, source_name: nil, required_stat_columns: [], replace_season: false)
    @csv_data = csv_data
    @file_path = file_path
    @source_name = source_name
    @required_stat_columns = Array(required_stat_columns).map { |column| column.to_s.strip }.reject(&:blank?)
    @replace_season = cast_boolean(replace_season)
    @errors = []
  end

  def call
    return failure("CSV data or file path is required") if csv_source.blank?
    return failure("Source name is required") if resolved_source_name.blank?

    csv = CSV.parse(csv_source, headers: true)
    return failure("CSV must include headers") if csv.headers.blank?

    missing_columns = missing_required_stat_columns(csv.headers)
    return failure("Missing required stat columns: #{missing_columns.join(', ')}") if missing_columns.any?

    import_rows = build_import_rows(csv)
    return failure("No valid player season stat rows found in CSV") if import_rows.empty?

    persisted = persist_rows(import_rows)
    success(
      "Imported #{persisted[:imported_count]} player season stats",
      persisted.merge(
        skipped_count: errors.length,
        duplicate_count: @duplicate_count || 0,
        replace_season: replace_season?,
        errors: errors
      )
    )
  rescue CSV::MalformedCSVError => e
    failure("Failed to parse CSV: #{e.message}")
  rescue Errno::ENOENT => e
    failure("Failed to read CSV file: #{e.message}")
  rescue ActiveRecord::ActiveRecordError => e
    failure("Failed to import player season stats: #{e.message}")
  end

  private

  attr_reader :csv_data, :file_path, :source_name, :required_stat_columns, :errors

  def replace_season?
    @replace_season
  end

  def csv_source
    @csv_source ||= if csv_data.present?
      csv_data
    elsif file_path.present?
      File.read(file_path)
    end
  end

  def resolved_source_name
    @resolved_source_name ||= source_name.presence || file_path.to_s.presence
  end

  def missing_required_stat_columns(headers)
    normalized_headers = headers.compact.map { |header| header.to_s.strip.downcase }

    required_stat_columns.reject do |column|
      normalized_headers.include?(column.downcase)
    end
  end

  def build_import_rows(csv)
    @duplicate_count = 0
    rows_by_identity = {}

    csv.each_with_index do |row, index|
      source_row_number = index + 2
      import_row = build_import_row(row, source_row_number)
      next if import_row.nil?

      row_key = [ import_row[:player_mlb_id], import_row[:season], import_row[:category], import_row[:scope_type], import_row[:scope_key] ]
      @duplicate_count += 1 if rows_by_identity.key?(row_key)
      rows_by_identity[row_key] = import_row
    end

    rows_by_identity.values
  end

  def build_import_row(row, source_row_number)
    normalized_row = normalize_row(row.to_h)
    key_map = normalized_row.keys.index_by { |key| key.downcase }

    player_mlb_id = parse_integer(fetch_value(normalized_row, key_map, PLAYER_ID_FIELDS))
    first_name = fetch_value(normalized_row, key_map, USE_NAME_FIELDS).presence || fetch_value(normalized_row, key_map, FIRST_NAME_FIELDS)
    last_name = fetch_value(normalized_row, key_map, LAST_NAME_FIELDS)

    if first_name.blank? || last_name.blank?
      derived_first_name, derived_last_name = split_name(fetch_value(normalized_row, key_map, FULL_NAME_FIELDS))
      first_name ||= derived_first_name
      last_name ||= derived_last_name
    end

    season = parse_integer(fetch_value(normalized_row, key_map, SEASON_FIELDS))
    category = normalize_category(fetch_value(normalized_row, key_map, STAT_GROUP_FIELDS))
    team_attributes = build_team_attributes(normalized_row, key_map)
    stat_entries = build_stat_entries(normalized_row, key_map, category)
    fielding_position_rows = parse_fielding_position_rows(fetch_value(normalized_row, key_map, FIELDING_BY_POSITION_FIELDS))

    missing_identity_fields = []
    missing_identity_fields << "playerId" if player_mlb_id.nil?
    missing_identity_fields << "playerFirstName" if first_name.blank?
    missing_identity_fields << "playerLastName" if last_name.blank?
    missing_identity_fields << "season" if season.nil?
    missing_identity_fields << "stat_type" if category.blank?

    if missing_identity_fields.any?
      errors << row_error(source_row_number, "Missing required player season fields: #{missing_identity_fields.join(', ')}")
      return nil
    end

    if team_attributes.values.any?(&:blank?)
      missing_team_fields = team_attributes.select { |_key, value| value.blank? }.keys
      errors << row_error(source_row_number, "Missing required team fields: #{missing_team_fields.join(', ')}")
      return nil
    end

    if stat_entries.empty?
      errors << row_error(source_row_number, "No importable #{category} stats found for player #{player_mlb_id}")
      return nil
    end

    {
      player_mlb_id: player_mlb_id,
      first_name: first_name,
      last_name: last_name,
      season: season,
      category: category,
      team_attributes: team_attributes,
      scope_type: scope_type_for(team_attributes),
      scope_key: scope_key_for(team_attributes),
      stat_entries: stat_entries,
      fielding_position_rows: fielding_position_rows
    }
  end

  def scope_type_for(team_attributes)
    abbreviation = team_attributes[:abbreviation].to_s.upcase
    return "combined" if abbreviation == "TOT"
    return "league" if LEAGUE_SCOPE_KEYS.include?(abbreviation)

    "team"
  end

  def scope_key_for(team_attributes)
    abbreviation = team_attributes[:abbreviation].to_s.upcase
    return abbreviation if abbreviation.present?

    team_attributes[:mlb_id].to_s
  end

  def build_team_attributes(normalized_row, key_map)
    team_abbreviation = fetch_value(normalized_row, key_map, TEAM_ABBREVIATION_FIELDS)
    full_team_name = fetch_value(normalized_row, key_map, TEAM_NAME_FIELDS)
    short_name = fetch_value(normalized_row, key_map, TEAM_SHORT_NAME_FIELDS).presence || full_team_name
    team_mlb_id = parse_integer(fetch_value(normalized_row, key_map, TEAM_ID_FIELDS))

    derived_location_name = if full_team_name.present? && short_name.present? && full_team_name.end_with?(short_name) && full_team_name != short_name
      full_team_name.delete_suffix(short_name).strip.presence || full_team_name
    else
      full_team_name
    end

    derived_team_name = short_name.presence || full_team_name
    derived_team_code = team_mlb_id.presence || team_abbreviation.to_s.downcase.presence

    {
      mlb_id: team_mlb_id,
      name: full_team_name.presence || derived_team_name,
      abbreviation: team_abbreviation,
      team_name: derived_team_name,
      location_name: derived_location_name,
      short_name: short_name,
      team_code: derived_team_code,
      file_code: derived_team_code
    }
  end

  def build_stat_entries(normalized_row, key_map, category)
    return [] if category.blank?

    stat_types_for_category(category).filter_map do |stat_type|
      raw_value = fetch_value(normalized_row, key_map, stat_lookup_names(stat_type, category))
      numeric_value = parse_numeric_value(raw_value)
      next if numeric_value.nil?

      { stat_type: stat_type, value: numeric_value }
    end
  end

  def stat_lookup_names(stat_type, category)
    category_aliases = STAT_IMPORT_ALIASES.fetch(category, {})
    aliases = category_aliases.fetch(stat_type.name, [ stat_type.name ])

    ([ stat_type.name, stat_type.label ] + aliases).compact.uniq
  end

  def stat_types_for_category(category)
    @stat_types_for_category ||= StatType.cached_all.group_by(&:category)
    @stat_types_for_category.fetch(category, [])
  end
  def parse_fielding_position_rows(value)
    return [] if value.blank?

    Array(JSON.parse(value)).filter_map do |row|
      position = row["position"].to_s.strip
      next if position.blank?

      {
        team_abbreviation: row["team_abbreviation"].to_s.strip.upcase.presence || "TOT",
        position: position,
        games: parse_integer(row["games"]),
        innings: parse_numeric_value(row["innings"]),
        putouts: parse_integer(row["putouts"]),
        assists: parse_integer(row["assists"]),
        fielding_errors: parse_integer(row["fielding_errors"] || row["errors"]),
        fielding_percentage: parse_numeric_value(row["fielding_percentage"]),
        defensive_runs_saved: parse_numeric_value(row["defensive_runs_saved"]),
        outs_above_average: parse_numeric_value(row["outs_above_average"])
      }
    end
  end


  def persist_rows(import_rows)
    timestamp = Time.current
    season_stat_records = []
    fielding_stat_records = []
    created_player_count = 0
    created_team_count = 0
    replaced_rows_count = 0

    PlayerSeasonStat.transaction do
      replaced_rows_count = replace_existing_season_rows(import_rows) if replace_season?

      import_rows.each do |import_row|
        team = Team.find_or_initialize_by(mlb_id: import_row[:team_attributes][:mlb_id])
        created_team_count += 1 if team.new_record?
        team.assign_attributes(import_row[:team_attributes])
        team.save!

        player = Player.find_or_initialize_by(mlb_id: import_row[:player_mlb_id])
        created_player_count += 1 if player.new_record?
        player.assign_attributes(
          first_name: import_row[:first_name],
          last_name: import_row[:last_name],
          team: team
        )
        player.save!

        import_row[:stat_entries].each do |stat_entry|
          season_stat_records << {
            player_id: player.id,
            team_id: import_row[:scope_type] == "team" ? team.id : nil,
            stat_type_id: stat_entry[:stat_type].id,
            season: import_row[:season],
            scope_type: import_row[:scope_type],
            scope_key: import_row[:scope_key],
            value: stat_entry[:value],
            created_at: timestamp,
            updated_at: timestamp
          }
        end
        if import_row[:fielding_position_rows].any?
          PlayerSeasonFieldingStat.where(player: player, season: import_row[:season]).delete_all
        end
        import_row[:fielding_position_rows].each do |fielding_row|
          fielding_team = if fielding_row[:team_abbreviation] == team.abbreviation
            team
          else
            Team.find_by(abbreviation: fielding_row[:team_abbreviation])
          end
          fielding_stat_records << fielding_row.merge(
            player_id: player.id,
            team_id: fielding_team&.id,
            season: import_row[:season],
            source_name: resolved_source_name,
            last_synced_at: timestamp,
            created_at: timestamp,
            updated_at: timestamp
          )
        end
      end

      PlayerSeasonFieldingStat.upsert_all(fielding_stat_records, unique_by: :idx_player_season_fielding_stats_unique_scope) if fielding_stat_records.any?
      PlayerSeasonStat.upsert_all(season_stat_records, unique_by: UPSERT_SCOPE_INDEX) if season_stat_records.any?
    end

    {
      fielding_imported_count: fielding_stat_records.length,
      imported_count: season_stat_records.length,
      created_player_count: created_player_count,
      created_team_count: created_team_count,
      replaced_rows_count: replaced_rows_count
    }
  end

  def replace_existing_season_rows(import_rows)
    scopes = import_rows.group_by { |row| [ row[:season], row[:category] ] }

    scopes.sum do |(season, category), rows|
      stat_type_ids = rows.flat_map { |row| row[:stat_entries].map { |entry| entry[:stat_type].id } }.uniq
      next 0 if stat_type_ids.empty?

      PlayerSeasonFieldingStat.where(season: season).delete_all if category == "batting"
      PlayerSeasonStat.where(season: season, stat_type_id: stat_type_ids).delete_all
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

  def fetch_value(normalized_row, key_map, aliases)
    aliases.each do |field_name|
      matched_key = key_map[field_name.to_s.downcase]
      return normalized_row[matched_key] if matched_key
    end

    nil
  end

  def split_name(full_name)
    return [ nil, nil ] if full_name.blank?

    parts = full_name.to_s.split
    return [ parts.first, nil ] if parts.one?

    [ parts[0..-2].join(" "), parts.last ]
  end

  def normalize_category(raw_category)
    CATEGORY_MAP[raw_category.to_s.strip.downcase]
  end

  def parse_integer(value)
    return nil if value.blank?

    Integer(value.to_s, exception: false)
  end

  def parse_numeric_value(value)
    return nil if value.blank?

    normalized_value = value.to_s.strip
    return nil if normalized_value.blank?
    return nil if normalized_value.match?(/\A-?\.-{2,}\z|\A\.---\z|\A-\.\-\-\z|\A\.--+\z|\A-\z/)

    BigDecimal(normalized_value)
  rescue ArgumentError
    nil
  end

  def cast_boolean(value)
    return value if value == true || value == false

    %w[1 true t yes y on].include?(value.to_s.strip.downcase)
  end

  def row_error(source_row_number, message)
    {
      row_number: source_row_number,
      error: message
    }
  end

  def success(message, data = nil)
    { success: true, message: message, data: data }
  end

  def failure(message)
    { success: false, message: message, data: { errors: errors } }
  end
end
