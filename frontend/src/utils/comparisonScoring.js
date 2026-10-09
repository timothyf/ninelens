const DEFAULT_RELIABILITY_K = {
  batting: 200,
  pitching: 150,
}

const CAREER_RELIABILITY_K = {
  batting: 600,
  pitching: 500,
}

const OPPORTUNITY_KEYS = {
  batting: new Set(['plateappearances', 'pa', 'atbats', 'ab']),
  pitching: new Set(['battersfaced', 'bf', 'inningspitched', 'ip']),
}

const BENCHMARK_KEYS = {
  batting: {
    ops: 'ops',
    k_percentage: 'batter_strikeout_percentage',
    bb_percentage: 'batter_walk_percentage',
  },
  pitching: {
    k_percentage: 'pitcher_strikeout_percentage',
    bb_percentage: 'pitcher_walk_percentage',
  },
}

const STAT_DIRECTIONS = {
  batting: {
    k_percentage: 'lower_better',
    bb_percentage: 'higher_better',
  },
  pitching: {
    k_percentage: 'higher_better',
    bb_percentage: 'lower_better',
  },
}

export function normalDistributionCdf(value) {
  // Abramowitz and Stegun approximation, accurate to roughly 7.5e-8.
  const sign = value < 0 ? -1 : 1
  const absolute = Math.abs(value) / Math.sqrt(2)
  const t = 1 / (1 + 0.3275911 * absolute)
  const polynomial = ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t
  const erf = 1 - polynomial * Math.exp(-(absolute * absolute))
  return 0.5 * (1 + sign * erf)
}

export function robustBenchmarkScore(value, benchmark, direction = 'higher_better') {
  const numericValue = Number(value)
  if (!Number.isFinite(numericValue) || !benchmark) return null

  const p05 = Number(benchmark.p05)
  const p95 = Number(benchmark.p95)
  const median = Number(benchmark.median)
  const mad = Number(benchmark.mad)
  if (![p05, p95, median, mad].every(Number.isFinite) || mad <= 0) return null

  const clamped = Math.min(p95, Math.max(p05, numericValue))
  const z = Math.min(3, Math.max(-3, (clamped - median) / (1.4826 * mad)))
  const rawScore = normalDistributionCdf(z) * 100
  return direction === 'lower_better' ? 100 - rawScore : rawScore
}

export function percentileScore(percentile, direction = 'higher_better') {
  const value = Number(percentile)
  if (!Number.isFinite(value)) return null
  return direction === 'lower_better' ? 100 - value : value
}

export function relativeComparisonScore(value, values, direction = 'higher_better') {
  const numericValue = Number(value)
  const numericValues = values.map(Number).filter(Number.isFinite)
  if (!Number.isFinite(numericValue) || numericValues.length < 2) return null

  const minimum = Math.min(...numericValues)
  const maximum = Math.max(...numericValues)
  if (minimum === maximum) return 50

  const normalized = direction === 'lower_better'
    ? (maximum - numericValue) / (maximum - minimum)
    : (numericValue - minimum) / (maximum - minimum)
  return normalized * 100
}

export function reliabilityAdjustedScore(score, opportunity, category, scope = 'season') {
  if (score === null || score === undefined) return null
  const numericOpportunity = Number(opportunity)
  if (!Number.isFinite(numericOpportunity) || numericOpportunity <= 0) return null

  const k = (scope === 'career' ? CAREER_RELIABILITY_K : DEFAULT_RELIABILITY_K)[category] || 200
  const reliability = numericOpportunity / (numericOpportunity + k)
  return reliability * Number(score) + (1 - reliability) * 50
}

export function benchmarkKeyForStat(key, category) {
  return BENCHMARK_KEYS[category]?.[String(key).trim().toLowerCase()] || null
}

export function directionalityForStat(key, category, fallback = 'higher_better') {
  return STAT_DIRECTIONS[category]?.[String(key).trim().toLowerCase()] || fallback
}

export function opportunityForRows(rows, playerIndex, category) {
  const opportunityRow = rows.find((row) => OPPORTUNITY_KEYS[category]?.has(String(row.key).trim().toLowerCase()))
  const value = Number(opportunityRow?.values?.[playerIndex])
  return Number.isFinite(value) && value > 0 ? value : null
}

export function weightedOverallScore(statScores, weights, { minimumCoverage = 0.5 } = {}) {
  let weightedTotal = 0
  let availableWeight = 0
  let requestedWeight = 0

  statScores.forEach(({ key, score }) => {
    const weight = Number(weights[key] || 0)
    if (weight <= 0) return
    requestedWeight += weight
    if (score === null || score === undefined || !Number.isFinite(Number(score))) return
    weightedTotal += Number(score) * weight
    availableWeight += weight
  })

  const coverage = requestedWeight ? availableWeight / requestedWeight : 0
  return {
    score: availableWeight > 0 && coverage >= minimumCoverage ? Math.round(weightedTotal / availableWeight) : null,
    coverage,
  }
}

export function commonWeightedOverallScores(statScoresByPlayer, weights, { minimumCoverage = 0.5 } = {}) {
  if (!Array.isArray(statScoresByPlayer) || statScoresByPlayer.length === 0) {
    return { scores: [], coverage: 0, commonKeys: [] }
  }

  const positiveWeights = Object.fromEntries(
    Object.entries(weights || {}).filter(([, weight]) => Number(weight) > 0),
  )
  const requestedWeight = Object.values(positiveWeights).reduce((total, weight) => total + Number(weight), 0)
  const scoreByPlayer = statScoresByPlayer.map((statScores) => new Map(
    statScores.map(({ key, score }) => [String(key).trim().toLowerCase(), score]),
  ))
  const commonKeys = Object.keys(positiveWeights).filter((key) =>
    scoreByPlayer.every((scores) => {
      const score = scores.get(key)
      return score !== null && score !== undefined && Number.isFinite(Number(score))
    }),
  )
  const commonWeight = commonKeys.reduce((total, key) => total + Number(positiveWeights[key]), 0)
  const coverage = requestedWeight > 0 ? commonWeight / requestedWeight : 0
  const commonKeySet = new Set(commonKeys)
  const scores = coverage >= minimumCoverage
    ? statScoresByPlayer.map((statScores) => weightedOverallScore(
      statScores.filter(({ key }) => commonKeySet.has(String(key).trim().toLowerCase())),
      positiveWeights,
      { minimumCoverage: 1 },
    ).score)
    : statScoresByPlayer.map(() => null)

  return { scores, coverage, commonKeys }
}
