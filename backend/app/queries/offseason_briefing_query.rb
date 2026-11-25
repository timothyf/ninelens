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

  def offseason_start
    Date.new(completed_season, 10, 1)
  end

  def recent_moves
    trades = Trade.where(occurred_on: offseason_start..on).order(occurred_on: :desc, id: :desc).limit(ITEM_LIMIT).includes(:trade_participants)
      .map do |trade|
        participant = trade.trade_participants.first
        {
          id: "trade-#{trade.id}", type: "Trade", date: trade.occurred_on,
          player_id: participant&.player_id, player_name: participant&.player_name,
          description: trade.description
        }
      end

    signings = TeamMembership.where(source_name: MlbPlayerTeamHistoryImporter::SOURCE_NAME, starts_on: offseason_start..on)
      .order(starts_on: :desc, id: :desc).limit(50).includes(:player, :team).filter_map do |membership|
        transaction = membership.raw_data.to_h["start_transaction"].to_h
        next unless transaction["typeCode"].to_s.upcase.in?(%w[SFA SGN]) || transaction["typeDesc"].to_s.match?(/signed/i)

        {
          id: "signing-#{membership.id}", type: "Signing", date: membership.starts_on,
          player_id: membership.player_id, player_name: membership.player.full_name,
          description: "#{membership.player.full_name} signed with #{membership.team.name}"
        }
      end

    (trades + signings).sort_by { |move| [ -move[:date].jd, move[:id] ] }.first(ITEM_LIMIT)
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
