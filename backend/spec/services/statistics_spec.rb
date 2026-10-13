require "rails_helper"

RSpec.describe Statistics do
  describe ".quantile" do
    it "sorts values and linearly interpolates between observations" do
      values = [ 4.0, 1.0, 3.0, 2.0 ]

      expect(described_class.quantile(values, 0)).to eq(1.0)
      expect(described_class.quantile(values, 0.25)).to eq(1.75)
      expect(described_class.quantile(values, 0.5)).to eq(2.5)
      expect(described_class.quantile(values, 1)).to eq(4.0)
    end

    it "handles empty and single-value collections" do
      expect(described_class.quantile([], 0.5)).to be_nil
      expect(described_class.quantile([ 7.0 ], 0.95)).to eq(7.0)
    end

    it "rejects probabilities outside the inclusive unit interval" do
      [ nil, -0.1, 1.1, "invalid" ].each do |probability|
        expect { described_class.quantile([ 1, 2 ], probability) }
          .to raise_error(ArgumentError, "Probability must be between 0 and 1")
      end
    end
  end

  describe ".distribution" do
    it "calculates the shared benchmark distribution" do
      distribution = described_class.distribution([ 5.0, 1.0, 4.0, 2.0, 3.0 ])

      expect(distribution).to include(median: 3.0, mad: 1.0)
      expect(distribution.fetch(:p05)).to be_within(0.0001).of(1.2)
      expect(distribution.fetch(:p95)).to be_within(0.0001).of(4.8)
    end

    it "returns an empty distribution when there are no values" do
      expect(described_class.distribution([])).to eq(
        p05: nil,
        median: nil,
        mad: nil,
        p95: nil
      )
    end
  end
end
