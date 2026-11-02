class MlbRosterSnapshotSync
  SOURCE_NAME = "MLB Stats API"
  ROSTER_TYPES = RosterSnapshot::ROSTER_TYPES

  def self.call(team_mlb_id:, snapshot_on:)
    new(team_mlb_id: team_mlb_id, snapshot_on: snapshot_on).call
  end

  def initialize(team_mlb_id:, snapshot_on:)
    @team_mlb_id = Integer(team_mlb_id, exception: false)
    @snapshot_on = parse_date(snapshot_on)
  end

  def call
    return failure("Team MLB id must be a positive integer") if team_mlb_id.nil? || team_mlb_id < 1
    return failure("Snapshot date must be a valid ISO date") if snapshot_on.nil?
    return failure("Snapshot date cannot be in the future") if snapshot_on > Date.current

    team = Team.find_by(mlb_id: team_mlb_id)
    return failure("Team with MLB id #{team_mlb_id} does not exist") if team.nil?

    downloads = download_rosters
    failed_download = downloads.values.find { |result| !result[:success] }
    return failure(failed_download[:message]) if failed_download

    snapshots = persist_snapshots(team, downloads)
    counts = snapshots.to_h { |snapshot| [ snapshot.roster_type, snapshot.roster_snapshot_players.size ] }

    success(
      "Stored Active and 40-man roster snapshots for #{team.name} on #{snapshot_on.iso8601}",
      team_id: team.id,
      team_mlb_id: team.mlb_id,
      snapshot_on: snapshot_on.iso8601,
      snapshot_ids: snapshots.to_h { |snapshot| [ snapshot.roster_type, snapshot.id ] },
      player_counts: counts
    )
  rescue ActiveRecord::ActiveRecordError => error
    failure("Failed to store MLB roster snapshots: #{error.message}")
  end

  private

  attr_reader :snapshot_on, :team_mlb_id

  def download_rosters
    ROSTER_TYPES.index_with do |roster_type|
      MlbRosterDownloader.call(
        team_mlb_id: team_mlb_id,
        season: snapshot_on.year,
        roster_type: roster_type,
        as_of: snapshot_on
      )
    end
  end

  def persist_snapshots(team, downloads)
    RosterSnapshot.transaction do
      downloads.map do |roster_type, result|
        data = result.fetch(:data)
        snapshot = team.roster_snapshots.find_or_initialize_by(
          roster_type: roster_type,
          snapshot_on: snapshot_on
        )
        snapshot.assign_attributes(
          season: snapshot_on.year,
          source_name: SOURCE_NAME,
          source_url: data[:source_url],
          last_synced_at: parse_time(data[:fetched_at]),
          raw_data: data.fetch(:payload)
        )
        snapshot.save!
        replace_players(snapshot, data.fetch(:payload))
        snapshot
      end
    end
  end

  def replace_players(snapshot, payload)
    entries = Array(payload["roster"]).each_with_object({}) do |entry, indexed_entries|
      mlb_id = entry.dig("person", "id")
      indexed_entries[mlb_id] = entry if mlb_id.present?
    end
    existing_players = Player.where(mlb_id: entries.keys).index_by(&:mlb_id)

    snapshot.roster_snapshot_players.delete_all
    entries.each_value do |entry|
      person = entry.fetch("person")
      position = entry["position"] || person["primaryPosition"] || {}
      status = entry["status"] || {}
      mlb_id = person.fetch("id")

      snapshot.roster_snapshot_players.create!(
        player: existing_players[mlb_id],
        mlb_id: mlb_id,
        full_name: person["fullName"].presence || fallback_name(person, mlb_id),
        first_name: person["firstName"],
        last_name: person["lastName"],
        jersey_number: entry["jerseyNumber"].presence || person["primaryNumber"],
        position_code: position["abbreviation"].presence || position["code"],
        position_name: position["name"],
        status_code: status["code"],
        status_description: status["description"]
      )
    end
  end

  def fallback_name(person, mlb_id)
    [ person["firstName"], person["lastName"] ].compact.join(" ").presence || "MLB Player #{mlb_id}"
  end

  def parse_date(value)
    return value if value.is_a?(Date)

    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end

  def parse_time(value)
    return value if value.respond_to?(:in_time_zone)

    Time.zone.parse(value.to_s)
  end

  def success(message, data)
    { success: true, message: message, data: data }
  end

  def failure(message)
    { success: false, message: message, data: { errors: [ message ] } }
  end
end
