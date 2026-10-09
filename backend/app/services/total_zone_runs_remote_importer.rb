require "csv"
require "json"
require "net/http"

class TotalZoneRunsRemoteImporter
  CANONICAL_HEADERS = %w[
    season stat_type playerId playerFirstName playerLastName
    teamAbbrev teamName teamShortName teamId TZR
  ].freeze

  def self.call(url:, source_name: nil, headers: {}, query: {})
    new(url: url, source_name: source_name, headers: headers, query: query).call
  end

  def initialize(url:, source_name: nil, headers: {}, query: {})
    @url = url
    @source_name = source_name.presence || url
    @headers = headers.to_h
    @query = query.to_h
  end

  def call
    response = fetch
    body = response.body.to_s
    csv_data = json_body?(body) ? normalize_json(JSON.parse(body)) : normalize_csv(body)
    return failure("Remote Total Zone response did not contain any rows") if CSV.parse(csv_data, headers: true).empty?

    { success: true, message: "Downloaded Total Zone Runs rows", data: { csv_data: csv_data, row_count: CSV.parse(csv_data, headers: true).length } }
  rescue JSON::ParserError => e
    failure("Failed to parse remote Total Zone JSON: #{e.message}")
  rescue StandardError => e
    failure("Failed to download remote Total Zone Runs: #{e.message}")
  end

  private

  attr_reader :url, :source_name, :headers, :query

  def fetch
    uri = URI(url)
    uri.query = URI.decode_www_form(String(uri.query))
      .to_h
      .merge(query.stringify_keys)
      .to_query
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 60
    http.read_timeout = 120
    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = "NineLens/1.0 (Total Zone Runs import)"
    headers.each { |key, value| request[key.to_s] = value.to_s }
    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    response
  end

  def json_body?(body)
    body.lstrip.start_with?("{", "[")
  end

  def normalize_csv(body)
    source = CSV.parse(body, headers: true)
    CSV.generate(headers: true) do |csv|
      csv << CANONICAL_HEADERS
      source.each { |row| csv << canonical_row(row.to_h) }
    end
  end

  def normalize_json(payload)
    rows = if payload.is_a?(Array)
      payload
    else
      payload["data"] || payload["results"] || payload["rows"] || payload["players"] || []
    end
    rows = rows.values if rows.is_a?(Hash)

    CSV.generate(headers: true) do |csv|
      csv << CANONICAL_HEADERS
      Array(rows).each { |row| csv << canonical_row(row.to_h) }
    end
  end

  def canonical_row(row)
    player_id = value(row, %w[playerId player_id mlb_id mlbID id])
    player = Player.find_by(mlb_id: player_id.to_i) if player_id.present?
    first_name = value(row, %w[playerFirstName firstName first_name]) || player&.first_name
    last_name = value(row, %w[playerLastName lastName last_name]) || player&.last_name
    team_id = value(row, %w[teamId team_id]) || 0
    team_abbreviation = value(row, %w[teamAbbrev team_abbreviation abbreviation]) || "TOT"
    team_name = value(row, %w[teamName team_name]) || "Total"
    team_short_name = value(row, %w[teamShortName team_short_name]) || team_name

    [
      value(row, %w[season year year_ID]),
      value(row, %w[stat_type statType]) || "batter",
      player_id,
      first_name,
      last_name,
      team_abbreviation,
      team_name,
      team_short_name,
      team_id,
      value(row, %w[TZR tzr totalZoneRuns total_zone_runs Rtot Total_Zone_Runs Total Zone Runs])
    ]
  end

  def value(row, aliases)
    aliases.each do |alias_name|
      key = row.keys.find { |candidate| candidate.to_s.casecmp?(alias_name.to_s) }
      return row[key] if key
    end
    nil
  end

  def failure(message)
    { success: false, message: message, data: { errors: [{ error: message }] } }
  end
end
