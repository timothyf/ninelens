require "csv"
require "net/http"
require "nokogiri"

class MlbPlayerContractsDownloader
  DEFAULT_PAYROLL_URL = "https://www.fangraphs.com/roster-resource/payroll/%{team}?season=%{season}".freeze
  DEFAULT_TIMEOUT_SECONDS = 120
  DEFAULT_USER_AGENT = "NineLens/1.0 (MLB contract data download)".freeze

  TEAM_SLUGS = %w[
    athletics angels astros blue-jays braves brewers cardinals
    diamondbacks dodgers giants guardians mariners marlins mets
    nationals orioles padres phillies pirates rangers rays red-sox
    reds rockies royals tigers twins white-sox yankees cubs
  ].freeze

  HEADERS = %w[
    source_season team_slug team_abbreviation player_name source_player_url
    source_player_id contract aav salary_by_year source_url fetched_at_utc
  ].freeze

  def self.call(season: Date.current.year, teams: TEAM_SLUGS)
    new(season: season, teams: teams).call
  end

  def initialize(season:, teams: TEAM_SLUGS)
    @season = Integer(season, exception: false)
    @teams = Array(teams).map { |team| team.to_s.strip.downcase }.reject(&:blank?)
  end

  def call
    return failure("Season must be a four-digit year") unless season&.between?(1876, 2100)
    return failure("At least one team is required") if teams.empty?
    invalid_teams = teams - TEAM_SLUGS
    return failure("Unknown team slug(s): #{invalid_teams.join(', ')}") if invalid_teams.any?

    rows = teams.flat_map { |team| fetch_team_rows(team) }
    return failure("No player contract rows returned from FanGraphs RosterResource") if rows.empty?

    success(
      "Downloaded #{rows.length} MLB player contract rows from FanGraphs RosterResource",
      csv_data: CSV.generate { |csv| csv << HEADERS; rows.each { |row| csv << HEADERS.map { |header| row[header] } } },
      row_count: rows.length,
      season: season,
      teams: teams,
      source: "FanGraphs RosterResource",
      source_urls: rows.map { |row| row["source_url"] }.uniq,
      fetched_at_utc: fetched_at_utc
    )
  rescue StandardError => error
    failure("Failed to download MLB player contracts: #{error.message}")
  end

  private

  attr_reader :season, :teams

  def fetch_team_rows(team)
    source_url = payroll_url(team)
    document = Nokogiri::HTML(fetch_html(source_url))
    tables = document.css("table").select { |table| payroll_table?(table) }

    tables.flat_map do |table|
      headers = table.css("thead tr").first&.css("th,td")&.map { |cell| clean(cell.text) }
      headers ||= table.css("tr").first&.css("th,td")&.map { |cell| clean(cell.text) }
      next [] if headers.blank?

      table.css("tbody tr").filter_map do |row|
        cells = row.css("th,td")
        next if cells.empty? || cells.length < headers.length

        values = headers.each_with_index.to_h { |header, index| [header, clean(cells[index]&.text)] }
        player_link = cells.first.at_css("a")
        player_name = clean(player_link&.text || cells.first.text)
        next if player_name.blank? || player_name.casecmp("player").zero?

        salary_by_year = year_headers(headers).each_with_object({}) do |year, salaries|
          value = values[year]
          salaries[year] = value if value.present? && value.casecmp("free agent").nonzero?
        end

        {
          "source_season" => season,
          "team_slug" => team,
          "team_abbreviation" => team_abbreviation(team),
          "player_name" => player_name,
          "source_player_url" => absolute_url(player_link&.[]("href")),
          "source_player_id" => source_player_id(player_link&.[]("href")),
          "contract" => values[header_named(headers, "contract")],
          "aav" => values[header_named(headers, "aav")],
          "salary_by_year" => salary_by_year.to_json,
          "source_url" => source_url,
          "fetched_at_utc" => fetched_at_utc
        }
      end
    end
  end

  def payroll_table?(table)
    text = clean(table.text).downcase
    text.include?("contract") && text.include?("aav") && text.include?(season.to_s)
  end

  def year_headers(headers)
    headers.select { |header| header.match?(/\A#{season}|\A(?:#{season + 1}|#{season + 2}|#{season + 3}|#{season + 4}|#{season + 5}|#{season + 6})\z/) }
  end

  def header_named(headers, name)
    headers.find { |header| header.downcase == name }
  end

  def fetch_html(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = timeout_seconds
    http.read_timeout = timeout_seconds
    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = user_agent
    request["Accept"] = "text/html"
    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    response.body
  end

  def payroll_url(team)
    format(fangraphs_config.fetch(:payroll_url, DEFAULT_PAYROLL_URL), team: team, season: season)
  end

  def timeout_seconds
    fangraphs_config.fetch(:payroll_timeout_seconds, DEFAULT_TIMEOUT_SECONDS).to_i
  end

  def user_agent
    fangraphs_config.fetch(:payroll_user_agent, DEFAULT_USER_AGENT)
  end

  def fangraphs_config
    NineLensConfig.fetch(:external_services, :fangraphs)
  end

  def team_abbreviation(team)
    { "athletics" => "ATH", "angels" => "LAA", "astros" => "HOU", "blue-jays" => "TOR", "braves" => "ATL", "brewers" => "MIL", "cardinals" => "STL", "diamondbacks" => "ARI", "dodgers" => "LAD", "giants" => "SFG", "guardians" => "CLE", "mariners" => "SEA", "marlins" => "MIA", "mets" => "NYM", "nationals" => "WSN", "orioles" => "BAL", "padres" => "SDP", "phillies" => "PHI", "pirates" => "PIT", "rangers" => "TEX", "rays" => "TBR", "red-sox" => "BOS", "reds" => "CIN", "rockies" => "COL", "royals" => "KCR", "tigers" => "DET", "twins" => "MIN", "white-sox" => "CHW", "yankees" => "NYY", "cubs" => "CHC" }.fetch(team)
  end

  def source_player_id(url)
    url.to_s[/\/players\/(?:[^\/]+\/)?(\d+)/, 1]
  end

  def absolute_url(url)
    return if url.blank?

    URI.join("https://www.fangraphs.com", url).to_s
  rescue URI::InvalidURIError
    url
  end

  def clean(value)
    value.to_s.gsub(/[[:space:]]+/, " ").strip
  end

  def fetched_at_utc
    @fetched_at_utc ||= Time.current.utc.iso8601
  end

  def success(message, data)
    { success: true, message: message, data: data }
  end

  def failure(message)
    { success: false, message: message, data: {} }
  end
end
