class MlbSeasonAwardsSync
  RETRY_AFTER_FAILURE = 15.minutes

  def self.call(season:, force: false)
    new(season: season, force: force).call
  end

  def initialize(season:, force: false)
    @season = Integer(season, exception: false)
    @force = ActiveModel::Type::Boolean.new.cast(force)
  end

  def call
    return failure("Season must be a valid year") unless season && season > 1800 && season <= ApplicationCalendar.current_date.year

    state = SeasonAwardSync.create_or_find_by!(season: season)
    state.with_lock do
      next success("Season awards are current", refreshed: false) unless force || refresh_due?(state)

      checked_at = Time.current
      state.update!(last_checked_at: checked_at)
      begin
        rows = SeasonAward::AWARD_IDS.flat_map { |award_id| download_recipients(award_id, checked_at) }
        raise "MLB returned no awards for a season with stored winners" if rows.empty? && SeasonAward.where(season: season).exists?

        SeasonAward.transaction(requires_new: true) do
          SeasonAward.where(season: season).delete_all
          SeasonAward.insert_all!(rows) if rows.any?
          state.update!(last_synced_at: checked_at)
        end
        success("Synchronized #{rows.length} award winners for #{season}", refreshed: true)
      rescue StandardError => error
        failure("Unable to synchronize #{season} award winners: #{error.message}")
      end
    end
  rescue StandardError => error
    failure("Unable to synchronize #{season} award winners: #{error.message}")
  end

  private

  attr_reader :season, :force

  def refresh_due?(state)
    lifetime = season == ApplicationCalendar.current_date.year ? 1.day : 30.days
    return false if state.last_synced_at && state.last_synced_at >= lifetime.ago
    return false if state.last_checked_at && state.last_checked_at >= RETRY_AFTER_FAILURE.ago

    true
  end

  def download_recipients(award_id, checked_at)
    url = "#{NineLensConfig.fetch(:external_services, :mlb_stats_api, :base_url)}/api/v1/awards/#{award_id}/recipients?season=#{season}"
    payload = MlbStatsApiClient.get_json(
      url,
      user_agent: NineLensConfig.fetch(:external_services, :mlb_stats_api, :user_agents, :player_profiles)
    )
    recipients = payload["awards"]
    raise "Invalid MLB response for #{award_id}" unless recipients.is_a?(Array)

    recipients.map do |recipient|
      player = recipient["player"]
      raise "Invalid MLB recipient for #{award_id}" unless recipient["id"] == award_id && recipient["season"].to_i == season && player.is_a?(Hash) && player["id"].to_i.positive? && player["nameFirstLast"].present?

      {
        season: season,
        award_id: award_id,
        award_name: recipient["name"].presence || award_id,
        player_mlb_id: player.fetch("id"),
        player_name: player.fetch("nameFirstLast"),
        team_mlb_id: recipient.dig("team", "id"),
        position: player.dig("primaryPosition", "abbreviation"),
        awarded_on: recipient["date"].presence,
        source_url: url,
        created_at: checked_at,
        updated_at: checked_at
      }
    end
  end

  def success(message, refreshed:)
    { success: true, message: message, data: { season: season, refreshed: refreshed, award_count: SeasonAward.where(season: season).count } }
  end

  def failure(message)
    { success: false, message: message, data: { season: season, award_count: SeasonAward.where(season: season).count } }
  end
end
