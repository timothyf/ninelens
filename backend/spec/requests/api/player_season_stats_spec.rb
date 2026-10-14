require "rails_helper"
require "tempfile"

RSpec.describe "Api::PlayerSeasonStats", type: :request do
  include ActiveJob::TestHelper

  def post_as_admin(path, params: {}, as: nil)
    with_admin_api_token("test-admin-token") do
      options = { params: params, headers: admin_headers }
      options[:as] = as if as
      post path, **options
    end
  end

  before do
    @team = create_team(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit",
      team_code: "det",
      file_code: "det"
    )
    @dodgers = create_team(
      mlb_id: 119,
      name: "Los Angeles Dodgers",
      abbreviation: "LAD",
      team_name: "Dodgers",
      location_name: "Los Angeles",
      short_name: "Los Angeles",
      team_code: "lan",
      file_code: "la"
    )
    @player = create_player(team: @team, attributes: { mlb_id: 408234, first_name: "Miguel", last_name: "Cabrera" })
    @shohei = create_player(team: @dodgers, attributes: { mlb_id: 660271, first_name: "Shohei", last_name: "Ohtani" })
    @stat_type = create_stat_type(name: "war", label: "WAR", category: "batting")
    @ops = create_stat_type(name: "ops", label: "OPS", category: "batting")
    @era = create_stat_type(name: "era", label: "ERA", category: "pitching")
    @player_season_stat = create_player_season_stat(
      player: @player,
      stat_type: @stat_type,
      attributes: { season: 2024, value: 3.2 }
    )
    @ops_stat = create_player_season_stat(
      player: @player,
      stat_type: @ops,
      attributes: { season: 2025, value: 0.95 }
    )
    @era_stat = create_player_season_stat(
      player: @shohei,
      stat_type: @era,
      attributes: { season: 2024, value: 2.35 }
    )
  end

  it "lists player season stats with pagination metadata and nested associations" do
    get api_player_season_stats_path,
        params: { page: 1, per_page: 2, sort: "-value", filter: { team_name: "tig", category: "batting" } }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "page")).to eq(1)
    expect(json_body.dig("meta", "per_page")).to eq(2)
    expect(json_body.dig("meta", "total_count")).to eq(2)
    expect(json_body.dig("meta", "total_pages")).to eq(1)
    expect(json_body.dig("meta", "sort")).to eq("-value")
    expect(json_body.dig("meta", "filters")).to eq({ "team_name" => "tig", "category" => "batting" })
    expect(json_body.fetch("data").length).to eq(2)
    expect(json_body.dig("data", 0, "id")).to eq(@player_season_stat.id)
    expect(json_body.dig("data", 0, "player", "full_name")).to eq("Miguel Cabrera")
    expect(json_body.dig("data", 0, "team", "abbreviation")).to eq("DET")
    expect(json_body.dig("data", 0, "stat_type", "label")).to eq("WAR")
    expect(json_body.dig("data", 0, "value")).to eq("3.2")
    expect(json_body.fetch("data").map { |row| row.dig("stat_type", "name") }).to eq(%w[war ops])
  end

  it "filters player season stats by player name, season, and stat type" do
    get api_player_season_stats_path,
        params: { filter: { player_name: "oht", season: 2024, stat_type_name: "era" } }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "total_count")).to eq(1)
    expect(json_body.fetch("data").map { |row| row.dig("player", "last_name") }).to eq(["Ohtani"])
    expect(json_body.dig("data", 0, "stat_type", "category")).to eq("pitching")
  end

  it "filters player season stats by inclusive season range" do
    get api_player_season_stats_path,
        params: { filter: { season_start: 2025, season_end: 2026 } }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "filters")).to include({ "season_start" => 2025, "season_end" => 2026 })
    expect(json_body.fetch("data").map { |row| row.fetch("season") }).to eq([2025])
  end

  it "filters player season stats by scope type and scope key" do
    create_player_season_stat(
      player: @player,
      stat_type: @ops,
      attributes: { season: 2024, team: nil, scope_type: "combined", scope_key: "TOT", value: 0.901 }
    )

    get api_player_season_stats_path,
        params: { filter: { scope_type: "combined", scope_key: "TOT" } }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "filters")).to include({ "scope_type" => "combined", "scope_key" => "TOT" })
    expect(json_body.fetch("data").length).to eq(1)
    expect(json_body.dig("data", 0, "scope_type")).to eq("combined")
    expect(json_body.dig("data", 0, "scope_key")).to eq("TOT")
    expect(json_body.dig("data", 0, "team", "abbreviation")).to eq("TOT")
  end

  it "lists leaderboard rows grouped by player with stats across columns" do
    %w[gamesPlayed atBats runs hits doubles triples homeRuns rbi baseOnBalls strikeOuts stolenBases caughtStealing avg obp slg ops].each do |name|
      create_stat_type(name: name, label: name, category: "batting") unless StatType.exists?(name: name, category: "batting")
    end

    {
      "gamesPlayed" => "150",
      "atBats" => "540",
      "runs" => "88",
      "hits" => "162",
      "doubles" => "30",
      "triples" => "2",
      "homeRuns" => "24",
      "rbi" => "91",
      "baseOnBalls" => "60",
      "strikeOuts" => "102",
      "stolenBases" => "4",
      "caughtStealing" => "1",
      "avg" => ".300",
      "obp" => ".372",
      "slg" => ".515",
      "ops" => ".887"
    }.each do |name, value|
      create_player_season_stat(
        player: @player,
        stat_type: StatType.find_by!(name: name, category: "batting"),
        attributes: { season: 2024, value: value }
      )
    end

    {
      "gamesPlayed" => "155",
      "atBats" => "560",
      "runs" => "102",
      "hits" => "171",
      "doubles" => "28",
      "triples" => "4",
      "homeRuns" => "41",
      "rbi" => "99",
      "baseOnBalls" => "88",
      "strikeOuts" => "118",
      "stolenBases" => "18",
      "caughtStealing" => "3",
      "avg" => ".305",
      "obp" => ".401",
      "slg" => ".612",
      "ops" => "1.013"
    }.each do |name, value|
      create_player_season_stat(
        player: @shohei,
        stat_type: StatType.find_by!(name: name, category: "batting"),
        attributes: { season: 2024, value: value }
      )
    end

    get api_player_season_stats_path,
        params: {
          view: "leaderboard",
          sort: "-homeRuns",
          filter: { category: "batting", season: 2024 }
        }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "category")).to eq("batting")
    expect(json_body.dig("meta", "sort")).to eq("-homeRuns")
    expect(json_body.dig("meta", "total_count")).to eq(2)
    expect(json_body.dig("meta", "data_range")).to eq({ "type" => "season", "start" => 2024, "end" => 2025 })
    expect(json_body.dig("meta", "available_seasons")).to eq([2025, 2024])
    expect(json_body.dig("meta", "available_teams")).to eq(
      [
        {
          "id" => @team.id,
          "mlb_id" => 116,
          "abbreviation" => "DET",
          "name" => "Detroit Tigers",
          "team_name" => "Tigers",
          "location_name" => "Detroit",
          "short_name" => "Detroit"
        },
        {
          "id" => @dodgers.id,
          "mlb_id" => 119,
          "abbreviation" => "LAD",
          "name" => "Los Angeles Dodgers",
          "team_name" => "Dodgers",
          "location_name" => "Los Angeles",
          "short_name" => "Los Angeles"
        }
      ]
    )
    expect(json_body.dig("meta", "columns").map { |column| column.fetch("key") }).to include("homeRuns", "ops")
    expect(json_body.dig("data", 0, "player", "full_name")).to eq("Shohei Ohtani")
    expect(json_body.dig("data", 0, "stats", "homeRuns")).to eq("41.0")
    expect(json_body.dig("data", 0, "stats", "ops")).to eq("1.013")
  end

  it "can defer expensive leaderboard facets until after rows render" do
    get api_player_season_stats_path,
        params: { view: "leaderboard", defer_facets: true, filter: { category: "batting" } }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "facets_complete")).to be(false)
    expect(json_body.fetch("meta")).not_to have_key("total_count")

    get api_player_season_stats_path,
        params: { view: "leaderboard", metadata_only: true, filter: { category: "batting" } }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data")).to eq([])
    expect(json_body.dig("meta", "facets_complete")).to be(true)
    expect(json_body.dig("meta", "total_count")).to be_a(Integer)
  end

  it "filters leaderboard rows by an inclusive season range" do
    get api_player_season_stats_path,
        params: {
          view: "leaderboard",
          sort: "-ops",
          filter: { category: "batting", season_start: 2025, season_end: 2026 }
        }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "filters")).to include({ "season_start" => 2025, "season_end" => 2026, "category" => "batting" })
    expect(json_body.fetch("data").map { |row| row.fetch("season") }).to eq([2025])
  end

  it "filters leaderboard rows by combined scope" do
    create_stat_type(name: "homeRuns", label: "HR", category: "batting") unless StatType.exists?(name: "homeRuns", category: "batting")

    create_player_season_stat(
      player: @player,
      stat_type: StatType.find_by!(name: "homeRuns", category: "batting"),
      attributes: { season: 2024, team: nil, scope_type: "combined", scope_key: "TOT", value: 30 }
    )
    create_player_season_stat(
      player: @player,
      stat_type: @ops,
      attributes: { season: 2024, team: nil, scope_type: "combined", scope_key: "TOT", value: 0.915 }
    )

    get api_player_season_stats_path,
        params: {
          view: "leaderboard",
          filter: { category: "batting", season: 2024, scope_type: "combined", scope_key: "TOT" }
        }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").length).to eq(1)
    expect(json_body.dig("data", 0, "scope", "type")).to eq("combined")
    expect(json_body.dig("data", 0, "scope", "key")).to eq("TOT")
    expect(json_body.dig("data", 0, "team", "abbreviation")).to eq("TOT")
    expect(json_body.dig("meta", "filters")).to include({ "scope_type" => "combined", "scope_key" => "TOT" })
  end

  it "sorts batting leaderboard rows by strikeOuts through the API" do
    %w[gamesPlayed atBats runs hits doubles triples homeRuns rbi baseOnBalls strikeOuts stolenBases caughtStealing avg obp slg ops].each do |name|
      create_stat_type(name: name, label: name, category: "batting") unless StatType.exists?(name: name, category: "batting")
    end

    {
      "gamesPlayed" => "150",
      "atBats" => "540",
      "runs" => "88",
      "hits" => "162",
      "doubles" => "30",
      "triples" => "2",
      "homeRuns" => "24",
      "rbi" => "91",
      "baseOnBalls" => "60",
      "strikeOuts" => "12",
      "stolenBases" => "4",
      "caughtStealing" => "1",
      "avg" => ".300",
      "obp" => ".372",
      "slg" => ".515",
      "ops" => ".887"
    }.each do |name, value|
      create_player_season_stat(
        player: @player,
        stat_type: StatType.find_by!(name: name, category: "batting"),
        attributes: { season: 2024, value: value }
      )
    end

    {
      "gamesPlayed" => "155",
      "atBats" => "560",
      "runs" => "102",
      "hits" => "171",
      "doubles" => "28",
      "triples" => "4",
      "homeRuns" => "41",
      "rbi" => "99",
      "baseOnBalls" => "88",
      "strikeOuts" => "2",
      "stolenBases" => "18",
      "caughtStealing" => "3",
      "avg" => ".305",
      "obp" => ".401",
      "slg" => ".612",
      "ops" => "1.013"
    }.each do |name, value|
      create_player_season_stat(
        player: @shohei,
        stat_type: StatType.find_by!(name: name, category: "batting"),
        attributes: { season: 2024, value: value }
      )
    end

    get api_player_season_stats_path,
        params: {
          view: "leaderboard",
          sort: "-strikeOuts",
          filter: { category: "batting", season: 2024 }
        }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "sort")).to eq("-strikeOuts")
    expect(json_body.fetch("data").map { |row| row.dig("player", "full_name") }).to eq(["Miguel Cabrera", "Shohei Ohtani"])
    expect(json_body.dig("data", 0, "stats", "strikeOuts")).to eq("12.0")
    expect(json_body.dig("data", 1, "stats", "strikeOuts")).to eq("2.0")
  end

  it "shows a player season stat" do
    get api_player_season_stat_path(@player_season_stat), as: :json

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "id")).to eq(@player_season_stat.id)
    expect(json_body.dig("data", "season")).to eq(2024)
    expect(json_body.dig("data", "player", "full_name")).to eq("Miguel Cabrera")
    expect(json_body.dig("data", "stat_type", "label")).to eq("WAR")
  end

  it "uses the season team when serializing a player season stat" do
    historical_team = create_team(
      mlb_id: 117,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit",
      team_code: "det",
      file_code: "det"
    )
    current_team = create_team(
      mlb_id: 136,
      name: "Seattle Mariners",
      abbreviation: "SEA",
      team_name: "Mariners",
      location_name: "Seattle",
      short_name: "Seattle",
      team_code: "sea",
      file_code: "sea"
    )
    batter = create_player(team: current_team, attributes: { mlb_id: 123456, first_name: "Alex", last_name: "Mason" })
    pitcher = create_player(team: current_team, attributes: { mlb_id: 684517, first_name: "Milt", last_name: "Wilcox" })
    batting_stat = create_stat_type(name: "homeRuns", label: "HR", category: "batting")
    pitching_stat = @era

    batting_row = create_player_season_stat(
      player: batter,
      stat_type: batting_stat,
      attributes: { team: historical_team, season: 2024, value: 31 }
    )
    pitching_row = create_player_season_stat(
      player: pitcher,
      stat_type: pitching_stat,
      attributes: { team: historical_team, season: 1976, value: 3.58 }
    )

    get api_player_season_stat_path(batting_row), as: :json

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "team", "abbreviation")).to eq("DET")

    get api_player_season_stat_path(pitching_row), as: :json

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "team", "abbreviation")).to eq("DET")
  end

  it "keeps read requests public when an admin token is configured" do
    with_admin_api_token("test-admin-token") do
      get api_player_season_stat_path(@player_season_stat), as: :json
    end

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "id")).to eq(@player_season_stat.id)
  end

  it "requires administrator authentication for direct stat mutations" do
    expect do
      with_admin_api_token("test-admin-token") do
        post api_player_season_stats_path,
             params: {
               player_season_stat: {
                 player_id: @player.id,
                 stat_type_id: @stat_type.id,
                 season: 2025,
                 value: "4.7"
               }
             },
             as: :json
      end
    end.not_to change(PlayerSeasonStat, :count)

    expect(response).to have_http_status(:unauthorized)
    expect(json_body["message"]).to eq("Authentication is required")
  end

  it "requires administrator authentication for direct stat mutations in production" do
    allow(Rails.env).to receive(:production?).and_return(true)

    post api_player_season_stats_path,
         params: {
           player_season_stat: {
             player_id: @player.id,
             stat_type_id: @stat_type.id,
             season: 2025,
             value: "4.7"
           }
         },
         as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(json_body["message"]).to eq("Authentication is required")
  end

  it "creates a player season stat" do
    expect do
      post_as_admin api_player_season_stats_path,
                    params: {
                      player_season_stat: {
                        player_id: @player.id,
                        stat_type_id: @stat_type.id,
                        season: 2025,
                        value: "4.7"
                      }
                    },
                    as: :json
    end.to change(PlayerSeasonStat, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(json_body.dig("data", "season")).to eq(2025)
    expect(json_body.dig("data", "value")).to eq("4.7")
  end

  it "accepts unsafe requests with a valid bearer admin token" do
    expect do
      with_admin_api_token("test-admin-token") do
        post api_player_season_stats_path,
             params: {
               player_season_stat: {
                 player_id: @player.id,
                 stat_type_id: @stat_type.id,
                 season: 2025,
                 value: "4.7"
               }
             },
             headers: admin_headers,
             as: :json
      end
    end.to change(PlayerSeasonStat, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(json_body.dig("data", "season")).to eq(2025)
  end

  it "returns validation errors for invalid create input" do
    post_as_admin api_player_season_stats_path,
                  params: {
                    player_season_stat: {
                      player_id: @player.id,
                      stat_type_id: @stat_type.id,
                      season: nil,
                      value: nil
                    }
                  },
                  as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("errors")).to include("Season can't be blank", "Value can't be blank")
  end

  it "imports player season stats from an uploaded csv" do
    create_stat_type(name: "gamesPlayed", label: "G", category: "batting")

    csv_file = Tempfile.new(["player-season-stats", ".csv"])
    csv_file.write(<<~CSV)
      source_season,season,stat_type,playerId,playerFirstName,playerLastName,teamAbbrev,teamName,teamShortName,teamId,gamesPlayed
      2024,2024,batter,123456,Barry,Bonds,SFG,San Francisco Giants,Giants,137,99
    CSV
    csv_file.rewind

    uploaded_file = Rack::Test::UploadedFile.new(csv_file.path, "text/csv", original_filename: "player-season-stats.csv")

    expect do
      post_as_admin import_api_player_season_stats_path,
                    params: {
                      file: uploaded_file,
                      required_stat_columns: ["gamesPlayed"]
                    }
    end.to have_enqueued_job(AdminImportJob)

    expect(response).to have_http_status(:accepted)
    run = AdminTaskRun.find(json_body.dig("data", "id"))
    expect(run).to have_attributes(task_name: "player_season_stats_import", status: "queued")
    expect(run.initiated_by).to be_present
    expect(run.admin_task_upload.original_filename).to eq("player-season-stats.csv")

    expect { perform_enqueued_jobs }.to change(PlayerSeasonStat, :count).by(1)

    expect(run.reload).to have_attributes(status: "completed", completed_items: 1)
    expect(run.result_data.dig("data", "imported_count")).to eq(1)
    expect(run.admin_task_upload).to be_nil
    expect(Player.find_by!(mlb_id: 123456).last_name).to eq("Bonds")
  ensure
    csv_file.close!
  end

  it "returns an error when the upload request is missing a csv file" do
    post_as_admin import_api_player_season_stats_path,
                  params: { required_stat_columns: ["gamesPlayed"] }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("errors")).to include("CSV file is required")
  end

  it "returns importer failures from the upload endpoint" do
    csv_file = Tempfile.new(["player-season-stats-invalid", ".csv"])
    csv_file.write(<<~CSV)
      source_season,season,stat_type,playerId,playerFirstName,playerLastName,teamAbbrev,teamName,teamShortName,teamId
      2024,2024,batter,123456,Barry,Bonds,SFG,San Francisco Giants,Giants,137
    CSV
    csv_file.rewind

    uploaded_file = Rack::Test::UploadedFile.new(csv_file.path, "text/csv", original_filename: "invalid-player-season-stats.csv")

    post_as_admin import_api_player_season_stats_path,
                  params: {
                    file: uploaded_file,
                    required_stat_columns: ["gamesPlayed"]
                  }

    expect(response).to have_http_status(:accepted)
    run = AdminTaskRun.find(json_body.dig("data", "id"))
    perform_enqueued_jobs
    expect(run.reload).to have_attributes(status: "failed", failed_items: 1)
    expect(run.error_message).to include("Missing required stat columns: gamesPlayed")
  ensure
    csv_file.close!
  end

  it "downloads MLB stats and imports them through the API" do
    create_stat_type(name: "gamesPlayed", label: "G", category: "batting") unless StatType.exists?(name: "gamesPlayed", category: "batting")
    create_stat_type(name: "homeRuns", label: "HR", category: "batting") unless StatType.exists?(name: "homeRuns", category: "batting")

    csv_data = <<~CSV
      source_season,season,stat_type,playerId,playerFirstName,playerLastName,teamAbbrev,teamName,teamShortName,teamId,gamesPlayed,homeRuns
      2026,2026,batter,123456,Barry,Bonds,SFG,San Francisco Giants,Giants,137,99,73
    CSV

    allow(PlayerStatsDownloader).to receive(:call).and_return(
      {
        success: true,
        message: "Downloaded 1 batting player season rows from MLB",
        data: {
          csv_data: csv_data,
          row_count: 1,
          category: "batting",
          seasons: [2026]
        }
      }
    )

    post_as_admin download_api_player_season_stats_path,
                  params: {
                    category: "batting",
                    start_year: 2026,
                    end_year: 2026,
                    replace_season: "1"
                  },
                  as: :json

    expect(response).to have_http_status(:accepted)
    run = AdminTaskRun.find(json_body.dig("data", "id"))
    expect { perform_enqueued_jobs }.to change(PlayerSeasonStat, :count).by(2)

    expect(PlayerStatsDownloader).to have_received(:call).with(category: "batting", start_year: 2026, end_year: 2026)
    expect(run.reload.status).to eq("completed")
    expect(run.result_data.dig("data", "downloaded_count")).to eq(1)
    expect(run.result_data.dig("data", "downloaded_category")).to eq("batting")
    expect(run.result_data.dig("data", "downloaded_seasons")).to eq([2026])
    expect(Player.find_by!(mlb_id: 123456).last_name).to eq("Bonds")
  end

  it "returns downloader failures from the MLB download endpoint" do
    allow(PlayerStatsDownloader).to receive(:call).and_return(
      { success: false, message: "No batting rows returned from MLB", data: {} }
    )

    post_as_admin download_api_player_season_stats_path,
                  params: { category: "batting", start_year: 2026, end_year: 2026 },
                  as: :json

    expect(response).to have_http_status(:accepted)
    run = AdminTaskRun.find(json_body.dig("data", "id"))
    perform_enqueued_jobs
    expect(run.reload).to have_attributes(status: "failed", error_message: "No batting rows returned from MLB")
  end

  it "updates a player season stat" do
    with_admin_api_token("test-admin-token") do
      patch api_player_season_stat_path(@player_season_stat),
            params: { player_season_stat: { value: "5.1" } },
            headers: admin_headers,
            as: :json
    end

    expect(response).to have_http_status(:ok)
    expect(@player_season_stat.reload.value).to eq(BigDecimal("5.1"))
  end

  it "destroys a player season stat" do
    expect do
      with_admin_api_token("test-admin-token") do
        delete api_player_season_stat_path(@player_season_stat), headers: admin_headers, as: :json
      end
    end.to change(PlayerSeasonStat, :count).by(-1)

    expect(response).to have_http_status(:no_content)
  end
end
