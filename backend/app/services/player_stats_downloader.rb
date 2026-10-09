require "csv"
require "json"
require "net/http"

class PlayerStatsDownloader
  DEFAULT_BASEBALL_REFERENCE_BATTING_WAR_URL = "https://www.baseball-reference.com/data/war_daily_bat.txt".freeze

  CATEGORY_CONFIG = {
    "batting" => {
      group: "hitting",
      stat_type: "batter",
      sort_stat: "onBasePlusSlugging",
      order: "desc"
    },
    "pitching" => {
      group: "pitching",
      stat_type: "pitcher",
      sort_stat: "earnedRunAverage",
      order: "asc"
    }
  }.freeze

  PREFERRED_COLUMNS = [
    "source_season",
    "season",
    "fetched_at_utc",
    "stat_type",
    "mlb_id",
    "playerId",
    "player.id",
    "playerName",
    "player.fullName",
    "playerFirstName",
    "playerLastName",
    "playerUseName",
    "firstName",
    "lastName",
    "teamId",
    "team.id",
    "teamAbbrev",
    "team.abbreviation",
    "teamName",
    "team.name",
    "teamShortName",
    "team.shortName",
    "gamesPlayed",
    "plateAppearances",
    "atBats",
    "runs",
    "hits",
    "doubles",
    "triples",
    "homeRuns",
    "rbi",
    "baseOnBalls",
    "intentionalWalks",
    "strikeOuts",
    "stolenBases",
    "caughtStealing",
    "avg",
    "obp",
    "slg",
    "ops",
    "wOBA",
    "wRC+",
    "OPS+",
    "Offense",
    "BaseRunning",
    "Defense",
    "DRS",
    "TZR",
    "fieldingByPosition",
    "GB%",
    "FB%",
    "LD%",
    "Pull%",
    "Cent%",
    "Oppo%",
    "Swing%",
    "O-Swing%",
    "Contact%",
    "Z-Contact%",
    "SwStr%",
    "K%",
    "BB%",
    "K-BB%",
    "K/BB",
    "BABIP",
    "LOB%",
    "ERA+",
    "ERA-",
    "FIP-",
    "FIP",
    "xFIP",
    "xFIP-",
    "SIERA",
    "xERA",
    "wOBAAllowed",
    "xwOBAAllowed",
    "RA9-Wins",
    "WPA",
    "WPA/LI",
    "RE24",
    "Clutch",
    "RAR",
    "RAA",
    "PitchingRuns",
    "pLI",
    "SD",
    "MD",
    "ballsInPlay",
    "WAR",
    "totalBases",
    "hitByPitch",
    "sacBunts",
    "sacFlies",
    "groundIntoDoublePlay",
    "wins",
    "losses",
    "earnedRunAverage",
    "gamesStarted",
    "completeGames",
    "shutouts",
    "saves",
    "saveOpportunities",
    "inningsPitched",
    "earnedRuns",
    "whip",
    "battersFaced",
    "numberOfPitches",
    "strikePercentage",
    "source_url"
  ].freeze

  attr_reader :category, :start_year, :end_year, :delay

  def self.call(category:, start_year:, end_year: Time.zone.today.year, delay: 0.0)
    new(category: category, start_year: start_year, end_year: end_year, delay: delay).call
  end

  def initialize(category:, start_year:, end_year: Time.zone.today.year, delay: 0.0)
    @category = normalize_category(category)
    @start_year = parse_year(start_year)
    @end_year = parse_year(end_year)
    @delay = delay.to_f
  end

  def call
    return failure("Category must be batting or pitching") unless config
    return failure("Start year is required") if start_year.nil?
    return failure("End year is required") if end_year.nil?
    return failure("Start year looks too early for modern MLB data") if start_year < 1876
    return failure("End year must be greater than or equal to start year") if end_year < start_year

    rows = fetch_rows
    return failure("No #{category} rows returned from MLB") if rows.empty?

    success(
      "Downloaded #{rows.length} #{category} player season rows from MLB",
      csv_data: build_csv(rows),
      row_count: rows.length,
      category: category,
      seasons: (start_year..end_year).to_a
    )
  rescue JSON::ParserError => e
    failure("Failed to parse MLB response: #{e.message}")
  rescue StandardError => e
    failure("Failed to download MLB stats: #{e.message}")
  end

  private

  def config
    CATEGORY_CONFIG[category]
  end

  def service_config
    @service_config ||= {
      base_url: NineLensConfig.fetch(:external_services, :mlb_player_stats, :base_url),
      timeout_seconds: NineLensConfig.fetch(:external_services, :mlb_player_stats, :timeout_seconds),
      user_agent: NineLensConfig.fetch(:external_services, :mlb_player_stats, :user_agent),
      fangraphs_url: NineLensConfig.fetch(:external_services, :fangraphs, :leaders_url),
      baseball_reference_url: NineLensConfig.fetch(:external_services, :baseball_reference, :war_url),
      baseball_reference_batting_url: batting_baseball_reference_url,
      baseballsavant_leaderboard_url: NineLensConfig.fetch(:external_services, :baseball_savant, :leaderboard_url),
      baseballsavant_user_agent: NineLensConfig.fetch(:external_services, :baseball_savant, :player_stats_user_agent),
      referers: NineLensConfig.fetch(:external_services, :mlb_player_stats, :referers)
    }
  end

  def batting_baseball_reference_url
    return unless category == "batting"

    NineLensConfig.fetch(:external_services, :baseball_reference).fetch(
      :batting_war_url,
      DEFAULT_BASEBALL_REFERENCE_BATTING_WAR_URL
    )
  end

  def page_size
    NineLensConfig.fetch(:operations, :player_stats, :page_size).to_i
  end

  def normalize_category(value)
    case value.to_s.strip.downcase
    when "batter", "batters", "hitting"
      "batting"
    when "pitcher", "pitchers"
      "pitching"
    else
      value.to_s.strip.downcase
    end
  end

  def parse_year(value)
    return nil if value.blank?

    Integer(value.to_s, exception: false)
  end

  def fetch_rows
    (start_year..end_year).flat_map do |year|
      fetch_year(year)
    end
  end

  def fetch_year(year)
    fetched_at_utc = Time.current.utc.iso8601
    offset = 0
    rows = []

    loop do
      url = build_url(year, offset)
      batch = extract_rows(fetch_json(url))
      break if batch.empty?

      rows.concat(batch.map { |row| normalize_row(row, year, fetched_at_utc, url) })
      break if batch.length < page_size

      offset += page_size
      sleep(delay) if delay.positive?
    end

    merge_fangraphs_values(rows, year)
    if category == "batting"
      merge_baseball_reference_batting_values(rows, year)
      merge_statcast_batting_values(rows, year)
    end
    merge_fangraphs_fielding_values(rows, year)
    merge_mlb_fielding_values(rows, year) if category == "batting"
    merge_statcast_fielding_values(rows, year) if category == "batting"
    if category == "pitching"
      merge_baseball_reference_values(rows, year)
      merge_statcast_values(rows, year)
    end
    merge_mlb_derived_values(rows)
    rows
  end

  def merge_fangraphs_values(rows, year)
    fangraphs_values = fetch_fangraphs_values(year)
    rows.each do |row|
      player_id = row["mlb_id"].to_i
      next unless fangraphs_values.key?(player_id)

      row.merge!(fangraphs_values.fetch(player_id))
    end
  rescue StandardError => e
    Rails.logger.warn("Unable to download FanGraphs values for #{category} #{year}: #{e.class}: #{e.message}")
    rows
  end

  def fetch_fangraphs_values(year)
    uri = URI(service_config.fetch(:fangraphs_url))
    query = {
      pos: "all",
      stats: category == "batting" ? "bat" : "pit",
      lg: "all",
      qual: 0,
      season: year,
      season1: year,
      month: 0,
      ind: 0,
      pageitems: 20_000,
      pagenum: 1
    }.to_query
    uri.query = query

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = service_config.fetch(:timeout_seconds).to_i
    http.read_timeout = service_config.fetch(:timeout_seconds).to_i
    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = service_config.fetch(:user_agent)
    request["Accept"] = "application/json,text/plain,*/*"

    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    payload = JSON.parse(response.body)
    Array(payload["data"]).each_with_object({}) do |row, values|
      mlb_id = Integer(row["xMLBAMID"], exception: false)
      next unless mlb_id

      player_values = { "WAR" => row["WAR"] }.compact
      if category == "batting"
        player_values["wOBA"] = row["wOBA"] if row["wOBA"].present?
        player_values["wRC+"] = row["wRC+"] if row["wRC+"].present?
        player_values["Offense"] = row["Offense"] if row["Offense"].present?
        player_values["BaseRunning"] = row["BaseRunning"] if row["BaseRunning"].present?
        player_values["Defense"] = row["Defense"] if row["Defense"].present?
        player_values["GB%"] = row["GB%"] if row["GB%"].present?
        player_values["FB%"] = row["FB%"] if row["FB%"].present?
        player_values["LD%"] = row["LD%"] if row["LD%"].present?
        player_values["Pull%"] = row["Pull%"] if row["Pull%"].present?
        player_values["Cent%"] = row["Cent%"] if row["Cent%"].present?
        player_values["Oppo%"] = row["Oppo%"] if row["Oppo%"].present?
        player_values["Swing%"] = row["Swing%"] if row["Swing%"].present?
        player_values["O-Swing%"] = row["O-Swing%"] if row["O-Swing%"].present?
        player_values["Contact%"] = row["Contact%"] if row["Contact%"].present?
        player_values["Z-Contact%"] = row["Z-Contact%"] if row["Z-Contact%"].present?
        player_values["SwStr%"] = row["SwStr%"] if row["SwStr%"].present?
        player_values["ballsInPlay"] = row["bipCount"] if row["bipCount"].present?
        ops_plus = calculated_ops_plus(row)
        player_values["OPS+"] = ops_plus if ops_plus
      else
        %w[
          K% BB% K-BB% K/BB BABIP LOB% ERA- FIP FIP- xFIP xFIP- SIERA xERA
          RA9-Wins WPA WPA/LI RE24 Clutch RAR RAA PitchingRuns pLI SD MD
        ].each do |key|
          player_values[key] = row[key] if row[key].present?
        end
      end
      values[mlb_id] = player_values if player_values.any?
    end
  end

  def merge_fangraphs_fielding_values(rows, year)
    fielding_values = fetch_fangraphs_fielding_values(year)
    rows.each do |row|
      player_id = row["mlb_id"].to_i
      next unless fielding_values.key?(player_id)

      row.merge!(fielding_values.fetch(player_id))
    end
  rescue StandardError => e
    Rails.logger.warn("Unable to download FanGraphs DRS values for #{year}: #{e.class}: #{e.message}")
    rows
  end

  def fetch_fangraphs_fielding_values(year)
    uri = URI(service_config.fetch(:fangraphs_url))
    uri.query = {
      pos: "all",
      stats: "fld",
      lg: "all",
      qual: 0,
      season: year,
      season1: year,
      month: 0,
      ind: 0,
      pageitems: 20_000,
      pagenum: 1
    }.to_query

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = service_config.fetch(:timeout_seconds).to_i
    http.read_timeout = service_config.fetch(:timeout_seconds).to_i
    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = service_config.fetch(:user_agent)
    request["Accept"] = "application/json,text/plain,*/*"

    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    rows_by_player = Array(JSON.parse(response.body)["data"]).each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |row, values|
      player_id = Integer(row["xMLBAMID"], exception: false)
      position = (row["Position"].presence || row["Pos"]).to_s.strip
      next if player_id.nil? || position.blank?

      values[player_id] << {
        team_abbreviation: row["TeamNameAbb"].to_s.strip.presence || "TOT",
        position: position,
        games: Integer(row["G"], exception: false),
        innings: Float(row["Inn"], exception: false),
        putouts: Integer(row["PO"], exception: false),
        assists: Integer(row["A"], exception: false),
        fielding_errors: Integer(row["E"], exception: false),
        fielding_percentage: Float(row["FP"], exception: false),
        defensive_runs_saved: Float(row["DRS"], exception: false),
        outs_above_average: Float(row["OAA"], exception: false)
      }
    end

    rows_by_player.transform_values do |position_rows|
      drs_values = position_rows.filter_map { |row| row[:defensive_runs_saved] }
      {
        "DRS" => drs_values.presence&.sum,
        "fieldingByPosition" => position_rows.to_json
      }.compact
    end
  end

  def merge_statcast_values(rows, year)
    statcast_values = fetch_statcast_values(year).merge(fetch_statcast_run_values(year)) do |_player_id, expected_values, run_values|
      expected_values.merge(run_values)
    end
    rows.each do |row|
      player_id = row["mlb_id"].to_i
      next unless statcast_values.key?(player_id)

      merge_missing_values(row, statcast_values.fetch(player_id))
    end
  rescue StandardError => e
    Rails.logger.warn("Unable to download Statcast values for pitching #{year}: #{e.class}: #{e.message}")
    rows
  end

  def merge_statcast_batting_values(rows, year)
    statcast_values = fetch_statcast_batting_values(year)
    rows.each do |row|
      player_id = row["mlb_id"].to_i
      next unless statcast_values.key?(player_id)

      merge_missing_values(row, statcast_values.fetch(player_id))
    end
  rescue StandardError => e
    Rails.logger.warn("Unable to download Statcast batting fallback values for #{year}: #{e.class}: #{e.message}")
    rows
  end

  def merge_statcast_fielding_values(rows, year)
    fielding_values = fetch_statcast_fielding_values(year)
    rows.each do |row|
      player_id = row["mlb_id"].to_i
      next unless fielding_values.key?(player_id)

      row.merge!(fielding_values.fetch(player_id))
    end
  rescue StandardError => e
    Rails.logger.warn("Unable to download Statcast fielding values for #{year}: #{e.class}: #{e.message}")
    rows
  end

  def merge_mlb_fielding_values(rows, year)
    fielding_values = fetch_mlb_fielding_values(year)
    rows.each do |row|
      player_id = row["mlb_id"].to_i
      next unless fielding_values.key?(player_id)

      row.merge!(fielding_values.fetch(player_id))
    end
  rescue StandardError => e
    Rails.logger.warn("Unable to download MLB fielding values for #{year}: #{e.class}: #{e.message}")
    rows
  end

  def fetch_mlb_fielding_values(year)
    offset = 0
    totals_by_player = Hash.new { |hash, player_id| hash[player_id] = { chances: 0, errors: 0 } }
    positions_by_player = Hash.new { |hash, player_id| hash[player_id] = [] }

    loop do
      query = {
        stitch_env: "prod",
        sportId: "1",
        stats: "season",
        group: "fielding",
        playerPool: "ALL",
        gameType: "R",
        limit: page_size.to_s,
        sortStat: "fieldingPercentage",
        order: "desc",
        season: year.to_s,
        offset: offset.to_s
      }.to_query
      batch = extract_rows(fetch_json("#{service_config.fetch(:base_url)}?#{query}"))
      break if batch.empty?

      batch.each do |row|
        player_id = Integer(row["playerId"], exception: false)
        chances = Integer(row["chances"], exception: false)
        errors = Integer(row["errors"], exception: false)
        next unless player_id && chances

        totals_by_player[player_id][:chances] += chances
        totals_by_player[player_id][:errors] += errors || 0
        positions_by_player[player_id] << {
          team_abbreviation: row["teamAbbrev"].to_s.strip.presence || "TOT",
          position: row["positionAbbrev"].to_s.strip,
          games: Integer(row["games"] || row["gamesPlayed"], exception: false),
          innings: Float(row["innings"], exception: false),
          putouts: Integer(row["putOuts"], exception: false),
          assists: Integer(row["assists"], exception: false),
          fielding_errors: errors,
          fielding_percentage: Float(row["fielding"], exception: false),
          defensive_runs_saved: nil,
          outs_above_average: nil
        }
      end
      break if batch.length < page_size

      offset += page_size
    end

    totals_by_player.each_with_object({}) do |(player_id, totals), values|
      next unless totals[:chances].positive?

      values[player_id] = {
        "fieldingPercentage" => (totals[:chances] - totals[:errors]).to_f / totals[:chances],
        "fieldingByPosition" => positions_by_player.fetch(player_id).to_json
      }
    end
  end

  def fetch_statcast_fielding_values(year)
    return {} if year < 2016

    uri = URI("#{service_config.fetch(:baseballsavant_leaderboard_url)}/outs_above_average")
    uri.query = {
      type: "Fielder",
      startYear: year,
      endYear: year,
      split: "no",
      team: "",
      range: "year",
      min: 0,
      pos: "",
      roles: "",
      viz: "hide",
      csv: "true"
    }.to_query

    response = request_csv(uri)
    CSV.parse(utf8_csv_body(response.body), headers: true).each_with_object({}) do |row, values|
      headers = row.headers.compact
      normalized_headers = headers.to_h do |header|
        [header, header.to_s.downcase.gsub(/[^a-z0-9]/, "")]
      end
      player_header = headers.find do |header|
        normalized = normalized_headers.fetch(header)
        normalized.include?("playerid") || %w[mlbamid mlbamplayerid].include?(normalized)
      end
      player_header ||= headers.find { |header| normalized_headers.fetch(header) == "id" }
      oaa_header = headers.find do |header|
        normalized = normalized_headers.fetch(header)
        normalized == "oaa" || normalized.include?("outsaboveaverage")
      end
      player_id = Integer(row[player_header], exception: false) if player_header
      oaa = Float(row[oaa_header], exception: false) if oaa_header
      next unless player_id && oaa

      values[player_id] = { "OAA" => oaa }
    end
  end

  def merge_baseball_reference_batting_values(rows, year)
    year_values = fetch_baseball_reference_batting_values.fetch(year, {})
    rows.each do |row|
      player_id = row["mlb_id"].to_i
      next unless year_values.key?(player_id)

      merge_missing_values(row, year_values.fetch(player_id))
    end
  rescue StandardError => e
    Rails.logger.warn("Unable to download Baseball-Reference WAR values for batting #{year}: #{e.class}: #{e.message}")
    rows
  end

  def fetch_baseball_reference_batting_values
    @fetch_baseball_reference_batting_values ||= begin
      uri = URI(service_config.fetch(:baseball_reference_batting_url))
      response = request_csv(uri)
      values = Hash.new { |hash, year| hash[year] = {} }

      CSV.parse(utf8_csv_body(response.body), headers: true).each do |row|
        year = Integer(row["year_ID"], exception: false)
        player_id = Integer(row["mlb_ID"], exception: false)
        next unless year && player_id && year.between?(start_year, end_year)

        player_values = values[year][player_id] ||= {
          "_ops_plus_total" => 0.0,
          "_ops_plus_pa" => 0.0
        }
        add_value(player_values, "WAR", row["WAR"])
        add_value(player_values, "Offense", row["runs_above_avg_off"])
        add_value(player_values, "BaseRunning", row["runs_br"])
        add_value(player_values, "Defense", row["runs_above_avg_def"])

        plate_appearances = Float(row["PA"], exception: false)
        ops_plus = Float(row["OPS_plus"], exception: false)
        if plate_appearances&.positive? && ops_plus
          player_values["_ops_plus_total"] += ops_plus * plate_appearances
          player_values["_ops_plus_pa"] += plate_appearances
        end
      end
      values.each_value do |players|
        players.each_value do |stats|
          stats["OPS+"] = stats.delete("_ops_plus_total") / stats["_ops_plus_pa"] if stats["_ops_plus_pa"].positive?
          stats.delete("_ops_plus_pa")
        end
      end
      values
    end
  end

  def merge_baseball_reference_values(rows, year)
    year_values = fetch_baseball_reference_values.fetch(year, {})
    rows.each do |row|
      player_id = row["mlb_id"].to_i
      next unless year_values.key?(player_id)

      year_values.fetch(player_id).each do |key, value|
        row[key] = value unless key == "WAR" && row[key].present?
      end
    end
  rescue StandardError => e
    Rails.logger.warn("Unable to download Baseball-Reference values for pitching #{year}: #{e.class}: #{e.message}")
    rows
  end

  def fetch_baseball_reference_values
    @fetch_baseball_reference_values ||= begin
      uri = URI(service_config.fetch(:baseball_reference_url))
      response = request_csv(uri)
      csv_body = utf8_csv_body(response.body)
      values = Hash.new { |hash, year| hash[year] = {} }

      CSV.parse(csv_body, headers: true).each do |row|
        year = Integer(row["year_ID"], exception: false)
        player_id = Integer(row["mlb_ID"], exception: false)
        next unless year && player_id && year.between?(start_year, end_year)

        player_values = values[year][player_id] ||= {}
        raa = Float(row["runs_above_avg"], exception: false)
        war = Float(row["WAR"], exception: false)
        era_plus = Float(row["ERA_plus"], exception: false)
        player_values["RAA"] = player_values.fetch("RAA", 0.0) + raa if raa
        player_values["WAR"] = player_values.fetch("WAR", 0.0) + war if war
        player_values["ERA+"] = era_plus if era_plus
      end
      values
    end
  end

  def fetch_statcast_values(year)
    uri = URI("#{service_config.fetch(:baseballsavant_leaderboard_url)}/custom")
    uri.query = {
      year: year,
      type: "pitcher",
      min: 1,
      selections: "player_id,player_name,k_percent,bb_percent,babip,xera,woba,xwoba",
      csv: "true"
    }.to_query

    response = request_csv(uri)
    csv_body = utf8_csv_body(response.body)
    CSV.parse(csv_body, headers: true).each_with_object({}) do |row, values|
      player_id = Integer(row["player_id"], exception: false)
      next unless player_id

      values[player_id] = {
        "K%" => percentage_fraction(row["k_percent"]),
        "BB%" => percentage_fraction(row["bb_percent"]),
        "BABIP" => Float(row["babip"], exception: false),
        "xERA" => Float(row["xera"], exception: false),
        "wOBAAllowed" => Float(row["woba"], exception: false),
        "xwOBAAllowed" => Float(row["xwoba"], exception: false)
      }.compact
    end
  end

  def fetch_statcast_batting_values(year)
    uri = URI("#{service_config.fetch(:baseballsavant_leaderboard_url)}/custom")
    uri.query = {
      year: year,
      type: "batter",
      min: 1,
      selections: %w[
        player_id player_name woba groundballs_percent flyballs_percent linedrives_percent
        pull_percent straightaway_percent opposite_percent swing_percent oz_swing_percent
        iz_contact_percent whiff_percent batted_ball
      ].join(","),
      csv: "true"
    }.to_query

    response = request_csv(uri)
    CSV.parse(utf8_csv_body(response.body), headers: true).each_with_object({}) do |row, values|
      player_id = Integer(row["player_id"], exception: false)
      next unless player_id

      whiff_rate = percentage_fraction(row["whiff_percent"])
      values[player_id] = {
        "wOBA" => Float(row["woba"], exception: false),
        "GB%" => percentage_fraction(row["groundballs_percent"]),
        "FB%" => percentage_fraction(row["flyballs_percent"]),
        "LD%" => percentage_fraction(row["linedrives_percent"]),
        "Pull%" => percentage_fraction(row["pull_percent"]),
        "Cent%" => percentage_fraction(row["straightaway_percent"]),
        "Oppo%" => percentage_fraction(row["opposite_percent"]),
        "Swing%" => percentage_fraction(row["swing_percent"]),
        "O-Swing%" => percentage_fraction(row["oz_swing_percent"]),
        "Contact%" => whiff_rate.nil? ? nil : 1.0 - whiff_rate,
        "Z-Contact%" => percentage_fraction(row["iz_contact_percent"]),
        "SwStr%" => derived_swinging_strike_rate(row),
        "ballsInPlay" => Integer(row["batted_ball"], exception: false)
      }.compact
    end
  end

  def fetch_statcast_run_values(year)
    uri = URI("#{service_config.fetch(:baseballsavant_leaderboard_url)}/swing-take")
    uri.query = {
      year: year,
      type: "All",
      group: "Pitcher",
      sub_type: "All",
      min: 1,
      csv: "true"
    }.to_query

    response = request_csv(uri)
    CSV.parse(utf8_csv_body(response.body), headers: true).each_with_object({}) do |row, values|
      player_id = Integer(row["player_id"], exception: false)
      next unless player_id

      pitching_runs = Float(row["runs_all"], exception: false)
      values[player_id] = { "PitchingRuns" => pitching_runs } if pitching_runs
    end
  end

  def request_csv(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = service_config.fetch(:timeout_seconds).to_i
    http.read_timeout = service_config.fetch(:timeout_seconds).to_i
    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = service_config.fetch(:baseballsavant_user_agent)
    request["Accept"] = "text/csv,*/*"

    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    response
  end

  def utf8_csv_body(body)
    body.dup.force_encoding(Encoding::UTF_8).delete_prefix("\uFEFF")
  end

  def merge_mlb_derived_values(rows)
    rows.each do |row|
      values = category == "pitching" ? derived_pitching_values(row) : derived_batting_values(row)
      merge_missing_values(row, values)
    end
  end

  def derived_pitching_values(row)
    batters_faced = numeric_value(row["battersFaced"])
    strikeouts = numeric_value(row["strikeOuts"])
    walks = numeric_value(row["baseOnBalls"])
    hits = numeric_value(row["hits"])
    home_runs = numeric_value(row["homeRuns"])
    hit_by_pitch = numeric_value(row["hitByPitch"] || row["hitBatsmen"])
    runs = numeric_value(row["runs"])
    k_rate = numeric_value(row["strikeoutsPerPlateAppearance"]) || safe_ratio(strikeouts, batters_faced)
    bb_rate = numeric_value(row["walksPerPlateAppearance"]) || safe_ratio(walks, batters_faced)
    effective_k_rate = numeric_value(row["K%"] || row["k_percentage"]) || k_rate
    effective_bb_rate = numeric_value(row["BB%"] || row["bb_percentage"]) || bb_rate

    {
      "K%" => k_rate,
      "BB%" => bb_rate,
      "K-BB%" => effective_k_rate && effective_bb_rate ? (effective_k_rate - effective_bb_rate).round(6) : nil,
      "K/BB" => numeric_value(row["strikeoutWalkRatio"]) || safe_ratio(strikeouts, walks),
      "BABIP" => numeric_value(row["babip"]),
      "LOB%" => derived_lob_rate(hits, walks, hit_by_pitch, runs, home_runs)
    }.compact
  end

  def derived_batting_values(row)
    pitches = numeric_value(row["numberOfPitches"])
    swings = numeric_value(row["totalSwings"])
    misses = numeric_value(row["swingAndMisses"])
    balls_in_play = numeric_value(row["ballsInPlay"])
    ground_balls = numeric_value(row["groundHits"]).to_f + numeric_value(row["groundOuts"]).to_f
    fly_balls = numeric_value(row["flyHits"]).to_f + numeric_value(row["flyOuts"]).to_f
    line_drives = numeric_value(row["lineHits"]).to_f + numeric_value(row["lineOuts"]).to_f

    {
      "GB%" => safe_ratio(ground_balls, balls_in_play),
      "FB%" => safe_ratio(fly_balls, balls_in_play),
      "LD%" => safe_ratio(line_drives, balls_in_play),
      "Swing%" => safe_ratio(swings, pitches),
      "Contact%" => swings&.positive? && misses ? 1.0 - (misses / swings) : nil,
      "SwStr%" => safe_ratio(misses, pitches),
      "ballsInPlay" => balls_in_play
    }.compact
  end

  def derived_lob_rate(hits, walks, hit_by_pitch, runs, home_runs)
    return if [ hits, walks, hit_by_pitch, runs, home_runs ].any?(&:nil?)

    denominator = hits + walks + hit_by_pitch - (1.4 * home_runs)
    safe_ratio(hits + walks + hit_by_pitch - runs, denominator)
  end

  def derived_swinging_strike_rate(row)
    swing_rate = percentage_fraction(row["swing_percent"])
    whiff_rate = percentage_fraction(row["whiff_percent"])
    swing_rate * whiff_rate if swing_rate && whiff_rate
  end

  def percentage_fraction(value)
    number = numeric_value(value)
    number && (number / 100.0).round(6)
  end

  def numeric_value(value)
    Float(value, exception: false)
  end

  def safe_ratio(numerator, denominator)
    return if numerator.nil? || denominator.nil? || denominator.zero?

    numerator.to_f / denominator
  end

  def merge_missing_values(row, values)
    values.each { |key, value| row[key] = value if row[key].blank? && value.present? }
  end

  def add_value(values, key, raw_value)
    value = numeric_value(raw_value)
    values[key] = values.fetch(key, 0.0) + value if value
  end

  def calculated_ops_plus(row)
    obp_plus = Float(row["OBP+"], exception: false)
    slg_plus = Float(row["SLG+"], exception: false)
    return if obp_plus.nil? || slg_plus.nil?

    obp_plus + slg_plus - 100
  end

  def build_url(year, offset)
    query = {
      stitch_env: "prod",
      sportId: "1",
      stats: "season",
      group: config.fetch(:group),
      playerPool: "ALL",
      gameType: "R",
      limit: page_size.to_s,
      sortStat: config.fetch(:sort_stat),
      order: config.fetch(:order),
      season: year.to_s,
      offset: offset.to_s
    }.to_query

    "#{service_config.fetch(:base_url)}?#{query}"
  end

  def fetch_json(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = service_config.fetch(:timeout_seconds).to_i
    http.read_timeout = service_config.fetch(:timeout_seconds).to_i

    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = service_config.fetch(:user_agent)
    request["Accept"] = "application/json,text/plain,*/*"
    request["Referer"] = service_config.fetch(:referers).fetch(category.to_sym)

    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def extract_rows(payload)
    rows = payload["stats"] || payload["data"] || payload["splits"] || []
    raise "Expected MLB response rows to be an array" unless rows.is_a?(Array)

    rows
  end

  def normalize_row(row, year, fetched_at_utc, source_url)
    flat = flatten(row)
    flat["season"] ||= year
    flat["source_season"] = year
    flat["fetched_at_utc"] = fetched_at_utc
    flat["source_url"] = source_url
    flat["stat_type"] = config.fetch(:stat_type)
    flat["mlb_id"] = flat["playerId"] || flat["player.id"]
    flat["playerFirstName"] ||= flat["firstName"] || flat["player.firstName"]
    flat["playerLastName"] ||= flat["lastName"] || flat["player.lastName"]
    flat["playerUseName"] ||= flat["useName"] || flat["player.useName"]
    flat["teamId"] ||= flat["team.id"]
    flat["teamAbbrev"] ||= flat["team.abbreviation"]
    flat["teamName"] ||= flat["team.name"]
    flat["teamShortName"] ||= flat["team.shortName"] || flat["team.teamName"]
    flat
  end

  def flatten(value, prefix = nil)
    case value
    when Hash
      value.each_with_object({}) do |(key, nested_value), flattened|
        nested_key = [ prefix, key ].compact.join(".")
        flattened.merge!(flatten(nested_value, nested_key))
      end
    when Array
      { prefix => value.to_json }
    else
      { prefix => value }
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
