class MlbTeamStatsDownloader
  GROUPS = {
    "batting" => "hitting",
    "pitching" => "pitching"
  }.freeze

  STAT_KEYS = {
    "batting" => %w[
      gamesPlayed atBats runs hits doubles triples homeRuns rbi baseOnBalls strikeOuts
      stolenBases caughtStealing avg obp slg ops
    ],
    "pitching" => %w[
      wins losses era gamesPitched gamesStarted completeGames shutouts saves saveOpportunities
      inningsPitched hits runs earnedRuns homeRuns hitBatsmen baseOnBalls strikeOuts whip avg
    ]
  }.freeze

  def self.call(season:, category:)
    new(season: season, category: category).call
  end

  def initialize(season:, category:)
    @season = season.to_i
    @category = category.to_s
  end

  def call
    uri = URI(base_url)
    uri.path = "/api/v1/teams/stats"
    uri.query = {
      stats: "season",
      group: GROUPS.fetch(category),
      season: season,
      sportId: 1,
      gameType: "R"
    }.to_query

    payload = MlbStatsApiClient.get_json(uri.to_s, user_agent: user_agent)
    splits = payload.dig("stats", 0, "splits") || []

    splits.each_with_object({}) do |split, values|
      team_id = Integer(split.dig("team", "id"), exception: false)
      next unless team_id

      values[team_id] = STAT_KEYS.fetch(category).each_with_object({}) do |source_key, stats|
        value = split.dig("stat", source_key)
        stats[canonical_key(source_key)] = value if value.present?
      end
    end
  end

  private

  attr_reader :season, :category

  def base_url
    NineLensConfig.fetch(:external_services, :mlb_stats_api, :base_url)
  end

  def user_agent
    NineLensConfig.fetch(:external_services, :mlb_stats_api, :user_agents, :schedule)
  end

  def canonical_key(source_key)
    {
      "wins" => "W",
      "losses" => "L",
      "era" => "ERA",
      "gamesPitched" => "G",
      "gamesStarted" => "GS",
      "completeGames" => "CG",
      "shutouts" => "ShO",
      "saves" => "SV",
      "saveOpportunities" => "SVO",
      "earnedRuns" => "ER",
      "hitBatsmen" => "hitByPitch"
    }.fetch(source_key, source_key)
  end

end
