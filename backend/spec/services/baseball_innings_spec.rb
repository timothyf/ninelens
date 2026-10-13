require "rails_helper"

RSpec.describe BaseballInnings do
  describe ".to_outs" do
    it "converts baseball innings notation at each valid fractional boundary" do
      expect(described_class.to_outs("0.0")).to eq(0)
      expect(described_class.to_outs("0.1")).to eq(1)
      expect(described_class.to_outs("0.2")).to eq(2)
      expect(described_class.to_outs("6.0")).to eq(18)
      expect(described_class.to_outs("6.1")).to eq(19)
      expect(described_class.to_outs("6.2")).to eq(20)
    end

    it "accepts whole innings and decimal values" do
      expect(described_class.to_outs(6)).to eq(18)
      expect(described_class.to_outs(6.1)).to eq(19)
      expect(described_class.to_outs(BigDecimal("6.2"))).to eq(20)
      expect(described_class.to_outs(BigDecimal("6.100"))).to eq(19)
    end

    it "returns nil for blank input" do
      expect(described_class.to_outs(nil)).to be_nil
      expect(described_class.to_outs("")).to be_nil
      expect(described_class.to_outs("  ")).to be_nil
    end

    it "rejects invalid third-out digits instead of clamping or rounding them" do
      [ "0.3", "1.9", BigDecimal("4.3"), "1.12", "invalid" ].each do |value|
        expect { described_class.to_outs(value) }
          .to raise_error(ArgumentError, /Invalid baseball innings value/)
      end
    end
  end

  describe ".format" do
    it "formats out counts using baseball innings notation" do
      expect(described_class.format(0)).to eq("0.0")
      expect(described_class.format(1)).to eq("0.1")
      expect(described_class.format(2)).to eq("0.2")
      expect(described_class.format(3)).to eq("1.0")
      expect(described_class.format(20)).to eq("6.2")
      expect(described_class.format(nil)).to be_nil
    end

    it "rejects negative and fractional out counts" do
      expect { described_class.format(-1) }.to raise_error(ArgumentError, /non-negative integer/)
      expect { described_class.format(1.5) }.to raise_error(ArgumentError, /non-negative integer/)
      expect { described_class.format("invalid") }.to raise_error(ArgumentError, /non-negative integer/)
    end
  end
end
