require "set"

class MlbPlayerTeamHistoryImporter
  SOURCE_NAME = "MLB Stats API transactions"
  ROSTER_STATUS = "organization"
  JOIN_TYPE_CODES = %w[ASG CL PUR SE SFA SGN TR].freeze
  JOIN_DESCRIPTIONS = /assigned|claimed|purchased|selected|signed|trade/i
  LEAVE_DESCRIPTIONS = /declared free agency|elected free agency|released|retired/i

  def self.call(player:, payload:, source_url: nil, fetched_at: Time.current, season: nil)
    new(player: player, payload: payload, source_url: source_url, fetched_at: fetched_at, season: season).call
  end

  def initialize(player:, payload:, source_url: nil, fetched_at: Time.current, season: nil)
    @player = player
    @payload = payload
    @source_url = source_url
    @fetched_at = fetched_at.is_a?(Time) ? fetched_at : Time.zone.parse(fetched_at.to_s)
    @season = season
  end

  def call
    return failure("Player is required") unless player.is_a?(Player)
    return failure("MLB transactions payload must include a transactions array") unless payload_transactions.is_a?(Array)
    return failure("Fetched-at timestamp is required") if fetched_at.nil?
    if season && payload_transactions.empty?
      return success("No MLB transactions to update for #{season}", transaction_count: 0, tenure_count: 0, skipped_team_ids: [])
    end

    tenures = build_tenures
    TeamMembership.transaction do
      if season
        player.team_memberships.where(source_name: SOURCE_NAME)
          .where("starts_on <= ? AND (ends_on IS NULL OR ends_on >= ?)", window_end, window_start).delete_all
        tenures.select { |tenure| overlaps_window?(tenure[:starts_on], tenure[:ends_on]) }
          .each { |tenure| create_membership!(tenure) }
      else
        player.team_memberships.where(source_name: SOURCE_NAME).delete_all
        tenures.each { |tenure| create_membership!(tenure) }
      end
      player.refresh_current_team!
    end

    success(
      "Synchronized #{tenures.length} MLB organization tenures",
      transaction_count: payload_transactions.length,
      tenure_count: season ? tenures.count { |tenure| overlaps_window?(tenure[:starts_on], tenure[:ends_on]) } : tenures.length,
      skipped_team_ids: skipped_team_ids.to_a.sort
    )
  rescue ActiveRecord::ActiveRecordError => error
    failure("Failed to import MLB organization history: #{error.message}")
  end

  private

  attr_reader :player, :payload, :source_url, :fetched_at, :season

  def payload_transactions
    payload.is_a?(Hash) ? payload["transactions"] : nil
  end

  def transactions
    @transactions ||= season ? (outside_window_events + payload_transactions).uniq { |transaction| transaction["id"] || transaction } : payload_transactions
  end

  def window_start = Date.new(season, 1, 1)
  def window_end = [ Date.new(season, 12, 31), ApplicationCalendar.current_date ].min

  def overlaps_window?(starts_on, ends_on)
    starts_on <= window_end && (ends_on.nil? || ends_on >= window_start)
  end

  def outside_window_events
    player.team_memberships.where(source_name: SOURCE_NAME).includes(:team).flat_map do |membership|
      [ boundary_event(membership, :start), boundary_event(membership, :end) ].compact
    end
  end

  def boundary_event(membership, boundary)
    date = boundary == :start ? membership.starts_on : membership.ends_on&.+(1.day)
    return if date.nil? || date.between?(window_start, window_end)

    stored = membership.raw_data.to_h[boundary == :start ? "start_transaction" : "end_transaction"]
    return stored if stored.is_a?(Hash) && transaction_date(stored) == date

    {
      "id" => boundary == :start ? -membership.id : -1_000_000_000 - membership.id,
      "_synthetic" => true,
      "date" => date.iso8601,
      "typeCode" => boundary == :start ? "SGN" : "DFA",
      "typeDesc" => boundary == :start ? "Signed" : "Declared Free Agency",
      "toTeam" => { "id" => membership.team.mlb_id, "name" => membership.team.name }
    }
  end

  def build_tenures
    @skipped_team_ids = Set.new
    tenures = []
    current = nil

    sorted_transactions.each do |transaction|
      date = transaction_date(transaction)
      next if date.nil?

      from_team = local_team(transaction["fromTeam"])
      to_team = local_team(transaction["toTeam"])

      if leaving_organization?(transaction)
        if current && [ from_team&.id, to_team&.id ].compact.include?(current[:team].id)
          current[:ends_on] = date - 1.day
          current[:end_transaction] = transaction
          current = nil
        end
        next
      end

      next unless organization_join?(transaction, from_team, to_team)
      next if to_team.nil? || current&.dig(:team)&.id == to_team.id

      if current
        current[:ends_on] = date - 1.day
        current[:end_transaction] = transaction
      end
      current = {
        team: to_team,
        starts_on: date,
        ends_on: nil,
        start_transaction: transaction,
        end_transaction: nil
      }
      tenures << current
    end

    tenures.select { |tenure| tenure[:ends_on].nil? || tenure[:ends_on] >= tenure[:starts_on] }
  end

  def sorted_transactions
    transactions.sort_by do |transaction|
      [ transaction_date(transaction) || Date.new(9999, 12, 31), transaction.fetch("id", 0).to_i  ]
    end
  end

  def transaction_date(transaction)
    Date.iso8601(transaction["date"].presence || transaction["effectiveDate"].to_s)
  rescue Date::Error
    nil
  end

  def organization_join?(transaction, from_team, to_team)
    return true if from_team && to_team && from_team.id != to_team.id

    JOIN_TYPE_CODES.include?(transaction["typeCode"].to_s.upcase) ||
      transaction["typeDesc"].to_s.match?(JOIN_DESCRIPTIONS)
  end

  def leaving_organization?(transaction)
    transaction["typeDesc"].to_s.match?(LEAVE_DESCRIPTIONS) ||
      transaction["description"].to_s.match?(LEAVE_DESCRIPTIONS)
  end

  def local_team(team_payload)
    mlb_id = Integer(team_payload&.fetch("id", nil), exception: false)
    return if mlb_id.nil?

    team = teams_by_mlb_id[mlb_id]
    @skipped_team_ids << mlb_id if team.nil?
    team
  end

  def teams_by_mlb_id
    @teams_by_mlb_id ||= Team.where(mlb_id: transaction_team_ids).index_by(&:mlb_id)
  end

  def transaction_team_ids
    transactions.flat_map do |transaction|
      [ transaction.dig("fromTeam", "id"), transaction.dig("toTeam", "id") ]
    end.filter_map { |value| Integer(value, exception: false) }.uniq
  end

  def skipped_team_ids
    @skipped_team_ids ||= Set.new
  end

  def create_membership!(tenure)
    player.team_memberships.create!(
      team: tenure.fetch(:team),
      starts_on: tenure.fetch(:starts_on),
      ends_on: tenure[:ends_on],
      roster_status: ROSTER_STATUS,
      source_name: SOURCE_NAME,
      source_status_description: "Organization tenure",
      source_url: source_url,
      last_synced_at: fetched_at,
      raw_data: {
        "start_transaction" => persisted_transaction(tenure[:start_transaction]),
        "end_transaction" => persisted_transaction(tenure[:end_transaction])
      }
    )
  end

  def persisted_transaction(transaction)
    transaction unless transaction&.fetch("_synthetic", false)
  end

  def success(message, data = {})
    { success: true, message: message, data: data }
  end

  def failure(message)
    { success: false, message: message, data: {} }
  end
end
