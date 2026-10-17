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
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = timeout_seconds
    http.read_timeout = timeout_seconds

    response = nil
    MAX_ATTEMPTS.times do |attempt|
      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = attempt.zero? ? user_agent : COMPATIBLE_USER_AGENT
      request["Accept"] = "application/json, text/plain, */*"
      request["Accept-Language"] = "en-US,en;q=0.9"
      request["Accept-Encoding"] = "identity"
      request["Referer"] = "https://www.mlb.com/"
      request["Cache-Control"] = "no-cache"
      request["Connection"] = "close"

      response = http.request(request)
      break if response.is_a?(Net::HTTPSuccess)
      break unless RETRYABLE_STATUS_CODES.include?(response.code) && attempt < MAX_ATTEMPTS - 1
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise HttpError.new(status: response.code, message: response.message, url: uri.to_s)
    end

    JSON.parse(response.body)
  end

  def self.timeout_seconds
    NineLensConfig.fetch(:external_services, :mlb_stats_api, :timeout_seconds).to_i
  end
  private_class_method :timeout_seconds
end
