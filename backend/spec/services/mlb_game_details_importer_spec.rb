require "rails_helper"

RSpec.describe MlbGameDetailsImporter do
  let(:sync_time) { Time.zone.parse("2026-07-15T12:00:00Z") }
  let(:home_team) { create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET") }
  let(:away_team) { create_team(mlb_id: 114, name: "Cleveland Guardians", abbreviation: "CLE") }
  let(:game) do
    create_game(
      mlb_id: 823_443,
      home_team: home_team,
      away_team: away_team,
      official_date: Date.new(2026, 7, 15),
      status: "live"
    )
  end

  it "idempotently imports player lines, lineups, plate appearances, substitutions, and pitch links" do
    PitchDatum.create!(
      game_pk: game.mlb_id,
      at_bat_number: 1,
      pitch_number: 1,
      pitcher: 669_373,
      batter: 680_776,
      raw_data: { "game_pk" => game.mlb_id }
    )

    first_result = import
    second_result = import(fetched_at: sync_time + 1.hour)

    expect(first_result[:success]).to be(true)
    expect(second_result[:success]).to be(true)
    expect(first_result.dig(:data, :linked_pitch_count)).to eq(1)
    expect(second_result.dig(:data, :linked_pitch_count)).to eq(0)
    expect(GamePlayerBattingLine.count).to eq(2)
    expect(GamePlayerPitchingLine.count).to eq(2)
    expect(LineupEntry.count).to eq(2)
    expect(PlateAppearance.count).to eq(2)
    expect(Player.count).to eq(4)

    greene = Player.find_by!(mlb_id: 680_776)
    batting_line = GamePlayerBattingLine.find_by!(game: game, player: greene)
    expect(batting_line).to have_attributes(
      team: home_team,
      opponent_team: away_team,
      home: true,
      starter: true,
      batting_order: 100,
      hits: 2,
      home_runs: 1,
      runs_batted_in: 3,
      batting_average: BigDecimal("0.287"),
      ops: BigDecimal("0.842")
    )
    pitching_line = GamePlayerPitchingLine.find_by!(game: game, player: Player.find_by!(mlb_id: 669_373))
    expect(pitching_line).to have_attributes(era: BigDecimal("2.01"), whip: BigDecimal("0.99"))
    expect(LineupEntry.find_by!(game: game, player: greene).substitutions).to include(
      hash_including("details" => hash_including("eventType" => "offensive_substitution"))
    )

    plate_appearance = PlateAppearance.find_by!(game: game, at_bat_index: 0)
    expect(plate_appearance).to have_attributes(
      plate_appearance_number: 1,
      batter: greene,
      batting_team: home_team,
      event_type: "home_run",
      complete: true
    )
    expect(PitchDatum.first.reload).to have_attributes(game: game, plate_appearance: plate_appearance)
    expect(game.reload.boxscore_raw_data).to eq(boxscore)
    expect(game.live_feed_raw_data).to eq(live_feed)
    expect(game.details_last_synced_at).to be_within(1.second).of(sync_time + 1.hour)
  end

  it "stores incomplete plate appearances without discarding their partial state" do
    payload = live_feed.deep_dup
    payload["liveData"]["plays"]["allPlays"] = [ payload.dig("liveData", "plays", "allPlays", 0) ]
    payload.dig("liveData", "plays", "allPlays", 0, "about")["isComplete"] = false
    payload.dig("liveData", "plays", "allPlays", 0, "result")["event"] = nil
    payload.dig("liveData", "plays", "allPlays", 0, "result")["eventType"] = nil

    result = import(live_payload: payload)

    expect(result[:success]).to be(true)
    expect(PlateAppearance.first).to have_attributes(complete: false, event: nil, event_type: nil)
  end

  it "safely records empty feeds for postponed games" do
    game.update!(status: "postponed", detailed_status: "Postponed", home_score: 0, away_score: 0)

    result = import(boxscore_payload: {}, live_payload: {})

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :plate_appearance_count)).to eq(0)
    expect(game.reload).to have_attributes(boxscore_raw_data: {}, live_feed_raw_data: {})
  end

  it "refreshes suspended status and scores from the live feed" do
    payload = live_feed.deep_dup
    payload["gameData"] = {
      "status" => { "abstractGameState" => "Live", "detailedState" => "Suspended" },
      "game" => { "gameNumber" => 2, "doubleHeader" => "Y" }
    }
    payload["liveData"]["linescore"] = {
      "teams" => { "home" => { "runs" => 3 }, "away" => { "runs" => 2 } }
    }

    result = import(live_payload: payload)

    expect(result[:success]).to be(true)
    expect(game.reload).to have_attributes(
      status: "suspended",
      detailed_status: "Suspended",
      home_score: 3,
      away_score: 2,
      game_number: 2,
      doubleheader: "Y"
    )
  end

  it "removes stale lines when an authoritative box score has an empty player list" do
    import
    boxscore_payload = boxscore.deep_dup
    boxscore_payload["teams"]["home"]["batters"] = []
    boxscore_payload["teams"]["home"]["players"] = {}
    boxscore_payload["teams"]["home"]["pitchers"] = []
    boxscore_payload["teams"]["home"]["players"] = {}

    result = import(boxscore_payload: boxscore_payload)

    expect(result[:success]).to be(true)
    expect(GamePlayerBattingLine.where(game:, home: true)).to be_empty
    expect(GamePlayerPitchingLine.where(game:, home: true)).to be_empty
  end

  private

  def import(boxscore_payload: boxscore, live_payload: live_feed, fetched_at: sync_time)
    described_class.call(
      game: game,
      boxscore: boxscore_payload,
      live_feed: live_payload,
      boxscore_source_url: "https://statsapi.mlb.com/api/v1/game/823443/boxscore",
      live_feed_source_url: "https://statsapi.mlb.com/api/v1.1/game/823443/feed/live",
      fetched_at: fetched_at
    )
  end

  def boxscore
    @boxscore ||= {
      "teams" => {
        "away" => team_boxscore(
          batter: person_payload(682_177, "Steven Kwan", batting_order: "100", batting: { "plateAppearances" => 4, "atBats" => 4, "hits" => 1 }, season_batting: { "avg" => ".301", "obp" => ".372", "slg" => ".420", "ops" => ".792" }),
          pitcher: person_payload(676_440, "Tanner Bibee", pitching: { "inningsPitched" => "6.1", "battersFaced" => 24, "hits" => 5, "earnedRuns" => 2, "strikeOuts" => 7, "numberOfPitches" => 91, "strikes" => 62 }, season_pitching: { "era" => "3.45", "whip" => "1.23" })
        ),
        "home" => team_boxscore(
          batter: person_payload(680_776, "Riley Greene", batting_order: "100", batting: { "plateAppearances" => 4, "atBats" => 4, "runs" => 1, "hits" => 2, "homeRuns" => 1, "rbi" => 3 }, season_batting: { "avg" => ".287", "obp" => ".361", "slg" => ".481", "ops" => ".842" }),
          pitcher: person_payload(669_373, "Tarik Skubal", pitching: { "inningsPitched" => "7.0", "battersFaced" => 25, "hits" => 4, "earnedRuns" => 1, "strikeOuts" => 9, "numberOfPitches" => 98, "strikes" => 67 }, season_pitching: { "era" => "2.01", "whip" => "0.99" })
        )
      }
    }
  end

  def team_boxscore(batter:, pitcher:)
    {
      "batters" => [ batter.dig("person", "id") ],
      "pitchers" => [ pitcher.dig("person", "id") ],
      "battingOrder" => [ batter.dig("person", "id") ],
      "players" => {
        "ID#{batter.dig('person', 'id')}" => batter,
        "ID#{pitcher.dig('person', 'id')}" => pitcher
      }
    }
  end

  def person_payload(id, name, batting_order: nil, batting: {}, pitching: {}, season_batting: {}, season_pitching: {})
    {
      "person" => { "id" => id, "fullName" => name },
      "battingOrder" => batting_order,
      "position" => { "abbreviation" => pitching.present? ? "P" : "OF" },
      "allPositions" => [ { "abbreviation" => pitching.present? ? "P" : "OF" } ],
      "stats" => { "batting" => batting, "pitching" => pitching },
      "seasonStats" => { "batting" => season_batting, "pitching" => season_pitching }
    }.compact
  end

  def live_feed
    @live_feed ||= {
      "liveData" => {
        "plays" => {
          "allPlays" => [
            play_payload(index: 0, half: "bottom", batter_id: 680_776, batter_name: "Riley Greene", pitcher_id: 676_440, pitcher_name: "Tanner Bibee", event: "Home Run", event_type: "home_run", home_score: 1),
            play_payload(index: 1, half: "top", batter_id: 682_177, batter_name: "Steven Kwan", pitcher_id: 669_373, pitcher_name: "Tarik Skubal", event: "Groundout", event_type: "field_out", away_score: 0)
          ]
        }
      }
    }.tap do |payload|
      payload.dig("liveData", "plays", "allPlays", 0)["playEvents"] = [
        {
          "details" => { "eventType" => "offensive_substitution", "description" => "Offensive Substitution" },
          "player" => { "id" => 680_776 }
        }
      ]
    end
  end

  def play_payload(index:, half:, batter_id:, batter_name:, pitcher_id:, pitcher_name:, event:, event_type:, home_score: 0, away_score: 0)
    {
      "result" => { "event" => event, "eventType" => event_type, "description" => event, "rbi" => 1, "homeScore" => home_score, "awayScore" => away_score },
      "about" => { "atBatIndex" => index, "halfInning" => half, "inning" => 1, "isComplete" => true, "startTime" => "2026-07-15T23:00:00Z", "endTime" => "2026-07-15T23:02:00Z" },
      "count" => { "outs" => 1 },
      "matchup" => {
        "batter" => { "id" => batter_id, "fullName" => batter_name },
        "pitcher" => { "id" => pitcher_id, "fullName" => pitcher_name }
      },
      "playEvents" => []
    }
  end
end
