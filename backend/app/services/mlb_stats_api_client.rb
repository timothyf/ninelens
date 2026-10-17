require "json"
require "net/http"

class MlbStatsApiClient
  MAX_ATTEMPTS = 3
  RETRYABLE_STATUS_CODES = %w[406 429 500 502 503 504].freeze
  COMPATIBLE_USER_AGENT = "Mozilla/5.0 (compatible; NineLens/1.0; +https://ninelens.com)".freeze

  def self.get_json(url, user_agent:)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = timeout_seconds
    http.read_timeout = timeout_seconds

    response = nil
    MAX_ATTEMPTS.times do |attempt|
      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = attempt.zero? ? user_agent : COMPATIBLE_USER_AGENT
      request["Accept"] = "application/json"
      request["Accept-Language"] = "en-US,en;q=0.9" unless attempt.zero?
      request["Cache-Control"] = "no-cache" unless attempt.zero?

      response = http.request(request)
      break if response.is_a?(Net::HTTPSuccess)
      break unless RETRYABLE_STATUS_CODES.include?(response.code) && attempt < MAX_ATTEMPTS - 1
    end

    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def self.timeout_seconds
    NineLensConfig.fetch(:external_services, :mlb_stats_api, :timeout_seconds).to_i
  end
  private_class_method :timeout_seconds
end
