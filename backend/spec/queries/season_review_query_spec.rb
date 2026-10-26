require "rails_helper"

RSpec.describe SeasonReviewQuery do
  it "shows only qualified batting average and ERA leaders, including combined team opportunities" do
    home = create_team
    away = create_team
    schedule = create_schedule(season: 2026)
    2.times do |index|
      create_game(schedule: schedule, home_team: home, away_team: away, status: "final",
        official_date: Date.new(2026, 7, index + 1), home_score: 4, away_score: 2)
    end

    average = create_stat_type(category: "batting", name: "avg", label: "AVG")
    appearances = create_stat_type(category: "batting", name: "plateAppearances", label: "PA")
    era = create_stat_type(category: "pitching", name: "ERA", label: "ERA")
    innings = create_stat_type(category: "pitching", name: "inningsPitched", label: "IP")

    qualified_batter = create_player(team: home)
    unqualified_batter = create_player(team: away)
    qualified_pitcher = create_player(team: home)
    unqualified_pitcher = create_player(team: away)

    season_stat(qualified_batter, average, 0.300, scope_type: "combined", team: nil, scope_key: "TOT")
    season_stat(qualified_batter, appearances, 4, team: home)
    season_stat(qualified_batter, appearances, 3, team: away)
    season_stat(unqualified_batter, average, 0.500)
    season_stat(unqualified_batter, appearances, 5)

    season_stat(qualified_pitcher, era, 2.50)
    season_stat(qualified_pitcher, innings, 2.0)
    season_stat(unqualified_pitcher, era, 0.50)
    season_stat(unqualified_pitcher, innings, 1.2)

    leaders = described_class.new(season: 2026).result.fetch(:leaders).index_by { |leader| leader.fetch(:category) }

    expect(leaders.fetch("Batting average")).to include(qualifier: "Min. 6 PA")
    expect(leaders.fetch("Batting average").fetch(:entries).map { |entry| entry.fetch(:player) }).to eq([ qualified_batter.full_name ])
    expect(leaders.fetch("ERA")).to include(qualifier: "Min. 2 IP")
    expect(leaders.fetch("ERA").fetch(:entries).map { |entry| entry.fetch(:player) }).to eq([ qualified_pitcher.full_name ])
  end

  it "counts complete games once per pitcher and includes saves leaders" do
    first_team = create_team
    second_team = create_team
    first_pitcher = create_player(team: first_team)
    second_pitcher = create_player(team: second_team)
    complete_games = create_stat_type(category: "pitching", name: "CG", label: "CG")
    saves = create_stat_type(category: "pitching", name: "SV", label: "SV")

    season_stat(first_pitcher, complete_games, 3, scope_type: "combined", team: nil, scope_key: "TOT")
    season_stat(first_pitcher, complete_games, 1, team: first_team)
    season_stat(first_pitcher, complete_games, 2, team: second_team)
    season_stat(second_pitcher, complete_games, 2)
    season_stat(first_pitcher, saves, 7)
    season_stat(second_pitcher, saves, 3)

    review = described_class.new(season: 2026).result
    saves_leaders = review.fetch(:leaders).find { |leader| leader.fetch(:category) == "Saves" }

    expect(review.fetch(:complete_games)).to eq(5)
    expect(saves_leaders.fetch(:entries).map { |entry| [ entry.fetch(:player), entry.fetch(:value) ] })
      .to eq([ [ first_pitcher.full_name, 7.0 ], [ second_pitcher.full_name, 3.0 ] ])
  end

  it "loads only regular-season pitches from the selected year" do
    [
      [ 900_001, Date.new(2026, 7, 1), "R", 101.2 ],
      [ 900_002, Date.new(2026, 10, 1), "D", 105.0 ],
      [ 900_003, Date.new(2025, 7, 1), "R", 104.0 ]
    ].each do |game_pk, game_date, game_type, speed|
      PitchDatum.create!(game_pk: game_pk, game_date: game_date, game_type: game_type,
        at_bat_number: 1, pitch_number: 1, release_speed: speed, raw_data: { "source" => "spec" })
    end

    pitches = described_class.new(season: 2026).send(:fastest_pitches)

    expect(pitches.map { |pitch| pitch.fetch(:speed) }).to eq([ 101.2 ])
  end

  def season_stat(player, stat_type, value, team: player.team, scope_type: "team", scope_key: nil)
    create_player_season_stat(player: player, stat_type: stat_type, attributes: {
      season: 2026, value: value, team: team, scope_type: scope_type,
      scope_key: scope_key || team.abbreviation
    })
  end
end
