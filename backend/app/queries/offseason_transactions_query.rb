class OffseasonTransactionsQuery
  def initialize(on:)
    @on = on
  end

  def result
    { season: season, as_of: cutoff, transactions: entries }
  end

  def entries
    @entries ||= (trades + signings).sort_by { |move| [ -move[:date].jd, move[:id] ] }
  end

  private

  attr_reader :on

  def season
    @season ||= on.month <= 9 ? on.year - 1 : on.year
  end

  def cutoff
    @cutoff ||= [ on, Date.new(season + 1, 2, -1) ].min
  end

  def offseason_start
    Date.new(season, 10, 1)
  end

  def trades
    Trade.where(occurred_on: offseason_start..cutoff)
      .includes(:trade_participants).map do |trade|
        participant = trade.trade_participants.first
        {
          id: "trade-#{trade.id}", type: "Trade", date: trade.occurred_on,
          player_id: participant&.player_id, player_name: participant&.player_name,
          description: trade.description
        }
      end
  end

  def signings
    TeamMembership.where(source_name: MlbPlayerTeamHistoryImporter::SOURCE_NAME, starts_on: offseason_start..cutoff)
      .includes(:player, :team).filter_map do |membership|
        transaction = membership.raw_data.to_h["start_transaction"].to_h
        next unless transaction["typeCode"].to_s.upcase.in?(%w[SFA SGN]) || transaction["typeDesc"].to_s.match?(/signed/i)

        {
          id: "signing-#{membership.id}", type: "Signing", date: membership.starts_on,
          player_id: membership.player_id, player_name: membership.player.full_name,
          description: "#{membership.player.full_name} signed with #{membership.team.name}"
        }
      end
  end
end
