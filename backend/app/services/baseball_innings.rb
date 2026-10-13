require "bigdecimal"

class BaseballInnings
  INNINGS_PATTERN = /\A(?<whole>\d+)(?:\.(?<partial>[012])0*)?\z/

  def self.to_outs(value)
    normalized = normalize(value)
    return if normalized.empty?

    match = INNINGS_PATTERN.match(normalized)
    raise ArgumentError, "Invalid baseball innings value: #{value.inspect}" unless match

    (match[:whole].to_i * 3) + (match[:partial] || "0").to_i
  end

  def self.format(outs)
    return if outs.nil?

    numeric = BigDecimal(outs.to_s, exception: false)
    if numeric.nil? || numeric.negative? || !numeric.frac.zero?
      raise ArgumentError, "Outs must be a non-negative integer: #{outs.inspect}"
    end

    integer = numeric.to_i
    "#{integer / 3}.#{integer % 3}"
  end

  def self.normalize(value)
    value.is_a?(BigDecimal) ? value.to_s("F") : value.to_s.strip
  end
  private_class_method :normalize
end
