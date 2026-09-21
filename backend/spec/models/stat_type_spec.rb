require "rails_helper"

RSpec.describe StatType, type: :model do
  after { described_class.invalidate_catalog_cache! }

  it "is valid with a name, label, and category" do
    expect(create_stat_type).to be_valid
  end

  it "allows the same name in different categories" do
    create_stat_type(name: "avg", category: "batting")

    stat_type = described_class.new(name: "avg", label: "AVG", category: "pitching")

    expect(stat_type).to be_valid
  end

  it "requires the name to be unique within a category" do
    create_stat_type(name: "avg", category: "batting")

    duplicate = described_class.new(name: "avg", label: "AVG", category: "batting")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to include("has already been taken")
  end

  it "requires required fields" do
    stat_type = described_class.new

    expect(stat_type).not_to be_valid
    expect(stat_type.errors[:name]).to include("can't be blank")
    expect(stat_type.errors[:label]).to include("can't be blank")
    expect(stat_type.errors[:category]).to include("can't be blank")
  end

  it "loads the catalog once and invalidates it after writes" do
    stat_type = create_stat_type(name: "avg", category: "batting")

    expect(described_class).to receive(:all).once.and_call_original
    expect(described_class.cached_find_by(category: "batting", name: "avg")).to eq(stat_type)
    expect(described_class.cached_find_by(category: "batting", name: "avg")).to eq(stat_type)

    create_stat_type(name: "ops", category: "batting")

    expect(described_class.cached_find_by(category: "batting", name: "ops")).to be_present
  end
end
