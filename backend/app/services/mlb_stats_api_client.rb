require "json"
require "net/http"

class MlbStatsApiClient
  def self.get_json(url, user_agent:)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = timeout_seconds
    http.read_timeout = timeout_seconds

    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = user_agent
    request["Accept"] = "application/json"

    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def self.timeout_seconds
    NineLensConfig.fetch(:external_services, :mlb_stats_api, :timeout_seconds).to_i
  end
  private_class_method :timeout_seconds
end
