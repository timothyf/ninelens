class MlbStandingsDownloader
  def self.call(season:)
    new(season:).call
  end

  def initialize(season:)
    @season = season.to_i
  end

  def call
    uri = URI(base_url)
    uri.path = "/api/v1/standings"
    uri.query = {
      leagueId: "103,104",
      season: season,
      standingsTypes: "regularSeason",
      hydrate: "team"
    }.to_query

    payload = MlbStatsApiClient.get_json(uri.to_s, user_agent: user_agent)
    Array(payload["records"]).flat_map { |record| Array(record["teamRecords"]) }.each_with_object({}) do |row, standings|
      team_id = Integer(row.dig("team", "id"), exception: false)
      next unless team_id

      standings[team_id] = {
        "wins" => row["wins"],
        "losses" => row["losses"]
      }
    end
  end

  private

  attr_reader :season

  def base_url
    NineLensConfig.fetch(:external_services, :mlb_stats_api, :base_url)
  end

  def user_agent
    NineLensConfig.fetch(:external_services, :mlb_stats_api, :user_agents, :schedule)
  end
end
