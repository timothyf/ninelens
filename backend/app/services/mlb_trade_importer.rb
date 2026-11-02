class MlbTradeImporter
  SOURCE_NAME = "MLB Stats API transactions"

  def self.call(payload:, source_url: nil, fetched_at: Time.current)
    new(payload: payload, source_url: source_url, fetched_at: fetched_at).call
  end

  def initialize(payload:, source_url:, fetched_at:)
    @payload = payload
    @source_url = source_url
    @fetched_at = parse_time(fetched_at)
  end

  def call
    errors = input_errors
    return failure("MLB trade import validation failed", errors) if errors.any?

    trade = persist
    success(
      "Imported MLB trade #{trade.mlb_transaction_id} with #{trade.trade_participants.length} participants",
      trade_id: trade.id,
      mlb_transaction_id: trade.mlb_transaction_id,
      participant_count: trade.trade_participants.length
    )
  rescue ActiveRecord::RecordInvalid => error
    failure("MLB trade import validation failed", error.record.errors.full_messages)
  rescue ActiveRecord::ActiveRecordError => error
    failure("Failed to import MLB trade: #{error.message}")
  end

  private

  attr_reader :payload, :source_url, :fetched_at

  def transactions
    return [] unless payload.is_a?(Hash)
    @transactions ||= Array(payload["transactions"]).select do |transaction|
      transaction.is_a?(Hash) && transaction["typeCode"].to_s.upcase == "TR"
    end
  end

  def participant_transactions
    @participant_transactions ||= transactions.select do |transaction|
      player_mlb_id(transaction)&.positive? && transaction.dig("person", "fullName").present?
    end
  end

  def input_errors
    errors = []
    errors << "Payload must be a JSON object" unless payload.is_a?(Hash)
    errors << "Payload must include trade transactions" if transactions.empty?
    errors << "Fetched-at timestamp is required" if fetched_at.nil?

    ids = transactions.filter_map { |transaction| Integer(transaction["id"], exception: false) }.uniq
    errors << "Trade transactions must share one MLB transaction id" unless ids.one?
    errors << "Trade transactions must include a positive MLB transaction id" unless ids.one? && ids.first.positive?
    errors << "Trade transactions must include a date" if trade_date.nil?
    errors << "Trade transactions must include a description" if description.blank?
    errors << "Trade transactions must include at least one player" if participant_transactions.empty?
    errors
  end

  def persist
    Trade.transaction do
      trade = Trade.find_or_initialize_by(mlb_transaction_id: mlb_transaction_id)
      trade.assign_attributes(
        occurred_on: trade_date,
        description: description,
        source_name: SOURCE_NAME,
        source_url: source_url,
        last_synced_at: fetched_at,
        raw_data: payload
      )
      trade.save!

      players_by_mlb_id = Player.where(mlb_id: participant_mlb_ids).index_by(&:mlb_id)
      teams_by_mlb_id = Team.where(mlb_id: team_mlb_ids).index_by(&:mlb_id)

      participant_transactions.each do |transaction|
        participant = trade.trade_participants.find_or_initialize_by(player_mlb_id: player_mlb_id(transaction))
        from_team = transaction["fromTeam"].to_h
        to_team = transaction["toTeam"].to_h
        participant.assign_attributes(
          player: players_by_mlb_id[player_mlb_id(transaction)],
          player_name: transaction.dig("person", "fullName"),
          from_team: teams_by_mlb_id[integer_id(from_team["id"])],
          to_team: teams_by_mlb_id[integer_id(to_team["id"])],
          from_team_mlb_id: integer_id(from_team["id"]),
          from_team_name: from_team["name"],
          to_team_mlb_id: integer_id(to_team["id"]),
          to_team_name: to_team["name"]
        )
        participant.save!
      end

      trade.trade_participants.where.not(player_mlb_id: participant_mlb_ids).delete_all
      trade
    end
  end

  def mlb_transaction_id
    Integer(transactions.first&.fetch("id", nil), exception: false)
  end

  def trade_date
    value = transactions.first&.fetch("date", nil) || transactions.first&.fetch("effectiveDate", nil)
    Date.iso8601(value.to_s) if value.present?
  rescue Date::Error
    nil
  end

  def description
    transactions.filter_map { |transaction| transaction["description"].presence }.first || generated_description
  end

  def generated_description
    movements = participant_transactions.group_by do |transaction|
      [ transaction.dig("fromTeam", "name"), transaction.dig("toTeam", "name") ]
    end.filter_map do |(from_team_name, to_team_name), grouped_transactions|
      next if from_team_name.blank? || to_team_name.blank?

      player_names = grouped_transactions.map { |transaction| transaction.dig("person", "fullName") }
      "#{from_team_name} traded #{player_names.to_sentence} to #{to_team_name}"
    end
    return "#{movements.join('; ')}." if movements.any?

    player_names = participant_transactions.map { |transaction| transaction.dig("person", "fullName") }
    "MLB trade involving #{player_names.to_sentence}."
  end

  def participant_mlb_ids
    @participant_mlb_ids ||= participant_transactions.map { |transaction| player_mlb_id(transaction) }.uniq
  end

  def team_mlb_ids
    transactions.flat_map do |transaction|
      [ transaction.dig("fromTeam", "id"), transaction.dig("toTeam", "id") ]
    end.filter_map { |value| integer_id(value) }.uniq
  end

  def player_mlb_id(transaction)
    integer_id(transaction.dig("person", "id"))
  end

  def integer_id(value)
    Integer(value, exception: false)
  end

  def parse_time(value)
    return value.in_time_zone if value.respond_to?(:in_time_zone)
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def success(message, data = {})
    { success: true, message: message, data: data }
  end

  def failure(message, errors = [])
    { success: false, message: message, data: { errors: errors } }
  end
end
