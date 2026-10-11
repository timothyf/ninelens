require "json"

class MlbPlayerProfilesDownloader
  attr_reader :mlb_ids

  def self.call(mlb_ids:)
    new(mlb_ids: mlb_ids).call
  end

  def initialize(mlb_ids:)
    @mlb_ids = Array(mlb_ids).filter_map { |value| Integer(value, exception: false) }.uniq
  end

  def call
    return failure("At least one player MLB id is required") if mlb_ids.empty?
    return failure("Player MLB ids must be positive integers") if mlb_ids.any? { |mlb_id| mlb_id < 1 }
    return failure("A profile request cannot exceed #{max_people_per_request} players") if mlb_ids.length > max_people_per_request

    source_url = build_url
    payload = fetch_json(source_url)
    return failure("MLB people response must be a JSON object") unless payload.is_a?(Hash)
    return failure("MLB people response must include a people array") unless payload["people"].is_a?(Array)

    payload["people"].each do |person|
      next unless person.is_a?(Hash) && person["id"].present?
      next if person["awards"].is_a?(Array) && person["drafts"].is_a?(Array)

      detail = fetch_json(build_person_url(person["id"]))
      detailed_person = detail.is_a?(Hash) ? Array(detail["people"]).first || detail : nil
      next unless detailed_person.is_a?(Hash)

      %w[awards drafts].each do |key|
        person[key] = detailed_person[key] if detailed_person[key].is_a?(Array)
      end
    end

    success(
      "Downloaded #{payload['people'].length} MLB player profiles",
      payload: payload,
      requested_mlb_ids: mlb_ids,
      profile_count: payload["people"].length,
      source_url: source_url,
      fetched_at: Time.current.utc.iso8601
    )
  rescue JSON::ParserError => e
    failure("Failed to parse MLB people response: #{e.message}")
  rescue StandardError => e
    failure("Failed to download MLB player profiles: #{e.message}")
  end

  private

  def build_url
    query = {
      personIds: mlb_ids.join(","),
      hydrate: "currentTeam,awards,draft"
    }.to_query
    "#{service_config.fetch(:base_url)}/api/v1/people?#{query}"
  end

  def build_person_url(mlb_id)
    query = { hydrate: "awards,draft" }.to_query
    "#{service_config.fetch(:base_url)}/api/v1/people/#{mlb_id}?#{query}"
  end

  def fetch_json(url)
    MlbStatsApiClient.get_json(
      url,
      user_agent: service_config.fetch(:user_agents).fetch(:player_profiles)
    )
  end

  def service_config
    @service_config ||= NineLensConfig.fetch(:external_services, :mlb_stats_api)
  end

  def max_people_per_request
    NineLensConfig.fetch(:operations, :player_profiles, :max_people_per_request).to_i
  end

  def success(message, data = {})
    { success: true, message: message, data: data }
  end

  def failure(message)
    { success: false, message: message, data: {} }
  end
end
