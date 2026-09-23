require "csv"
require "json"

class MlbPlayerContractsImporter
  TEAM_ABBREVIATIONS = {
    "athletics" => "ATH", "angels" => "LAA", "astros" => "HOU", "blue-jays" => "TOR",
    "braves" => "ATL", "brewers" => "MIL", "cardinals" => "STL", "diamondbacks" => "ARI",
    "dodgers" => "LAD", "giants" => "SFG", "guardians" => "CLE", "mariners" => "SEA",
    "marlins" => "MIA", "mets" => "NYM", "nationals" => "WSN", "orioles" => "BAL",
    "padres" => "SDP", "phillies" => "PHI", "pirates" => "PIT", "rangers" => "TEX",
    "rays" => "TBR", "red-sox" => "BOS", "reds" => "CIN", "rockies" => "COL",
    "royals" => "KCR", "tigers" => "DET", "twins" => "MIN", "white-sox" => "CHW",
    "yankees" => "NYY", "cubs" => "CHC"
  }.freeze

  def self.call(csv_data:, source_name: "FanGraphs RosterResource")
    new(csv_data:, source_name:).call
  end

  def initialize(csv_data:, source_name:)
    @csv_data = csv_data
    @source_name = source_name
  end

  def call
    rows = CSV.parse(csv_data, headers: true)
    imported_count = 0
    unmatched_count = 0

    rows.each do |row|
      player = player_for(row)
      if player.blank?
        unmatched_count += 1
        next
      end

      salary_by_year = parse_salary_by_year(row["salary_by_year"])
      season = Integer(row["source_season"], exception: false)
      next unless season

      contract = player.player_contracts.find_or_initialize_by(season: season)
      contract.assign_attributes(
        team_slug: row["team_slug"],
        contract: row["contract"],
        aav_amount: parse_money(row["aav"]),
        salary_amount: parse_money(salary_by_year[season.to_s]),
        salary_by_year: salary_by_year,
        source_player_id: row["source_player_id"],
        source_url: row["source_url"],
        fetched_at: parse_timestamp(row["fetched_at_utc"]) || Time.current
      )
      contract.save!
      imported_count += 1
    end

    {
      success: true,
      message: "Imported #{imported_count} player contract records",
      data: { imported_count:, unmatched_count: }
    }
  rescue CSV::MalformedCSVError, JSON::ParserError => error
    { success: false, message: "Failed to parse player contract data: #{error.message}", data: {} }
  rescue ActiveRecord::ActiveRecordError => error
    { success: false, message: "Failed to import player contract data: #{error.message}", data: {} }
  end

  private

  attr_reader :csv_data, :source_name

  def player_for(row)
    mlb_id = PlayerIdMapping.where(fangraphs_id: row["source_player_id"].to_s).pick(:mlb_id)
    player = Player.find_by(mlb_id: mlb_id) if mlb_id
    return player if player

    normalized_name = row["player_name"].to_s.downcase.gsub(/\s+/, " ").strip
    return if normalized_name.blank?

    candidates = Player.joins(:team).where(
      "lower(players.first_name || ' ' || players.last_name) = ?",
      normalized_name
    )
    team_abbreviation = TEAM_ABBREVIATIONS[row["team_slug"].to_s]
    candidates = candidates.where(teams: { abbreviation: team_abbreviation }) if team_abbreviation.present?
    candidates.first || Player.where(
      "lower(first_name || ' ' || last_name) = ?",
      normalized_name
    ).first
  end

  def parse_salary_by_year(value)
    parsed = JSON.parse(value.presence || "{}")
    parsed.is_a?(Hash) ? parsed : {}
  end

  def parse_money(value)
    text = value.to_s.strip
    return if text.blank? || text.match?(/\A(?:free agent|arb|pre-arb)/i)

    multiplier = text.downcase.end_with?("m") ? 1_000_000 : text.downcase.end_with?("k") ? 1_000 : 1
    numeric = text.delete("$,").sub(/[mk]\z/i, "").to_f
    numeric.positive? ? (numeric * multiplier).round : nil
  end

  def parse_timestamp(value)
    Time.iso8601(value.to_s) if value.present?
  rescue ArgumentError
    nil
  end
end
