require "set"

class MlbPlayerTeamHistoriesSync
  def self.call(limit: nil, mlb_ids: nil, season: nil, progress_tracker: nil)
    new(limit: limit, mlb_ids: mlb_ids, season: season, progress_tracker: progress_tracker).call
  end

  def self.selected_player_count(limit: nil, mlb_ids: nil, season: nil)
    new(limit: limit, mlb_ids: mlb_ids, season: season).selected_player_count
  end

  def initialize(limit: nil, mlb_ids: nil, season: nil, progress_tracker: nil)
    @limit = positive_integer(limit)
    @mlb_ids = Array(mlb_ids).flat_map { |value| value.to_s.split(",") }
      .filter_map { |value| Integer(value, exception: false) }.uniq.presence
    @season = parse_season(season)
    @progress_tracker = progress_tracker
    @synchronized_trade_ids = Set.new
  end

  def selected_player_count = player_scope.count

  def call
    summary = {
      selected_player_count: players.length,
      season: season,
      synchronized_player_count: 0,
      transaction_count: 0,
      tenure_count: 0,
      trade_count: 0,
      trade_participant_count: 0,
      failed_player_count: 0,
      failures: []
    }

    progress_tracker&.start!(total: summary[:selected_player_count])
    players.each do |player|
      if progress_tracker&.cancel_requested?
        summary[:cancelled] = true
        break
      end

      progress_tracker&.player_started!(player)
      result = sync_player(player)
      if result[:success]
        summary[:synchronized_player_count] += 1
        summary[:transaction_count] += result.dig(:data, :transaction_count).to_i
        summary[:tenure_count] += result.dig(:data, :tenure_count).to_i
        summary[:trade_count] += result.dig(:data, :trade_count).to_i
        summary[:trade_participant_count] += result.dig(:data, :trade_participant_count).to_i
      else
        summary[:failed_player_count] += 1
        summary[:failures] << { mlb_id: player.mlb_id, name: player.full_name, message: result[:message] }
      end
      progress_tracker&.player_finished!(success: result[:success])
    end

    if summary[:cancelled]
      return { success: true, message: "MLB organization history synchronization cancelled after #{summary[:synchronized_player_count] + summary[:failed_player_count]} players", data: summary }
    end

    {
      success: summary[:failed_player_count].zero?,
      message: "Synchronized MLB organization history for #{summary[:synchronized_player_count]} of #{summary[:selected_player_count]} players",
      data: summary
    }
  end

  private

  attr_reader :limit, :mlb_ids, :season, :progress_tracker

  def players
    @players ||= player_scope.to_a
  end

  def player_scope
    scope = season && mlb_ids.blank? ? season_player_scope : Player.all
    scope = scope.where(mlb_id: mlb_ids) if mlb_ids.present?
    scope = scope.order(:id)
    scope = scope.limit(limit) if limit.present?
    scope
  end

  def season_player_scope
    first_day = Date.new(season, 1, 1)
    last_day = [ Date.new(season, 12, 31), ApplicationCalendar.current_date ].min
    seasonal_stats = PlayerSeasonStat.where(season: season).select(:player_id)
    roster_memberships = TeamMembership.where(source_name: "MLB Stats API")
      .where("starts_on <= ? AND (ends_on IS NULL OR ends_on >= ?)", last_day, first_day)
      .select(:player_id)
    transaction_memberships = TeamMembership.where(source_name: "MLB Stats API transactions")
      .where("starts_on BETWEEN ? AND ? OR ends_on BETWEEN ? AND ?", first_day, last_day, first_day, last_day)
      .select(:player_id)

    Player.where(id: seasonal_stats)
      .or(Player.where(id: roster_memberships))
      .or(Player.where(id: transaction_memberships))
  end

  def sync_player(player)
    download = if season
      MlbPlayerTransactionsDownloader.call(
        player_mlb_id: player.mlb_id,
        start_date: Date.new(season, 1, 1),
        end_date: [ Date.new(season, 12, 31), ApplicationCalendar.current_date ].min
      )
    else
      MlbPlayerTransactionsDownloader.call(player_mlb_id: player.mlb_id)
    end
    return download unless download[:success]

    data = download.fetch(:data)
    payload = data.fetch(:payload)
    if season
      selected_dates = Date.new(season, 1, 1)..[ Date.new(season, 12, 31), ApplicationCalendar.current_date ].min
      payload = payload.merge("transactions" => Array(payload["transactions"]).select do |transaction|
        date = Date.iso8601(transaction["date"].presence || transaction["effectiveDate"].to_s)
        selected_dates.cover?(date)
      rescue Date::Error
        false
      end)
    end
    history = MlbPlayerTeamHistoryImporter.call(
      player: player,
      payload: payload,
      source_url: data.fetch(:source_url),
      fetched_at: data.fetch(:fetched_at),
      season: season
    )
    return history unless history[:success]

    trade_ids = Array(payload["transactions"]).filter_map do |transaction|
      Integer(transaction["id"], exception: false) if transaction["typeCode"].to_s.upcase == "TR"
    end.uniq
    unsynchronized_trade_ids = trade_ids.reject { |trade_id| @synchronized_trade_ids.include?(trade_id) }
    trades = MlbTradesSync.call(mlb_transaction_ids: unsynchronized_trade_ids)
    return trades unless trades[:success]

    @synchronized_trade_ids.merge(unsynchronized_trade_ids)
    history[:data] = history.fetch(:data).merge(
      trade_count: trades.dig(:data, :synchronized_trade_count).to_i,
      trade_participant_count: trades.dig(:data, :participant_count).to_i
    )
    history
  end

  def positive_integer(value)
    parsed = Integer(value, exception: false)
    parsed if parsed&.positive?
  end

  def parse_season(value)
    return if value.blank?

    parsed = Integer(value, exception: false)
    current_year = ApplicationCalendar.current_date.year
    raise ArgumentError, "Season must be between 1900 and #{current_year}" unless parsed&.between?(1900, current_year)

    parsed
  end
end
