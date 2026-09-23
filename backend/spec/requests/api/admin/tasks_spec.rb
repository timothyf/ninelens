require "rails_helper"

RSpec.describe "Api::Admin::Tasks", type: :request do
  include ActiveJob::TestHelper
  around { |example| with_admin_api_token("test-admin-token", &example) }
  it "lists the admin tasks exposed through the API" do
    early_schedule = create_schedule(start_date: Date.new(2026, 3, 26), end_date: Date.new(2026, 4, 7))
    late_schedule = create_schedule(start_date: Date.new(2026, 5, 2), end_date: Date.new(2026, 5, 31))
    create_game(schedule: early_schedule, official_date: Date.new(2026, 3, 26))
    create_game(schedule: late_schedule, official_date: Date.new(2026, 9, 22))
    tigers = create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET")
    player = create_player(team: tigers)
    create_team_membership(
      player: player,
      team: tigers,
      starts_on: Date.new(2024, 12, 31),
      ends_on: Date.new(2025, 12, 30)
    )
    create_team_membership(player: player, team: tigers, starts_on: Date.new(2025, 12, 31))
    stat_type = create_stat_type
    create_player_season_stat(player: player, stat_type: stat_type, attributes: { season: 1901 })
    create_player_season_stat(player: player, stat_type: stat_type, attributes: { season: 2026 })
    PitchDatum.create!(game_pk: 700_001, at_bat_number: 1, pitch_number: 1, game_date: Date.new(2026, 4, 1), raw_data: { "pitch" => 1 })
    PitchDatum.create!(game_pk: 700_002, at_bat_number: 1, pitch_number: 1, game_date: Date.new(2026, 5, 31), raw_data: { "pitch" => 2 })

    get api_admin_tasks_path, headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").pluck("id")).to contain_exactly(
      "mlb_schedule_sync",
      "mlb_game_details_sync",
      "mlb_player_profiles_sync",
      "mlb_player_team_histories_sync",
      "mlb_player_contracts_download",
      "mlb_roster_sync",
      "mlb_roster_snapshots_sync",
      "player_positions_backfill",
      "daily_analytics_refresh",
      "contextual_benchmarks_refresh"
    )
    expect(json_body.dig("meta", "schedule_date_range")).to eq(
      "earliest_game_date" => "2026-03-26",
      "latest_game_date" => "2026-09-22"
    )
    expect(json_body.dig("meta", "schedule_import_range")).to eq(
      "earliest_import_date" => "2026-03-26",
      "latest_import_date" => "2026-05-31"
    )
    expect(json_body.dig("meta", "roster_coverage")).to eq(
      "earliest_date" => "2024-12-31",
      "latest_date" => Date.current.iso8601
    )
    expect(json_body.dig("meta", "mlb_teams")).to eq(
      [
        {
          "id" => tigers.id,
          "mlb_id" => 116,
          "name" => "Detroit Tigers",
          "abbreviation" => "DET",
          "league" => "american"
        }
      ]
    )
    expect(json_body.dig("meta", "database")).to include(
      "environment" => "test",
      "adapter" => "PostgreSQL"
    )
    expect(json_body.dig("meta", "database", "size_bytes")).to be_positive
    expect(json_body.dig("meta", "database", "database_name")).to be_present
    expect(json_body.dig("meta", "database", "server_version")).to be_present
    expect(json_body.dig("meta", "database", "table_count")).to be >= 16
    expect(json_body.dig("meta", "database", "user_table_size_bytes")).to be_positive
    expect(json_body.dig("meta", "database", "estimated_row_count")).to be_a(Integer)
    expect(json_body.dig("meta", "database", "estimated_dead_row_count")).to be_a(Integer)
    expect(json_body.dig("meta", "database", "statistics_collected_since")).to be_present
    expect(json_body.dig("meta", "database", "measured_at")).to be_present
    expect(json_body.dig("meta", "database", "largest_tables")).not_to be_empty
    expect(json_body.dig("meta", "database", "largest_tables", 0)).to include(
      "table_name",
      "total_size_bytes",
      "data_size_bytes",
      "index_size_bytes",
      "estimated_row_count",
      "estimated_dead_row_count",
      "database_percentage"
    )
    table_sizes = json_body.dig("meta", "database", "largest_tables").pluck("total_size_bytes")
    expect(table_sizes).to eq(table_sizes.sort.reverse)
    expect(json_body.dig("meta", "database", "most_read_tables")).not_to be_empty
    expect(json_body.dig("meta", "database", "most_read_tables", 0)).to include(
      "table_name",
      "total_scans",
      "sequential_scans",
      "index_scans",
      "rows_read_or_fetched",
      "last_sequential_scan_at",
      "last_index_scan_at"
    )
    table_scans = json_body.dig("meta", "database", "most_read_tables").pluck("total_scans")
    expect(table_scans).to eq(table_scans.sort.reverse)
    expect(json_body.dig("meta", "player_season_stats")).to include(
      "earliest_season" => 1901,
      "latest_season" => 2026
    )
    expect(json_body.dig("meta", "player_season_stats", "approximate_row_count")).to be_a(Integer)
    expect(json_body.dig("meta", "pitch_data")).to include(
      "earliest_game_date" => "2026-04-01",
      "latest_game_date" => "2026-05-31"
    )
    expect(json_body.dig("meta", "pitch_data", "approximate_row_count")).to be_a(Integer)
    expect(json_body.dig("meta", "game_details")).to include(
      "synchronized_game_count" => 0,
      "plate_appearance_count" => 0,
      "linked_pitch_count" => 0
    )
    expect(json_body.dig("meta", "daily_analytics")).to include(
      "calculation_version" => "1.0.0",
      "row_counts" => include(
        "player_batting_daily" => 0,
        "team_daily_metrics" => 0
      )
    )
    expect(json_body.dig("meta", "contextual_benchmarks")).to include(
      "calculation_version" => "1.0.0",
      "benchmark_count" => 0,
      "percentile_count" => 0
    )
  end

  it "returns an empty schedule date range when no games are stored" do
    get api_admin_tasks_path, headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "schedule_date_range")).to eq(
      "earliest_game_date" => nil,
      "latest_game_date" => nil
    )
    expect(json_body.dig("meta", "schedule_import_range")).to eq(
      "earliest_import_date" => nil,
      "latest_import_date" => nil
    )
    expect(json_body.dig("meta", "roster_coverage")).to eq(
      "earliest_date" => nil,
      "latest_date" => nil
    )
  end

  it "queues an allowlisted admin task and returns its persisted run" do
    expect do
      post run_api_admin_task_path("mlb_schedule_sync"), headers: admin_headers,
           params: { start_date: "2026-07-15", end_date: "2026-07-17" }
    end.to have_enqueued_job(AdminTaskJob)

    expect(response).to have_http_status(:accepted)
    expect(json_body.fetch("data")).to include(
      "task_name" => "mlb_schedule_sync",
      "status" => "queued",
      "task_parameters" => include(
        "start_date" => "2026-07-15",
        "end_date" => "2026-07-17"
      ),
      "initiated_by" => include("email" => "system@ninelens.local")
    )
  end

  it "requires the configured admin token for task execution" do
    ENV["ADMIN_API_TOKEN"] = "secret-token"

    post run_api_admin_task_path("player_positions_backfill"), headers: admin_headers

    expect(response).to have_http_status(:unauthorized)
    expect(json_body.fetch("message")).to eq("Admin API token is required")
  end

  it "persists validation failures from the background worker" do
    post run_api_admin_task_path("mlb_schedule_sync"), headers: admin_headers

    expect(response).to have_http_status(:accepted)
    run = AdminTaskRun.find(json_body.dig("data", "id"))
    perform_enqueued_jobs

    expect(run.reload).to have_attributes(
      status: "failed",
      error_message: "Start date is required",
      failed_items: 1
    )
  end
end
