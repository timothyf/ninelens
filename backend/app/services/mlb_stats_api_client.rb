require "json"
require "net/http"

class MlbStatsApiClient
  class HttpError < StandardError
    attr_reader :status, :url

    def initialize(status:, message:, url:)
      @status = status.to_i
      @url = url
      super("HTTP #{status}: #{message} (#{url})")
    end
  end

  MAX_ATTEMPTS = 3
  RETRYABLE_STATUS_CODES = %w[406 429 500 502 503 504].freeze
  COMPATIBLE_USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36".freeze

  def self.get_json(url, user_agent:)
    upstream_uri = URI(url)
    request_uri = relay_request_uri(upstream_uri) || upstream_uri
    http = Net::HTTP.new(request_uri.host, request_uri.port)
    http.use_ssl = request_uri.scheme == "https"
    http.open_timeout = timeout_seconds
    http.read_timeout = timeout_seconds

    response = nil
    MAX_ATTEMPTS.times do |attempt|
      request = Net::HTTP::Get.new(request_uri.request_uri)
      request["User-Agent"] = attempt.zero? ? user_agent : COMPATIBLE_USER_AGENT
      request["Accept"] = "application/json, text/plain, */*"
      request["Accept-Language"] = "en-US,en;q=0.9"
      request["Accept-Encoding"] = "identity"
      request["Referer"] = "https://www.mlb.com/"
      request["Cache-Control"] = "no-cache"
      request["Connection"] = "close"
      request["X-NineLens-Relay-Token"] = relay_token if relay_enabled?

      response = http.request(request)
      break if response.is_a?(Net::HTTPSuccess)
      break unless RETRYABLE_STATUS_CODES.include?(response.code) && attempt < MAX_ATTEMPTS - 1
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise HttpError.new(status: response.code, message: response.message, url: upstream_uri.to_s)
    end

    JSON.parse(response.body)
  end

  def self.timeout_seconds
    NineLensConfig.fetch(:external_services, :mlb_stats_api, :timeout_seconds).to_i
  end

  def self.relay_request_uri(upstream_uri)
    return unless relay_enabled?
    raise "MLB_STATS_API_RELAY_TOKEN is required when MLB_STATS_API_RELAY_URL is set" if relay_token.empty?

    uri = URI(ENV.fetch("MLB_STATS_API_RELAY_URL"))
    raise "MLB_STATS_API_RELAY_URL must use HTTPS" unless uri.is_a?(URI::HTTPS)

    uri.query = URI.encode_www_form(upstream: upstream_uri.request_uri)
    uri
  end

  def self.relay_enabled?
    ENV["MLB_STATS_API_RELAY_URL"].to_s.strip != ""
  end

  def self.relay_token
    ENV["MLB_STATS_API_RELAY_TOKEN"].to_s
  end

  private_class_method :timeout_seconds, :relay_request_uri, :relay_enabled?, :relay_token
end
