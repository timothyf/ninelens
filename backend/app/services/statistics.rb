class Statistics
  EMPTY_DISTRIBUTION = { p05: nil, median: nil, mad: nil, p95: nil }.freeze

  def self.quantile(values, probability)
    sorted = Array(values).compact.sort
    return if sorted.empty?

    probability = Float(probability, exception: false)
    raise ArgumentError, "Probability must be between 0 and 1" unless probability&.between?(0, 1)
    return sorted.first if sorted.one?

    position = probability * (sorted.length - 1)
    lower = position.floor
    upper = position.ceil
    return sorted[lower] if lower == upper

    sorted[lower] + ((sorted[upper] - sorted[lower]) * (position - lower))
  end

  def self.distribution(values)
    sorted = Array(values).compact.sort
    return EMPTY_DISTRIBUTION.dup if sorted.empty?

    median = quantile(sorted, 0.5)
    deviations = sorted.map { |value| (value - median).abs }
    {
      p05: quantile(sorted, 0.05),
      median:,
      mad: quantile(deviations, 0.5),
      p95: quantile(sorted, 0.95)
    }
  end
end
