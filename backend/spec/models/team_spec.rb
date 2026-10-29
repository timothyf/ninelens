require "rails_helper"

RSpec.describe Team, type: :model do
  it "is valid with all required fields" do
    expect(create_team).to be_valid
  end

  it "requires a unique mlb id" do
    create_team(mlb_id: 116)

    duplicate = described_class.new(
      mlb_id: 116,
      name: "Another Team",
      abbreviation: "AT",
      team_name: "Another",
      location_name: "Elsewhere",
      short_name: "Elsewhere",
      team_code: "another",
      file_code: "another"
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:mlb_id]).to include("has already been taken")
  end

  it "requires core display fields" do
    team = described_class.new(mlb_id: nil)

    expect(team).not_to be_valid
    expect(team.errors[:mlb_id]).to include("can't be blank")
    expect(team.errors[:name]).to include("can't be blank")
    expect(team.errors[:abbreviation]).to include("can't be blank")
    expect(team.errors[:team_name]).to include("can't be blank")
  end

  it "keeps current club identities when an importer saves historical names for the same MLB IDs" do
    historical_names = {
      119 => [ "Brooklyn Dodgers", "BRO", "Los Angeles Dodgers", "LAD" ],
      113 => [ "Cincinnati Redlegs", "CIN", "Cincinnati Reds", "CIN" ],
      114 => [ "Cleveland Indians", "CLE", "Cleveland Guardians", "CLE" ],
      117 => [ "Houston Colt 45's", "HOU", "Houston Astros", "HOU" ],
      144 => [ "Milwaukee Braves", "MIL", "Atlanta Braves", "ATL" ],
      133 => [ "Philadelphia Athletics", "PHA", "Athletics", "ATH" ],
      137 => [ "New York Giants", "NYG", "San Francisco Giants", "SF" ],
      140 => [ "Washington Senators", "WAS", "Texas Rangers", "TEX" ],
      142 => [ "Washington Senators", "WAS", "Minnesota Twins", "MIN" ]
    }

    historical_names.each do |mlb_id, (old_name, old_abbreviation, current_name, current_abbreviation)|
      team = described_class.create!(
        mlb_id: mlb_id,
        name: old_name,
        abbreviation: old_abbreviation,
        team_name: old_name.split.last,
        location_name: old_name.split.first,
        short_name: old_name.split.last,
        team_code: mlb_id.to_s,
        file_code: mlb_id.to_s
      )

      expect(team.reload).to have_attributes(name: current_name, abbreviation: current_abbreviation)
      team.update!(name: old_name, abbreviation: old_abbreviation)
      expect(team.reload).to have_attributes(name: current_name, abbreviation: current_abbreviation)
    end
  end
end
