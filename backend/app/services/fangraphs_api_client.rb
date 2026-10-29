require "json"
require "net/http"

class FangraphsApiClient
  def self.get_json(url, timeout_seconds:, user_agent:)
    upstream_uri = URI(url)
    request_uri = relay_request_uri(upstream_uri) || upstream_uri
    http = Net::HTTP.new(request_uri.host, request_uri.port)
    http.use_ssl = request_uri.scheme == "https"
    http.open_timeout = timeout_seconds.to_i
    http.read_timeout = timeout_seconds.to_i
    request = Net::HTTP::Get.new(request_uri.request_uri)
    request["User-Agent"] = user_agent
    request["Accept"] = "application/json,text/plain,*/*"
    request["X-NineLens-Relay-Token"] = relay_token if request_uri != upstream_uri

    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def self.relay_request_uri(upstream_uri)
    url = ENV["FANGRAPHS_API_RELAY_URL"].presence || default_relay_url
    return nil if url.blank?
    raise "FANGRAPHS_API_RELAY_TOKEN or MLB_STATS_API_RELAY_TOKEN is required for the FanGraphs relay" if relay_token.blank?

    uri = URI(url)
    raise "FanGraphs API relay URL must use HTTPS" unless uri.is_a?(URI::HTTPS)

    uri.query = URI.encode_www_form(upstream: upstream_uri.request_uri)
    uri
  end

  def self.default_relay_url
    mlb_url = ENV["MLB_STATS_API_RELAY_URL"].to_s.strip
    return if mlb_url.blank?

    uri = URI(mlb_url)
    raise "MLB_STATS_API_RELAY_URL must end in /mlb-relay" unless uri.path.end_with?("/mlb-relay")

    uri.path = uri.path.sub(/\/mlb-relay\z/, "/fangraphs-relay")
    uri.to_s
  end

  def self.relay_token
    ENV["FANGRAPHS_API_RELAY_TOKEN"].presence || ENV["MLB_STATS_API_RELAY_TOKEN"].to_s
  end

  private_class_method :relay_request_uri, :default_relay_url, :relay_token
end
