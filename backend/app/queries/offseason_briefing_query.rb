class OffseasonBriefingQuery
  ITEM_LIMIT = 5

  def initialize(on:)
    @on = on
  end

  def result
    return nil unless offseason?

    {
      season: completed_season,
      recent_moves: recent_moves,
      free_agents: free_agents,
      awards: awards
    }
  end

  private

  attr_reader :on

  def offseason?
    [ 11, 12, 1, 2 ].include?(on.month)
  end

  def completed_season
    on.month <= 2 ? on.year - 1 : on.year
  end

  def recent_moves
    OffseasonTransactionsQuery.new(on: on).entries.first(ITEM_LIMIT)
  end

  def free_agents
    FreeAgentsQuery.new(on: on).entries.first(ITEM_LIMIT)
  end

  def awards
    MlbSeasonAwardsSync.call(season: completed_season) if Schedule.exists?(season: completed_season)
    rows = SeasonAward.where(season: completed_season, award_id: %w[ALMVP NLMVP ALCY NLCY ALROY NLROY])
      .order(:award_id).to_a
    players = Player.where(mlb_id: rows.map(&:player_mlb_id)).pluck(:mlb_id, :id).to_h
    rows.map do |award|
      {
        id: award.id, name: award.award_name, player_id: players[award.player_mlb_id],
        player_name: award.player_name, season: award.season
      }
    end
  end
end
