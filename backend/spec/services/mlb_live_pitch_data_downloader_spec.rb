require "rails_helper"

RSpec.describe MlbLivePitchDataDownloader do
  it "converts pitch events from the live feed into import-ready rows" do
    game = create_game(status: "final", official_date: Date.new(2026, 7, 15), mlb_id: 823_443)
    downloader = described_class.new(game: game)
    allow(downloader).to receive(:fetch_json).and_return(
      {
        "liveData" => {
          "plays" => {
            "allPlays" => [
              {
                "about" => { "atBatIndex" => 4, "inning" => 2, "halfInning" => "top" },
                "result" => { "event" => "Single" },
                "matchup" => {
                  "batter" => { "id" => 8001 },
                  "pitcher" => { "id" => 9001, "fullName" => "Pitcher One" },
                  "batSide" => { "code" => "R" },
                  "pitchHand" => { "code" => "L" }
                },
                "playEvents" => [
                  {
                    "isPitch" => true,
                    "pitchNumber" => 1,
                    "details" => {
                      "type" => { "code" => "FF", "description" => "四-Seam Fastball" },
                      "description" => "Called Strike"
                    },
                    "pitchData" => {
                      "startSpeed" => 95.2,
                      "zone" => 5,
                      "coordinates" => { "pX" => 0.1, "pZ" => 2.4 }
                    },
                    "hitData" => {
                      "launchSpeed" => 101.4,
                      "launchAngle" => 9.0,
                      "launchSpeedAngle" => 6,
                      "totalDistance" => 200.0,
                      "trajectory" => "line_drive",
                      "batSpeed" => 74.2,
                      "coordinates" => { "coordX" => 140.5, "coordY" => 92.4 }
                    },
                    "count" => { "balls" => 0, "strikes" => 1, "outs" => 1 }
                  }
                ]
              }
            ]
          }
        }
      }
    )

    result = downloader.call
    row = result[:rows].first

    expect(result[:success]).to be(true)
    expect(row).to include(
      "game_pk" => "823443",
      "game_year" => 2026,
      "at_bat_number" => 5,
      "pitch_number" => 1,
      "pitcher" => 9001,
      "batter" => 8001,
      "pitch_type" => "FF",
      "release_speed" => 95.2,
      "launch_speed" => 101.4,
      "launch_angle" => 9.0,
      "launch_speed_angle" => 6,
      "hit_distance_sc" => 200.0,
      "bb_type" => "line_drive",
      "events" => "single",
      "hc_x" => 140.5,
      "hc_y" => 92.4,
      "bat_speed" => 74.2
    )
    expect(downloader).to have_received(:fetch_json).with(end_with("/api/v1.1/game/823443/feed/live"))
  end

  it "does not query the live feed for a scheduled game" do
    game = create_game(status: "scheduled")
    downloader = described_class.new(game: game)
    expect(downloader).not_to receive(:fetch_json)

    expect(downloader.call).to include(success: true, rows: [])
  end

  it "downloads pitch events for an in-progress game" do
    game = create_game(status: "live")
    downloader = described_class.new(game: game)
    allow(downloader).to receive(:fetch_json).and_return(
      "liveData" => { "plays" => { "allPlays" => [
        {
          "about" => { "atBatIndex" => 0, "inning" => 1, "halfInning" => "top" },
          "matchup" => { "batter" => { "id" => 8001 }, "pitcher" => { "id" => 9001 } },
          "playEvents" => [ { "isPitch" => true, "pitchNumber" => 1, "details" => { "type" => { "code" => "FF" } } } ]
        }
      ] } }
    )

    expect(downloader.call).to include(success: true, rows: [ hash_including("game_pk" => game.mlb_id.to_s, "pitch_type" => "FF") ])
    expect(downloader).to have_received(:fetch_json).with(end_with("/api/v1.1/game/#{game.mlb_id}/feed/live"))
  end

  it "uses the saved game-details feed when a fresh live request fails" do
    game = create_game(status: "live")
    game.update!(live_feed_raw_data: {
      "gamePk" => game.mlb_id,
      "liveData" => { "plays" => { "allPlays" => [
        {
          "about" => { "atBatIndex" => 0 },
          "matchup" => { "batter" => { "id" => 8001 }, "pitcher" => { "id" => 9001 } },
          "playEvents" => [ { "isPitch" => true, "pitchNumber" => 1 } ]
        }
      ] } }
    })
    downloader = described_class.new(game: game)
    allow(downloader).to receive(:fetch_json).and_raise("HTTP 403: Forbidden")

    result = downloader.call

    expect(result).to include(success: true, rows: [ hash_including("game_pk" => game.mlb_id.to_s) ])
    expect(result[:message]).to include("saved MLB live feed")
  end
end
