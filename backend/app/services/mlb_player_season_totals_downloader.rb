class MlbPlayerSeasonTotalsDownloader
  GROUPS = {
    "batting" => "hitting",
    "pitching" => "pitching"
  }.freeze

  def self.call(mlb_id:, season:, category:)
    new(mlb_id:, season:, category:).call
  end

  def initialize(mlb_id:, season:, category:)
    @mlb_id = mlb_id.to_i
    @season = season.to_i
    @category = category.to_s
  end

  def call
    uri = URI(base_url)
    uri.path = "/api/v1/people/#{mlb_id}/stats"
    uri.query = {
      stats: "season",
      group: GROUPS.fetch(category),
      season: season,
      gameType: "R"
    }.to_query

    MlbStatsApiClient.get_json(uri.to_s, user_agent: user_agent).dig("stats", 0, "splits", 0, "stat") || {}
  end

  private

  attr_reader :mlb_id, :season, :category

  def base_url
    NineLensConfig.fetch(:external_services, :mlb_stats_api, :base_url)
  end

  def user_agent
    NineLensConfig.fetch(:external_services, :mlb_stats_api, :user_agents, :schedule)
  end
end
