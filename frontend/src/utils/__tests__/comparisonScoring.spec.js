import { describe, expect, it } from 'vitest'

import {
  percentileScore,
  reliabilityAdjustedScore,
  relativeComparisonScore,
  robustBenchmarkScore,
  commonWeightedOverallScores,
  directionalityForStat,
  weightedOverallScore,
} from '../comparisonScoring'

describe('comparison scoring', () => {
  it('normalizes robust benchmark values and reverses lower-is-better metrics', () => {
    const benchmark = { p05: 0, median: 50, mad: 10, p95: 100 }

    expect(robustBenchmarkScore(50, benchmark, 'higher_better')).toBeCloseTo(50, 5)
    expect(robustBenchmarkScore(50, benchmark, 'lower_better')).toBeCloseTo(50, 5)
    expect(robustBenchmarkScore(100, benchmark, 'higher_better')).toBeGreaterThan(95)
    expect(robustBenchmarkScore(100, benchmark, 'lower_better')).toBeLessThan(5)
  })

  it('shrinks small-sample scores toward 50', () => {
    expect(reliabilityAdjustedScore(90, 10, 'batting')).toBeLessThan(90)
    expect(reliabilityAdjustedScore(90, 10000, 'batting')).toBeGreaterThan(85)
    expect(percentileScore(20, 'lower_better')).toBe(80)
  })

  it('treats tied comparison values as neutral', () => {
    expect(relativeComparisonScore(12, [12, 12])).toBe(50)
    expect(relativeComparisonScore(3, [3, 6], 'lower_better')).toBe(100)
  })

  it('uses canonical directions for batting rate statistics', () => {
    expect(directionalityForStat('k_percentage', 'batting', 'higher_better')).toBe('lower_better')
    expect(directionalityForStat('bb_percentage', 'batting', 'lower_better')).toBe('higher_better')
  })

  it('renormalizes weights when a statistic is unavailable and reports coverage', () => {
    expect(weightedOverallScore([
      { key: 'ops', score: 80 },
      { key: 'war', score: null },
    ], { ops: 50, war: 50 }, { minimumCoverage: 0.51 })).toEqual({ score: null, coverage: 0.5 })

    expect(weightedOverallScore([
      { key: 'ops', score: 80 },
      { key: 'war', score: null },
    ], { ops: 50, war: 25 }, { minimumCoverage: 0.5 })).toEqual({ score: 80, coverage: 2 / 3 })
  })

  it('uses the common statistic set for every player', () => {
    expect(commonWeightedOverallScores([
      [{ key: 'ops', score: 80 }, { key: 'war', score: 90 }],
      [{ key: 'ops', score: 60 }, { key: 'war', score: null }],
    ], { ops: 50, war: 50 })).toEqual({
      scores: [80, 60],
      coverage: 0.5,
      commonKeys: ['ops'],
    })
  })

  it('returns insufficient scores when common coverage is below the threshold', () => {
    expect(commonWeightedOverallScores([
      [{ key: 'ops', score: 80 }],
      [{ key: 'ops', score: null }],
    ], { ops: 50, war: 50 }, { minimumCoverage: 0.75 })).toEqual({
      scores: [null, null],
      coverage: 0,
      commonKeys: [],
    })
  })
})
