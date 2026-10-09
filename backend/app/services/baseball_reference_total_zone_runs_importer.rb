require "csv"
require "net/http"
require "nokogiri"

class BaseballReferenceTotalZoneRunsImporter
  DEFAULT_URL_TEMPLATE = "https://www.baseball-reference.com/leagues/majors/%{season}-standard-fielding.shtml".freeze
  HEADERS = %w[
    season stat_type playerId playerFirstName playerLastName
    teamAbbrev teamName teamShortName teamId TZR
  ].freeze

  def self.call(start_year:, end_year: start_year, delay: 0.5, url_template: DEFAULT_URL_TEMPLATE)
    new(start_year: start_year, end_year: end_year, delay: delay, url_template: url_template).call
  end

  def initialize(start_year:, end_year:, delay: 0.5, url_template: DEFAULT_URL_TEMPLATE)
    @start_year = Integer(start_year)
    @end_year = Integer(end_year)
    @delay = delay.to_f
    @url_template = url_template
  end

  def call
    return failure("End year must be greater than or equal to start year") if end_year < start_year

    rows = (start_year..end_year).flat_map do |season|
      season_rows = parse_season(season)
      sleep(delay) if delay.positive? && season < end_year
      season_rows
    end
    csv_data = CSV.generate(headers: true) do |csv|
      csv << HEADERS
      rows.each { |row| csv << row }
    end

    {
      success: true,
      message: "Downloaded #{rows.length} Baseball-Reference Total Zone Runs rows",
      data: { csv_data: csv_data, row_count: rows.length, seasons: (start_year..end_year).to_a }
    }
  rescue ArgumentError => e
    failure("Invalid Baseball-Reference Total Zone season range: #{e.message}")
  rescue StandardError => e
    failure("Failed to download Baseball-Reference Total Zone Runs: #{e.message}")
  end

  private

  attr_reader :start_year, :end_year, :delay, :url_template

  def parse_season(season)
    document = Nokogiri::HTML(fetch(season).body)
    table = document.at_css("table#players_standard_fielding")
    raise "Player Standard Fielding table was not found for #{season}" unless table

    table.css("tbody tr").filter_map do |row|
      name_cell = row.at_css('[data-stat="name_display"]')
      tzr_cell = row.at_css('[data-stat="f_tz_runs_total"]')
      next if name_cell.nil? || tzr_cell.nil? || tzr_cell.text.strip.blank?

      baseball_reference_id = name_cell["data-append-csv"].to_s.strip
      player = player_for_baseball_reference_id(baseball_reference_id)
      next unless player

      team_abbreviation = row.at_css('[data-stat="team_name_abbr"]')&.text.to_s.strip.presence || "TOT"
      [
        season,
        "batter",
        player.mlb_id,
        player.first_name,
        player.last_name,
        "TOT",
        "Total",
        "Total",
        0,
        tzr_cell.text.strip
      ]
    end
  end

  def player_for_baseball_reference_id(baseball_reference_id)
    @players_by_baseball_reference_id ||= begin
      mappings = PlayerIdMapping.where.not(baseball_reference_id: nil).pluck(:baseball_reference_id, :mlb_id)
      players_by_mlb_id = Player.where(mlb_id: mappings.map(&:last)).index_by(&:mlb_id)
      mappings.each_with_object({}) do |(reference_id, mlb_id), players|
        players[reference_id] = players_by_mlb_id[mlb_id]
      end
    end
    @players_by_baseball_reference_id[baseball_reference_id]
  end

  def fetch(season)
    uri = URI(format(url_template, season: season))
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 60
    http.read_timeout = 120
    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = "NineLens/1.0 (historical Total Zone import)"
    request["Accept"] = "text/html,*/*"
    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    response
  end

  def failure(message)
    { success: false, message: message, data: { errors: [{ error: message }] } }
  end
end
