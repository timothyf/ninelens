class PlayerTrendEventRefresh
  def self.call(players:, as_of: nil, observed_at: Time.current)
    new(players: players, as_of: as_of, observed_at: observed_at).call
  end

  def initialize(players:, as_of: nil, observed_at: Time.current)
    @players = Array(players)
    @as_of = as_of
    @observed_at = observed_at
  end

  def call
    counts = { players: 0, created: 0, updated: 0, resolved: 0 }
    resolved_players.each do |player|
      refresh_player(player, counts)
      counts[:players] += 1
    end
    { success: true, data: counts }
  rescue ActiveRecord::ActiveRecordError => error
    { success: false, message: "Failed to refresh trend events: #{error.message}", data: counts }
  end

  private

  attr_reader :players, :as_of, :observed_at

  def resolved_players
    ids = players.filter_map { |value| value.is_a?(Player) ? value.id : Integer(value, exception: false) }
    Player.where(id: ids).to_a
  end

  def refresh_player(player, counts)
    result = PlayerTrendEventDetector.new(player: player, as_of: as_of).result
    candidates_by_identity = result.candidates.index_by { |candidate| candidate.fetch(:identity_key) }

    player.with_lock do
      candidates_by_identity.each_value do |candidate|
        event = player.trend_events.active.find_by(identity_key: candidate.fetch(:identity_key))
        if event
          event.update!(candidate.except(:onset_date).merge(last_observed_at: observed_at))
          counts[:updated] += 1
        else
          event = player.trend_events.create!(
            candidate.merge(
              status: "active",
              detected_at: observed_at,
              last_observed_at: observed_at
            )
          )
          counts[:created] += 1
        end
        AlertInboxSync.call(event: event)
      end

      player.trend_events.active
        .where(identity_key: result.evaluated_identities - candidates_by_identity.keys)
        .find_each do |event|
          event.resolve!(at: observed_at)
          Alert.where(player_trend_event: event).where.not(status: "resolved").update_all(status: "resolved", resolved_at: observed_at, updated_at: observed_at)
          counts[:resolved] += 1
        end
    end
  end
end
