# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_09_22_020000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "plpgsql"

  create_table "admin_task_runs", force: :cascade do |t|
    t.string "task_name", null: false
    t.string "status", default: "queued", null: false
    t.jsonb "task_parameters", default: {}, null: false
    t.jsonb "result_data", default: {}, null: false
    t.text "error_message"
    t.integer "total_items", default: 0, null: false
    t.integer "completed_items", default: 0, null: false
    t.integer "failed_items", default: 0, null: false
    t.bigint "current_item_mlb_id"
    t.string "current_item_label"
    t.datetime "cancel_requested_at"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "last_heartbeat_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "initiated_by_id"
    t.integer "estimated_duration_seconds"
    t.datetime "remaining_time_anchor_at"
    t.index ["created_at"], name: "index_admin_task_runs_on_created_at"
    t.index ["initiated_by_id"], name: "index_admin_task_runs_on_initiated_by_id"
    t.index ["task_name", "status", "created_at"], name: "idx_admin_task_runs_active_lookup"
    t.index ["task_name"], name: "idx_admin_task_runs_one_active_per_task", unique: true, where: "((status)::text = ANY ((ARRAY['queued'::character varying, 'running'::character varying])::text[]))"
  end

  create_table "admin_task_uploads", force: :cascade do |t|
    t.bigint "admin_task_run_id", null: false
    t.string "original_filename", null: false
    t.string "content_type"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.binary "contents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_task_run_id"], name: "index_admin_task_uploads_on_admin_task_run_id", unique: true
  end

  create_table "alert_subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "player_id"
    t.bigint "watchlist_id"
    t.string "name"
    t.string "minimum_severity", default: "warning", null: false
    t.string "event_types", default: [], null: false, array: true
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_alert_subscriptions_on_player_id"
    t.index ["user_id", "player_id"], name: "idx_alert_subscriptions_user_player", unique: true, where: "(player_id IS NOT NULL)"
    t.index ["user_id", "watchlist_id"], name: "idx_alert_subscriptions_user_watchlist", unique: true, where: "(watchlist_id IS NOT NULL)"
    t.index ["user_id"], name: "index_alert_subscriptions_on_user_id"
    t.index ["watchlist_id"], name: "index_alert_subscriptions_on_watchlist_id"
    t.check_constraint "(player_id IS NOT NULL) <> (watchlist_id IS NOT NULL)", name: "alert_subscriptions_one_target"
    t.check_constraint "minimum_severity::text = ANY (ARRAY['warning'::character varying, 'critical'::character varying]::text[])", name: "alert_subscriptions_valid_severity"
  end

  create_table "alerts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "player_trend_event_id", null: false
    t.bigint "alert_subscription_id"
    t.bigint "assigned_to_id"
    t.string "status", default: "active", null: false
    t.jsonb "supporting_evidence", default: {}, null: false
    t.jsonb "links", default: {}, null: false
    t.datetime "acknowledged_at"
    t.datetime "snoozed_until"
    t.datetime "resolved_at"
    t.datetime "last_digest_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_subscription_id"], name: "index_alerts_on_alert_subscription_id"
    t.index ["assigned_to_id"], name: "index_alerts_on_assigned_to_id"
    t.index ["player_trend_event_id"], name: "index_alerts_on_player_trend_event_id"
    t.index ["user_id", "player_trend_event_id"], name: "idx_alerts_user_event_unique", unique: true
    t.index ["user_id", "status", "created_at"], name: "idx_alerts_user_inbox"
    t.index ["user_id"], name: "index_alerts_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'acknowledged'::character varying, 'snoozed'::character varying, 'resolved'::character varying]::text[])", name: "alerts_valid_status"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.string "action", null: false
    t.string "auditable_type", null: false
    t.bigint "auditable_id", null: false
    t.jsonb "change_set", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auditable_type", "auditable_id", "created_at"], name: "idx_audit_logs_auditable_history"
    t.index ["user_id", "created_at"], name: "idx_audit_logs_user_history"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "batter_split_summaries", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "team_id"
    t.string "split_type", null: false
    t.string "split_value", null: false
    t.date "metric_date", null: false
    t.date "source_start_date", null: false
    t.date "source_end_date", null: false
    t.integer "sample_size", default: 0, null: false
    t.string "calculation_version", null: false
    t.datetime "calculated_at", null: false
    t.string "source_name", null: false
    t.jsonb "metrics", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["metric_date", "calculation_version"], name: "idx_on_metric_date_calculation_version_4c26b0c526"
    t.index ["player_id", "metric_date", "split_type", "split_value", "calculation_version"], name: "idx_batter_split_summaries_identity", unique: true
    t.index ["player_id"], name: "index_batter_split_summaries_on_player_id"
    t.index ["team_id"], name: "index_batter_split_summaries_on_team_id"
    t.check_constraint "sample_size >= 0", name: "batter_split_summaries_sample_size_nonnegative"
    t.check_constraint "source_end_date >= source_start_date", name: "batter_split_summaries_source_range_valid"
  end

  create_table "game_player_batting_lines", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.bigint "player_id", null: false
    t.bigint "team_id", null: false
    t.bigint "opponent_team_id", null: false
    t.boolean "home", null: false
    t.boolean "starter", default: false, null: false
    t.integer "batting_order"
    t.string "position"
    t.integer "plate_appearances"
    t.integer "at_bats"
    t.integer "runs"
    t.integer "hits"
    t.integer "doubles"
    t.integer "triples"
    t.integer "home_runs"
    t.integer "runs_batted_in"
    t.integer "walks"
    t.integer "strikeouts"
    t.integer "stolen_bases"
    t.integer "caught_stealing"
    t.decimal "batting_average", precision: 6, scale: 4
    t.decimal "on_base_percentage", precision: 6, scale: 4
    t.decimal "slugging_percentage", precision: 6, scale: 4
    t.decimal "ops", precision: 6, scale: 4
    t.string "source_name", null: false
    t.string "source_url"
    t.datetime "last_synced_at", null: false
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "player_id"], name: "idx_game_batting_lines_game_player", unique: true
    t.index ["game_id"], name: "index_game_player_batting_lines_on_game_id"
    t.index ["opponent_team_id"], name: "index_game_player_batting_lines_on_opponent_team_id"
    t.index ["player_id", "game_id"], name: "idx_game_batting_lines_player_game"
    t.index ["player_id"], name: "index_game_player_batting_lines_on_player_id"
    t.index ["team_id"], name: "index_game_player_batting_lines_on_team_id"
  end

  create_table "game_player_pitching_lines", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.bigint "player_id", null: false
    t.bigint "team_id", null: false
    t.bigint "opponent_team_id", null: false
    t.boolean "home", null: false
    t.boolean "starter", default: false, null: false
    t.integer "appearance_order"
    t.string "innings_pitched"
    t.integer "outs_recorded"
    t.integer "batters_faced"
    t.integer "hits"
    t.integer "runs"
    t.integer "earned_runs"
    t.integer "home_runs"
    t.integer "walks"
    t.integer "strikeouts"
    t.integer "pitches"
    t.integer "strikes"
    t.decimal "era", precision: 7, scale: 3
    t.decimal "whip", precision: 7, scale: 3
    t.string "decision"
    t.integer "holds"
    t.integer "saves"
    t.integer "blown_saves"
    t.string "source_name", null: false
    t.string "source_url"
    t.datetime "last_synced_at", null: false
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "player_id"], name: "idx_game_pitching_lines_game_player", unique: true
    t.index ["game_id"], name: "index_game_player_pitching_lines_on_game_id"
    t.index ["opponent_team_id"], name: "index_game_player_pitching_lines_on_opponent_team_id"
    t.index ["player_id", "game_id"], name: "idx_game_pitching_lines_player_game"
    t.index ["player_id"], name: "index_game_player_pitching_lines_on_player_id"
    t.index ["team_id"], name: "index_game_player_pitching_lines_on_team_id"
  end

  create_table "games", force: :cascade do |t|
    t.bigint "schedule_id", null: false
    t.bigint "mlb_id", null: false
    t.date "official_date", null: false
    t.datetime "scheduled_at"
    t.string "game_type", null: false
    t.string "status", null: false
    t.string "detailed_status"
    t.bigint "home_team_id", null: false
    t.bigint "away_team_id", null: false
    t.bigint "home_probable_pitcher_id"
    t.bigint "away_probable_pitcher_id"
    t.string "venue_name"
    t.integer "game_number"
    t.string "doubleheader"
    t.integer "home_score"
    t.integer "away_score"
    t.string "source_name", null: false
    t.string "source_url"
    t.datetime "last_synced_at", null: false
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "details_source_url"
    t.datetime "details_last_synced_at"
    t.jsonb "boxscore_raw_data", default: {}, null: false
    t.jsonb "live_feed_raw_data", default: {}, null: false
    t.datetime "pitch_data_complete_at"
    t.integer "pitch_data_row_count", default: 0, null: false
    t.index ["away_probable_pitcher_id"], name: "index_games_on_away_probable_pitcher_id"
    t.index ["away_team_id", "official_date"], name: "index_games_on_away_team_id_and_official_date"
    t.index ["away_team_id"], name: "index_games_on_away_team_id"
    t.index ["details_last_synced_at"], name: "idx_games_details_last_synced_at"
    t.index ["home_probable_pitcher_id"], name: "index_games_on_home_probable_pitcher_id"
    t.index ["home_team_id", "official_date"], name: "index_games_on_home_team_id_and_official_date"
    t.index ["home_team_id"], name: "index_games_on_home_team_id"
    t.index ["last_synced_at"], name: "idx_games_last_synced_at"
    t.index ["mlb_id"], name: "index_games_on_mlb_id", unique: true
    t.index ["official_date", "status"], name: "index_games_on_official_date_and_status"
    t.index ["pitch_data_complete_at"], name: "index_games_on_pitch_data_complete_at"
    t.index ["schedule_id"], name: "index_games_on_schedule_id"
    t.check_constraint "away_score IS NULL OR away_score >= 0", name: "games_nonnegative_away_score"
    t.check_constraint "home_score IS NULL OR home_score >= 0", name: "games_nonnegative_home_score"
    t.check_constraint "home_team_id <> away_team_id", name: "games_distinct_teams"
  end

  create_table "league_metric_benchmarks", force: :cascade do |t|
    t.string "metric_key", null: false
    t.string "metric_group", null: false
    t.string "display_name", null: false
    t.string "peer_group_type", null: false
    t.string "peer_group_key", null: false
    t.string "dimension_type", default: "", null: false
    t.string "dimension_value", default: "", null: false
    t.string "directionality", null: false
    t.decimal "average_value", precision: 14, scale: 6, null: false
    t.bigint "sample_size", default: 0, null: false
    t.integer "player_count", default: 0, null: false
    t.date "source_start_date", null: false
    t.date "source_end_date", null: false
    t.string "calculation_version", null: false
    t.datetime "calculated_at", null: false
    t.string "source_name", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["metric_key", "peer_group_type", "peer_group_key", "dimension_type", "dimension_value", "source_start_date", "source_end_date", "calculation_version"], name: "idx_league_metric_benchmarks_identity", unique: true
    t.index ["source_end_date", "calculation_version"], name: "idx_league_metric_benchmarks_latest"
    t.check_constraint "player_count >= 0", name: "league_benchmarks_players_nonnegative"
    t.check_constraint "sample_size >= 0", name: "league_benchmarks_sample_nonnegative"
    t.check_constraint "source_end_date >= source_start_date", name: "league_benchmarks_range_valid"
  end

  create_table "lineup_entries", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.bigint "team_id", null: false
    t.bigint "player_id", null: false
    t.integer "batting_order"
    t.integer "batting_slot"
    t.boolean "starter", default: false, null: false
    t.string "position"
    t.jsonb "all_positions", default: [], null: false
    t.jsonb "substitutions", default: [], null: false
    t.string "source_name", null: false
    t.string "source_url"
    t.datetime "last_synced_at", null: false
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "team_id", "batting_order"], name: "idx_lineup_entries_game_team_order"
    t.index ["game_id", "team_id", "player_id"], name: "idx_lineup_entries_game_team_player", unique: true
    t.index ["game_id"], name: "index_lineup_entries_on_game_id"
    t.index ["player_id"], name: "index_lineup_entries_on_player_id"
    t.index ["team_id"], name: "index_lineup_entries_on_team_id"
  end

  create_table "lineup_scenario_entries", force: :cascade do |t|
    t.bigint "lineup_scenario_id", null: false
    t.bigint "player_id", null: false
    t.integer "batting_slot", null: false
    t.string "defensive_position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lineup_scenario_id", "batting_slot"], name: "index_lineup_scenario_entries_on_slot", unique: true
    t.index ["lineup_scenario_id", "player_id"], name: "index_lineup_scenario_entries_on_player", unique: true
    t.index ["lineup_scenario_id"], name: "index_lineup_scenario_entries_on_lineup_scenario_id"
    t.index ["player_id"], name: "index_lineup_scenario_entries_on_player_id"
    t.check_constraint "batting_slot >= 1 AND batting_slot <= 9", name: "lineup_scenario_entries_valid_slot"
  end

  create_table "lineup_scenarios", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.integer "season", null: false
    t.date "scenario_date", null: false
    t.string "name", null: false
    t.text "notes"
    t.datetime "validated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "evaluation_inputs", default: {}, null: false
    t.jsonb "score_breakdown", default: {}, null: false
    t.decimal "total_score", precision: 6, scale: 2
    t.bigint "owner_id", null: false
    t.jsonb "decision_constraints", default: {}, null: false
    t.jsonb "decision_weights", default: {}, null: false
    t.jsonb "recommendation_data", default: {}, null: false
    t.index ["owner_id"], name: "index_lineup_scenarios_on_owner_id"
    t.index ["team_id", "season", "scenario_date"], name: "index_lineup_scenarios_on_team_season_date"
    t.index ["team_id"], name: "index_lineup_scenarios_on_team_id"
  end

  create_table "need_profiles", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.string "name", null: false
    t.text "description"
    t.jsonb "criteria", default: {}, null: false
    t.jsonb "weights", default: {}, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "owner_id"
    t.index ["owner_id"], name: "index_need_profiles_on_owner_id"
    t.index ["team_id", "name"], name: "index_need_profiles_on_team_id_and_name", unique: true
    t.index ["team_id"], name: "index_need_profiles_on_team_id"
  end

  create_table "note_revisions", force: :cascade do |t|
    t.bigint "note_id", null: false
    t.bigint "editor_id", null: false
    t.integer "version", null: false
    t.string "action", default: "updated", null: false
    t.text "body", null: false
    t.date "note_date", null: false
    t.jsonb "tag_names", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["editor_id"], name: "index_note_revisions_on_editor_id"
    t.index ["note_id", "version"], name: "index_note_revisions_on_note_id_and_version", unique: true
    t.index ["note_id"], name: "index_note_revisions_on_note_id"
  end

  create_table "note_taggings", force: :cascade do |t|
    t.bigint "note_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["note_id", "tag_id"], name: "index_note_taggings_on_note_id_and_tag_id", unique: true
    t.index ["note_id"], name: "index_note_taggings_on_note_id"
    t.index ["tag_id"], name: "index_note_taggings_on_tag_id"
  end

  create_table "notes", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.bigint "last_edited_by_id", null: false
    t.string "target_type", null: false
    t.string "target_key", null: false
    t.text "body", null: false
    t.date "note_date", null: false
    t.jsonb "target_metadata", default: {}, null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["archived_at"], name: "index_notes_on_archived_at"
    t.index ["author_id"], name: "index_notes_on_author_id"
    t.index ["last_edited_by_id"], name: "index_notes_on_last_edited_by_id"
    t.index ["target_type", "target_key", "note_date"], name: "index_notes_on_target_and_date"
  end

  create_table "opponent_reports", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.bigint "opponent_team_id", null: false
    t.integer "season", null: false
    t.date "series_starts_on", null: false
    t.date "series_ends_on", null: false
    t.string "title", null: false
    t.jsonb "snapshot", default: {}, null: false
    t.datetime "generated_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "owner_id", null: false
    t.index ["opponent_team_id"], name: "index_opponent_reports_on_opponent_team_id"
    t.index ["owner_id"], name: "index_opponent_reports_on_owner_id"
    t.index ["team_id", "generated_at"], name: "index_opponent_reports_on_team_id_and_generated_at"
    t.index ["team_id", "opponent_team_id", "series_starts_on"], name: "index_opponent_reports_on_series"
    t.index ["team_id"], name: "index_opponent_reports_on_team_id"
    t.check_constraint "series_ends_on >= series_starts_on", name: "opponent_reports_valid_series_range"
  end

  create_table "pitch_data", force: :cascade do |t|
    t.date "source_start_date"
    t.date "source_end_date"
    t.datetime "fetched_at_utc"
    t.date "game_date"
    t.bigint "game_pk", null: false
    t.string "game_type"
    t.string "home_team"
    t.string "away_team"
    t.integer "inning"
    t.string "inning_topbot"
    t.integer "at_bat_number", null: false
    t.integer "pitch_number", null: false
    t.bigint "pitcher"
    t.string "player_name"
    t.bigint "batter"
    t.string "stand"
    t.string "p_throws"
    t.string "pitch_type"
    t.string "pitch_name"
    t.string "description"
    t.string "events"
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "balls"
    t.integer "strikes"
    t.integer "outs_when_up"
    t.float "release_speed"
    t.float "release_spin_rate"
    t.float "release_extension"
    t.float "release_pos_x"
    t.float "release_pos_y"
    t.float "release_pos_z"
    t.float "pfx_x"
    t.float "pfx_z"
    t.float "plate_x"
    t.float "plate_z"
    t.integer "zone"
    t.float "launch_speed"
    t.float "launch_angle"
    t.float "hit_distance_sc"
    t.string "bb_type"
    t.float "estimated_ba_using_speedangle"
    t.float "estimated_woba_using_speedangle"
    t.float "woba_value"
    t.float "delta_run_exp"
    t.integer "bat_score"
    t.integer "fld_score"
    t.integer "post_bat_score"
    t.integer "post_fld_score"
    t.string "sv_id"
    t.float "age_bat"
    t.float "age_bat_legacy"
    t.float "age_pit"
    t.float "age_pit_legacy"
    t.float "api_break_x_arm"
    t.float "api_break_x_batter_in"
    t.float "api_break_z_with_gravity"
    t.float "arm_angle"
    t.float "attack_angle"
    t.float "attack_direction"
    t.integer "away_score"
    t.float "ax"
    t.float "ay"
    t.float "az"
    t.float "babip_value"
    t.integer "bat_score_diff"
    t.float "bat_speed"
    t.float "bat_win_exp"
    t.integer "batter_days_since_prev_game"
    t.integer "batter_days_until_next_game"
    t.float "break_angle_deprecated"
    t.float "break_length_deprecated"
    t.float "delta_home_win_exp"
    t.float "delta_pitcher_run_exp"
    t.string "des"
    t.float "effective_speed"
    t.float "estimated_slg_using_speedangle"
    t.bigint "fielder_2"
    t.bigint "fielder_3"
    t.bigint "fielder_4"
    t.bigint "fielder_5"
    t.bigint "fielder_6"
    t.bigint "fielder_7"
    t.bigint "fielder_8"
    t.bigint "fielder_9"
    t.integer "game_year"
    t.float "hc_x"
    t.float "hc_y"
    t.integer "hit_location"
    t.integer "home_score"
    t.integer "home_score_diff"
    t.float "home_win_exp"
    t.float "hyper_speed"
    t.string "if_fielding_alignment"
    t.float "intercept_ball_minus_batter_pos_x_inches"
    t.float "intercept_ball_minus_batter_pos_y_inches"
    t.float "iso_value"
    t.integer "launch_speed_angle"
    t.float "miss_distance"
    t.integer "n_priorpa_thisgame_player_at_bat"
    t.integer "n_thruorder_pitcher"
    t.string "of_fielding_alignment"
    t.bigint "on_1b"
    t.bigint "on_2b"
    t.bigint "on_3b"
    t.integer "pitcher_days_since_prev_game"
    t.integer "pitcher_days_until_next_game"
    t.integer "post_away_score"
    t.integer "post_home_score"
    t.float "spin_axis"
    t.float "spin_dir"
    t.float "spin_rate_deprecated"
    t.float "swing_length"
    t.float "swing_path_tilt"
    t.float "sz_bot"
    t.float "sz_top"
    t.string "tfs_deprecated"
    t.string "tfs_zulu_deprecated"
    t.string "type"
    t.bigint "umpire"
    t.float "vx0"
    t.float "vy0"
    t.float "vz0"
    t.integer "woba_denom"
    t.bigint "game_id"
    t.bigint "plate_appearance_id"
    t.index ["batter", "game_date"], name: "idx_pitch_data_batter_game_date"
    t.index ["batter"], name: "index_pitch_data_on_batter"
    t.index ["game_date"], name: "index_pitch_data_on_game_date"
    t.index ["game_id"], name: "index_pitch_data_on_game_id"
    t.index ["game_pk", "at_bat_number", "pitch_number"], name: "idx_pitch_data_unique_pitch", unique: true
    t.index ["pitch_type"], name: "index_pitch_data_on_pitch_type"
    t.index ["pitcher", "game_date"], name: "idx_pitch_data_pitcher_game_date"
    t.index ["pitcher"], name: "index_pitch_data_on_pitcher"
    t.index ["plate_appearance_id", "pitch_number"], name: "index_pitch_data_on_plate_appearance_id_and_pitch_number"
    t.index ["plate_appearance_id"], name: "index_pitch_data_on_plate_appearance_id"
  end

  create_table "pitcher_pitch_type_daily", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "team_id"
    t.string "pitch_type", null: false
    t.string "pitch_name"
    t.date "metric_date", null: false
    t.date "source_start_date", null: false
    t.date "source_end_date", null: false
    t.integer "sample_size", default: 0, null: false
    t.string "calculation_version", null: false
    t.datetime "calculated_at", null: false
    t.string "source_name", null: false
    t.jsonb "metrics", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["metric_date", "calculation_version"], name: "idx_on_metric_date_calculation_version_6c0612609d"
    t.index ["player_id", "metric_date", "pitch_type", "calculation_version"], name: "idx_pitcher_pitch_type_daily_identity", unique: true
    t.index ["player_id"], name: "index_pitcher_pitch_type_daily_on_player_id"
    t.index ["team_id"], name: "index_pitcher_pitch_type_daily_on_team_id"
    t.check_constraint "sample_size >= 0", name: "pitcher_pitch_type_daily_sample_size_nonnegative"
    t.check_constraint "source_end_date >= source_start_date", name: "pitcher_pitch_type_daily_source_range_valid"
  end

  create_table "pitcher_split_summaries", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "team_id"
    t.string "split_type", null: false
    t.string "split_value", null: false
    t.date "metric_date", null: false
    t.date "source_start_date", null: false
    t.date "source_end_date", null: false
    t.integer "sample_size", default: 0, null: false
    t.string "calculation_version", null: false
    t.datetime "calculated_at", null: false
    t.string "source_name", null: false
    t.jsonb "metrics", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["metric_date", "calculation_version"], name: "idx_on_metric_date_calculation_version_99e6483c5d"
    t.index ["player_id", "metric_date", "split_type", "split_value", "calculation_version"], name: "idx_pitcher_split_summaries_identity", unique: true
    t.index ["player_id"], name: "index_pitcher_split_summaries_on_player_id"
    t.index ["team_id"], name: "index_pitcher_split_summaries_on_team_id"
    t.check_constraint "sample_size >= 0", name: "pitcher_split_summaries_sample_size_nonnegative"
    t.check_constraint "source_end_date >= source_start_date", name: "pitcher_split_summaries_source_range_valid"
  end

  create_table "plate_appearances", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.bigint "batter_id"
    t.bigint "pitcher_id"
    t.bigint "batting_team_id"
    t.bigint "fielding_team_id"
    t.integer "at_bat_index", null: false
    t.integer "plate_appearance_number", null: false
    t.integer "inning"
    t.string "half_inning"
    t.string "event"
    t.string "event_type"
    t.text "description"
    t.integer "runs_batted_in"
    t.integer "away_score"
    t.integer "home_score"
    t.integer "outs_after"
    t.boolean "complete", default: false, null: false
    t.datetime "started_at"
    t.datetime "ended_at"
    t.string "source_name", null: false
    t.string "source_url"
    t.datetime "last_synced_at", null: false
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["batter_id", "game_id"], name: "index_plate_appearances_on_batter_id_and_game_id"
    t.index ["batter_id"], name: "index_plate_appearances_on_batter_id"
    t.index ["batting_team_id"], name: "index_plate_appearances_on_batting_team_id"
    t.index ["fielding_team_id"], name: "index_plate_appearances_on_fielding_team_id"
    t.index ["game_id", "at_bat_index"], name: "index_plate_appearances_on_game_id_and_at_bat_index", unique: true
    t.index ["game_id", "plate_appearance_number"], name: "idx_plate_appearances_game_number", unique: true
    t.index ["game_id"], name: "index_plate_appearances_on_game_id"
    t.index ["pitcher_id", "game_id"], name: "index_plate_appearances_on_pitcher_id_and_game_id"
    t.index ["pitcher_id"], name: "index_plate_appearances_on_pitcher_id"
  end

  create_table "player_batting_daily", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "team_id", null: false
    t.date "metric_date", null: false
    t.date "source_start_date", null: false
    t.date "source_end_date", null: false
    t.integer "sample_size", default: 0, null: false
    t.string "calculation_version", null: false
    t.datetime "calculated_at", null: false
    t.string "source_name", null: false
    t.jsonb "metrics", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["metric_date", "calculation_version"], name: "idx_on_metric_date_calculation_version_786d18fcc2"
    t.index ["player_id", "team_id", "metric_date", "calculation_version"], name: "idx_player_batting_daily_identity", unique: true
    t.index ["player_id"], name: "index_player_batting_daily_on_player_id"
    t.index ["team_id"], name: "index_player_batting_daily_on_team_id"
    t.check_constraint "sample_size >= 0", name: "player_batting_daily_sample_size_nonnegative"
    t.check_constraint "source_end_date >= source_start_date", name: "player_batting_daily_source_range_valid"
  end

  create_table "player_contracts", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.integer "season", null: false
    t.string "team_slug"
    t.string "contract"
    t.integer "aav_amount"
    t.integer "salary_amount"
    t.jsonb "salary_by_year", default: {}, null: false
    t.string "source_player_id"
    t.string "source_url", null: false
    t.datetime "fetched_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "season"], name: "index_player_contracts_on_player_id_and_season", unique: true
    t.index ["player_id"], name: "index_player_contracts_on_player_id"
    t.index ["season"], name: "index_player_contracts_on_season"
  end

  create_table "player_id_mappings", force: :cascade do |t|
    t.integer "mlb_id", null: false
    t.string "chadwick_id", null: false
    t.uuid "chadwick_uuid", null: false
    t.string "retrosheet_id"
    t.string "baseball_reference_id"
    t.string "baseball_reference_minors_id"
    t.string "fangraphs_id"
    t.string "npb_id"
    t.string "pro_football_reference_id"
    t.string "basketball_reference_id"
    t.string "hockey_reference_id"
    t.string "wikidata_id"
    t.string "source_name", default: "Chadwick Register", null: false
    t.datetime "imported_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["baseball_reference_id"], name: "index_player_id_mappings_on_baseball_reference_id"
    t.index ["chadwick_id"], name: "index_player_id_mappings_on_chadwick_id", unique: true
    t.index ["fangraphs_id"], name: "index_player_id_mappings_on_fangraphs_id"
    t.index ["mlb_id"], name: "index_player_id_mappings_on_mlb_id", unique: true
  end

  create_table "player_metric_percentiles", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "league_metric_benchmark_id", null: false
    t.decimal "raw_value", precision: 14, scale: 6, null: false
    t.decimal "percentile", precision: 6, scale: 2, null: false
    t.bigint "sample_size", default: 0, null: false
    t.integer "peer_player_count", default: 0, null: false
    t.date "source_start_date", null: false
    t.date "source_end_date", null: false
    t.string "calculation_version", null: false
    t.datetime "calculated_at", null: false
    t.string "source_name", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["league_metric_benchmark_id"], name: "index_player_metric_percentiles_on_league_metric_benchmark_id"
    t.index ["player_id", "league_metric_benchmark_id"], name: "idx_player_metric_percentiles_identity", unique: true
    t.index ["player_id", "source_end_date", "calculation_version"], name: "idx_player_metric_percentiles_latest"
    t.index ["player_id"], name: "index_player_metric_percentiles_on_player_id"
    t.check_constraint "peer_player_count >= 0", name: "player_percentiles_peers_nonnegative"
    t.check_constraint "percentile >= 0::numeric AND percentile <= 100::numeric", name: "player_percentiles_value_valid"
    t.check_constraint "sample_size >= 0", name: "player_percentiles_sample_nonnegative"
    t.check_constraint "source_end_date >= source_start_date", name: "player_percentiles_range_valid"
  end

  create_table "player_pitching_daily", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "team_id", null: false
    t.date "metric_date", null: false
    t.date "source_start_date", null: false
    t.date "source_end_date", null: false
    t.integer "sample_size", default: 0, null: false
    t.string "calculation_version", null: false
    t.datetime "calculated_at", null: false
    t.string "source_name", null: false
    t.jsonb "metrics", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["metric_date", "calculation_version"], name: "idx_on_metric_date_calculation_version_ffce0e8cff"
    t.index ["player_id", "team_id", "metric_date", "calculation_version"], name: "idx_player_pitching_daily_identity", unique: true
    t.index ["player_id"], name: "index_player_pitching_daily_on_player_id"
    t.index ["team_id"], name: "index_player_pitching_daily_on_team_id"
    t.check_constraint "sample_size >= 0", name: "player_pitching_daily_sample_size_nonnegative"
    t.check_constraint "source_end_date >= source_start_date", name: "player_pitching_daily_source_range_valid"
  end

  create_table "player_positions", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "position_id", null: false
    t.boolean "is_primary", default: false, null: false
    t.integer "season"
    t.string "source_name", null: false
    t.datetime "last_synced_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "position_id", "season"], name: "index_player_positions_unique_season", unique: true, where: "(season IS NOT NULL)"
    t.index ["player_id", "position_id"], name: "index_player_positions_unique_current", unique: true, where: "(season IS NULL)"
    t.index ["player_id", "season"], name: "index_player_positions_one_season_primary", unique: true, where: "((season IS NOT NULL) AND (is_primary = true))"
    t.index ["player_id"], name: "index_player_positions_on_player_id"
    t.index ["player_id"], name: "index_player_positions_one_current_primary", unique: true, where: "((season IS NULL) AND (is_primary = true))"
    t.index ["position_id"], name: "index_player_positions_on_position_id"
    t.check_constraint "season IS NULL OR season > 1800", name: "player_positions_valid_season"
  end

  create_table "player_profiles", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.date "birth_date"
    t.integer "height_inches"
    t.integer "weight_pounds"
    t.string "bats", limit: 1
    t.string "throws", limit: 1
    t.date "mlb_debut_date"
    t.string "headshot_id"
    t.string "headshot_url_override"
    t.string "source_name", null: false
    t.datetime "source_updated_at"
    t.datetime "last_synced_at", null: false
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_player_profiles_on_player_id", unique: true
    t.check_constraint "bats IS NULL OR (bats::text = ANY (ARRAY['L'::character varying, 'R'::character varying, 'S'::character varying]::text[]))", name: "player_profiles_valid_bats"
    t.check_constraint "height_inches IS NULL OR height_inches > 0", name: "player_profiles_positive_height"
    t.check_constraint "throws IS NULL OR (throws::text = ANY (ARRAY['L'::character varying, 'R'::character varying]::text[]))", name: "player_profiles_valid_throws"
    t.check_constraint "weight_pounds IS NULL OR weight_pounds > 0", name: "player_profiles_positive_weight"
  end

  create_table "player_season_fielding_stats", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "team_id"
    t.integer "season", null: false
    t.string "team_abbreviation", null: false
    t.string "position", null: false
    t.integer "games"
    t.decimal "innings", precision: 7, scale: 1
    t.integer "putouts"
    t.integer "assists"
    t.integer "fielding_errors"
    t.decimal "fielding_percentage", precision: 7, scale: 6
    t.decimal "defensive_runs_saved", precision: 7, scale: 2
    t.decimal "outs_above_average", precision: 7, scale: 2
    t.string "source_name", null: false
    t.datetime "last_synced_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "season", "team_abbreviation", "position"], name: "idx_player_season_fielding_stats_unique_scope", unique: true
    t.index ["player_id"], name: "index_player_season_fielding_stats_on_player_id"
    t.index ["team_id"], name: "index_player_season_fielding_stats_on_team_id"
  end

  create_table "player_season_stats", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "stat_type_id", null: false
    t.integer "season", null: false
    t.decimal "value", precision: 12, scale: 4, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "team_id"
    t.string "scope_type"
    t.string "scope_key"
    t.index ["player_id", "stat_type_id", "season", "scope_type", "scope_key"], name: "idx_player_season_stats_unique_scope", unique: true
    t.index ["player_id"], name: "index_player_season_stats_on_player_id"
    t.index ["season", "stat_type_id", "value"], name: "idx_player_season_stats_home_leaderboard", order: { value: :desc }, include: ["player_id", "team_id", "scope_type", "scope_key"]
    t.index ["season"], name: "index_player_season_stats_on_season"
    t.index ["stat_type_id", "value"], name: "idx_player_season_stats_leaderboard_lookup", order: { value: :desc }, include: ["player_id", "team_id", "season", "scope_type", "scope_key"]
    t.index ["stat_type_id"], name: "index_player_season_stats_on_stat_type_id"
    t.index ["team_id"], name: "index_player_season_stats_on_team_id"
    t.index ["updated_at"], name: "idx_player_season_stats_updated_at"
    t.check_constraint "scope_type::text = ANY (ARRAY['team'::character varying, 'combined'::character varying, 'league'::character varying]::text[])", name: "player_season_stats_valid_scope_type"
  end

  create_table "player_stats", force: :cascade do |t|
    t.string "player_id", null: false
    t.string "source_url", null: false
    t.integer "row_number", null: false
    t.jsonb "stats_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "source_url", "row_number"], name: "index_player_stats_on_player_id_and_source_url_and_row_number", unique: true
    t.index ["player_id", "source_url"], name: "index_player_stats_on_player_id_and_source_url"
  end

  create_table "player_trend_events", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.string "identity_key", null: false
    t.string "event_type", null: false
    t.string "role", null: false
    t.string "metric_key", null: false
    t.string "pitch_type"
    t.string "direction", null: false
    t.string "severity", null: false
    t.string "status", default: "active", null: false
    t.string "unit", null: false
    t.decimal "baseline_value", precision: 12, scale: 4, null: false
    t.decimal "current_value", precision: 12, scale: 4, null: false
    t.decimal "change_value", precision: 12, scale: 4, null: false
    t.decimal "threshold_value", precision: 12, scale: 4, null: false
    t.integer "baseline_sample_size", null: false
    t.integer "sample_size", null: false
    t.date "baseline_start_date", null: false
    t.date "baseline_end_date", null: false
    t.date "current_start_date", null: false
    t.date "current_end_date", null: false
    t.date "onset_date", null: false
    t.datetime "detected_at", null: false
    t.datetime "last_observed_at", null: false
    t.datetime "resolved_at"
    t.string "calculation_version", null: false
    t.jsonb "thresholds", default: {}, null: false
    t.jsonb "supporting_pitches", default: [], null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "identity_key"], name: "idx_player_trend_events_one_active", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["player_id", "status", "severity", "onset_date"], name: "idx_player_trend_events_feed"
    t.index ["player_id"], name: "index_player_trend_events_on_player_id"
    t.check_constraint "direction::text = ANY (ARRAY['increase'::character varying, 'decrease'::character varying]::text[])", name: "player_trend_events_direction"
    t.check_constraint "role::text = ANY (ARRAY['batter'::character varying, 'pitcher'::character varying]::text[])", name: "player_trend_events_role"
    t.check_constraint "sample_size > 0 AND baseline_sample_size > 0", name: "player_trend_events_sample_sizes"
    t.check_constraint "severity::text = ANY (ARRAY['warning'::character varying, 'critical'::character varying]::text[])", name: "player_trend_events_severity"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'resolved'::character varying]::text[])", name: "player_trend_events_status"
  end

  create_table "players", force: :cascade do |t|
    t.integer "mlb_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.bigint "team_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mlb_id"], name: "index_players_on_mlb_id", unique: true
    t.index ["team_id"], name: "index_players_on_team_id"
  end

  create_table "positions", force: :cascade do |t|
    t.string "mlb_code", null: false
    t.string "abbreviation", null: false
    t.string "name", null: false
    t.string "position_type", null: false
    t.integer "sort_order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["abbreviation"], name: "index_positions_on_abbreviation", unique: true
    t.index ["mlb_code"], name: "index_positions_on_mlb_code", unique: true
    t.index ["sort_order"], name: "index_positions_on_sort_order"
    t.check_constraint "position_type::text = ANY (ARRAY['pitcher'::character varying, 'catcher'::character varying, 'infielder'::character varying, 'outfielder'::character varying, 'designated_hitter'::character varying, 'two_way'::character varying, 'other'::character varying]::text[])", name: "positions_valid_position_type"
    t.check_constraint "sort_order > 0", name: "positions_positive_sort_order"
  end

  create_table "roster_players", force: :cascade do |t|
    t.bigint "roster_id", null: false
    t.bigint "player_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_roster_players_on_player_id"
    t.index ["roster_id", "player_id"], name: "index_roster_players_on_roster_id_and_player_id", unique: true
    t.index ["roster_id"], name: "index_roster_players_on_roster_id"
  end

  create_table "roster_snapshot_players", force: :cascade do |t|
    t.bigint "roster_snapshot_id", null: false
    t.bigint "player_id"
    t.integer "mlb_id", null: false
    t.string "full_name", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "jersey_number"
    t.string "position_code"
    t.string "position_name"
    t.string "status_code"
    t.string "status_description"
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mlb_id"], name: "index_roster_snapshot_players_on_mlb_id"
    t.index ["player_id"], name: "index_roster_snapshot_players_on_player_id"
    t.index ["roster_snapshot_id", "mlb_id"], name: "index_roster_snapshot_players_on_snapshot_and_mlb_id", unique: true
    t.index ["roster_snapshot_id"], name: "index_roster_snapshot_players_on_roster_snapshot_id"
  end

  create_table "roster_snapshots", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.integer "season", null: false
    t.string "roster_type", null: false
    t.date "snapshot_on", null: false
    t.string "source_name", default: "MLB Stats API", null: false
    t.string "source_url"
    t.datetime "last_synced_at", null: false
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["snapshot_on", "roster_type"], name: "index_roster_snapshots_on_snapshot_on_and_roster_type"
    t.index ["team_id", "snapshot_on", "roster_type"], name: "index_roster_snapshots_on_team_date_and_type", unique: true
    t.index ["team_id"], name: "index_roster_snapshots_on_team_id"
  end

  create_table "rosters", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.integer "season", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "roster_type", default: "40Man", null: false
    t.date "snapshot_on", null: false
    t.string "source_name", default: "derived_team_memberships", null: false
    t.datetime "last_synced_at", null: false
    t.jsonb "raw_data", default: {}, null: false
    t.index ["team_id", "season"], name: "index_rosters_on_team_id_and_season", unique: true
    t.index ["team_id"], name: "index_rosters_on_team_id"
  end

  create_table "saved_analyses", force: :cascade do |t|
    t.bigint "owner_id", null: false
    t.string "name", null: false
    t.string "analysis_type", null: false
    t.string "visibility", default: "private", null: false
    t.text "reproducible_url", null: false
    t.jsonb "state", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analysis_type", "visibility", "updated_at"], name: "idx_saved_analyses_discovery"
    t.index ["owner_id", "analysis_type", "name"], name: "idx_saved_analyses_owner_type_name", unique: true
    t.index ["owner_id"], name: "index_saved_analyses_on_owner_id"
  end

  create_table "schedules", force: :cascade do |t|
    t.integer "season", null: false
    t.string "schedule_type", default: "regular", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.string "source_name", null: false
    t.string "source_key", null: false
    t.string "source_url"
    t.datetime "last_synced_at", null: false
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["season", "schedule_type"], name: "index_schedules_on_season_and_schedule_type"
    t.index ["source_key"], name: "index_schedules_on_source_key", unique: true
    t.check_constraint "end_date >= start_date", name: "schedules_valid_date_range"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "stat_types", force: :cascade do |t|
    t.string "name", null: false
    t.string "label", null: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "category"], name: "index_stat_types_on_name_and_category", unique: true
  end

  create_table "tags", force: :cascade do |t|
    t.bigint "created_by_id", null: false
    t.string "name", null: false
    t.string "color", default: "#20543c", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_tags_on_lower_name", unique: true
    t.index ["created_by_id"], name: "index_tags_on_created_by_id"
  end

  create_table "team_daily_metrics", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.date "metric_date", null: false
    t.date "source_start_date", null: false
    t.date "source_end_date", null: false
    t.integer "sample_size", default: 0, null: false
    t.string "calculation_version", null: false
    t.datetime "calculated_at", null: false
    t.string "source_name", null: false
    t.jsonb "metrics", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calculated_at"], name: "idx_team_daily_metrics_calculated_at"
    t.index ["metric_date", "calculation_version"], name: "idx_on_metric_date_calculation_version_6b9dab98af"
    t.index ["team_id", "metric_date", "calculation_version"], name: "idx_team_daily_metrics_identity", unique: true
    t.index ["team_id"], name: "index_team_daily_metrics_on_team_id"
    t.check_constraint "sample_size >= 0", name: "team_daily_metrics_sample_size_nonnegative"
    t.check_constraint "source_end_date >= source_start_date", name: "team_daily_metrics_source_range_valid"
  end

  create_table "team_memberships", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "team_id", null: false
    t.date "starts_on", null: false
    t.date "ends_on"
    t.string "roster_status", null: false
    t.string "primary_position"
    t.jsonb "secondary_positions", default: [], null: false
    t.string "jersey_number"
    t.string "source_name", null: false
    t.datetime "last_synced_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source_status_code"
    t.string "source_status_description"
    t.string "source_url"
    t.jsonb "raw_data", default: {}, null: false
    t.index ["player_id", "team_id", "starts_on"], name: "index_team_memberships_on_player_team_start"
    t.index ["player_id"], name: "index_team_memberships_on_player_id"
    t.index ["roster_status"], name: "index_team_memberships_on_roster_status"
    t.index ["team_id", "starts_on", "ends_on"], name: "index_team_memberships_on_team_date_window"
    t.index ["team_id"], name: "index_team_memberships_on_team_id"
    t.check_constraint "ends_on IS NULL OR ends_on >= starts_on", name: "team_memberships_valid_date_range"
    t.exclusion_constraint "player_id WITH =, team_id WITH =, lower((roster_status)::text) WITH =, daterange(starts_on, COALESCE((ends_on + 1), 'infinity'::date), '[)'::text) WITH &&", using: :gist, name: "team_memberships_no_overlap_same_status"
  end

  create_table "teams", force: :cascade do |t|
    t.integer "mlb_id", null: false
    t.string "name", null: false
    t.string "abbreviation", null: false
    t.string "team_name", null: false
    t.string "location_name", null: false
    t.string "short_name", null: false
    t.string "team_code", null: false
    t.string "file_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mlb_id"], name: "index_teams_on_mlb_id", unique: true
  end

  create_table "trade_participants", force: :cascade do |t|
    t.bigint "trade_id", null: false
    t.bigint "player_id"
    t.bigint "player_mlb_id", null: false
    t.string "player_name", null: false
    t.bigint "from_team_id"
    t.bigint "to_team_id"
    t.integer "from_team_mlb_id"
    t.string "from_team_name"
    t.integer "to_team_mlb_id"
    t.string "to_team_name"
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_team_id"], name: "index_trade_participants_on_from_team_id"
    t.index ["player_id"], name: "index_trade_participants_on_player_id"
    t.index ["player_mlb_id"], name: "index_trade_participants_on_player_mlb_id"
    t.index ["to_team_id"], name: "index_trade_participants_on_to_team_id"
    t.index ["trade_id", "player_mlb_id"], name: "index_trade_participants_on_trade_id_and_player_mlb_id", unique: true
    t.index ["trade_id"], name: "index_trade_participants_on_trade_id"
  end

  create_table "trades", force: :cascade do |t|
    t.bigint "mlb_transaction_id", null: false
    t.date "occurred_on", null: false
    t.text "description", null: false
    t.string "source_name", null: false
    t.string "source_url"
    t.datetime "last_synced_at", null: false
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mlb_transaction_id"], name: "index_trades_on_mlb_transaction_id", unique: true
    t.index ["occurred_on"], name: "index_trades_on_occurred_on"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name", null: false
    t.string "role", default: "viewer", null: false
    t.string "password_salt"
    t.string "password_digest"
    t.string "auth_token_digest"
    t.datetime "last_signed_in_at"
    t.datetime "disabled_at"
    t.boolean "system_account", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "alert_digest_frequency", default: "off", null: false
    t.integer "alert_digest_day"
    t.integer "alert_digest_hour", default: 8, null: false
    t.index "lower((email)::text)", name: "idx_users_lower_email", unique: true
    t.index ["auth_token_digest"], name: "index_users_on_auth_token_digest", unique: true
    t.check_constraint "alert_digest_day IS NULL OR alert_digest_day >= 0 AND alert_digest_day <= 6", name: "users_valid_alert_digest_day"
    t.check_constraint "alert_digest_frequency::text = ANY (ARRAY['off'::character varying, 'daily'::character varying, 'weekly'::character varying]::text[])", name: "users_valid_alert_digest_frequency"
    t.check_constraint "alert_digest_hour >= 0 AND alert_digest_hour <= 23", name: "users_valid_alert_digest_hour"
    t.check_constraint "role::text = ANY (ARRAY['admin'::character varying::text, 'administrator'::character varying::text, 'analyst'::character varying::text, 'coach'::character varying::text, 'scout'::character varying::text, 'editor'::character varying::text, 'viewer'::character varying::text])", name: "users_valid_role"
  end

  create_table "watchlist_entries", force: :cascade do |t|
    t.bigint "watchlist_id", null: false
    t.bigint "player_id", null: false
    t.string "priority", default: "medium", null: false
    t.string "status", default: "scouting", null: false
    t.string "recommendation", default: "monitor", null: false
    t.integer "fit_score"
    t.integer "need_score"
    t.integer "cost_score"
    t.integer "risk_score"
    t.string "tags", default: [], null: false, array: true
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "calculated_fit_score", precision: 5, scale: 2
    t.jsonb "fit_breakdown", default: {}, null: false
    t.datetime "fit_calculated_at"
    t.bigint "candidate_owner_id"
    t.text "acquisition_rationale"
    t.decimal "estimated_cost", precision: 12, scale: 2
    t.string "availability", default: "unknown", null: false
    t.text "concerns"
    t.string "review_status", default: "initial_review", null: false
    t.index ["calculated_fit_score"], name: "index_watchlist_entries_on_calculated_fit_score"
    t.index ["candidate_owner_id"], name: "index_watchlist_entries_on_candidate_owner_id"
    t.index ["player_id"], name: "index_watchlist_entries_on_player_id"
    t.index ["watchlist_id", "player_id"], name: "index_watchlist_entries_on_watchlist_id_and_player_id", unique: true
    t.index ["watchlist_id"], name: "index_watchlist_entries_on_watchlist_id"
    t.check_constraint "calculated_fit_score IS NULL OR calculated_fit_score >= 0::numeric AND calculated_fit_score <= 100::numeric", name: "watchlist_entries_calculated_fit_range"
    t.check_constraint "cost_score IS NULL OR cost_score >= 1 AND cost_score <= 5", name: "watchlist_entries_cost_score_range"
    t.check_constraint "estimated_cost IS NULL OR estimated_cost >= 0::numeric", name: "watchlist_entries_estimated_cost_nonnegative"
    t.check_constraint "fit_score IS NULL OR fit_score >= 1 AND fit_score <= 5", name: "watchlist_entries_fit_score_range"
    t.check_constraint "need_score IS NULL OR need_score >= 1 AND need_score <= 5", name: "watchlist_entries_need_score_range"
    t.check_constraint "priority::text = ANY (ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying]::text[])", name: "watchlist_entries_valid_priority"
    t.check_constraint "recommendation::text = ANY (ARRAY['pursue'::character varying, 'monitor'::character varying, 'pass'::character varying]::text[])", name: "watchlist_entries_valid_recommendation"
    t.check_constraint "review_status::text = ANY (ARRAY['initial_review'::character varying, 'analyst_review'::character varying, 'scout_review'::character varying, 'medical_review'::character varying, 'discuss_internally'::character varying, 'contact_club_or_agent'::character varying, 'no_longer_pursuing'::character varying]::text[])", name: "watchlist_entries_valid_review_status"
    t.check_constraint "risk_score IS NULL OR risk_score >= 1 AND risk_score <= 5", name: "watchlist_entries_risk_score_range"
    t.check_constraint "status::text = ANY (ARRAY['scouting'::character varying, 'active'::character varying, 'paused'::character varying, 'closed'::character varying]::text[])", name: "watchlist_entries_valid_status"
  end

  create_table "watchlists", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "need_profile_id"
    t.bigint "owner_id"
    t.index ["name"], name: "index_watchlists_on_name", unique: true
    t.index ["need_profile_id"], name: "index_watchlists_on_need_profile_id"
    t.index ["owner_id"], name: "index_watchlists_on_owner_id"
  end

  add_foreign_key "admin_task_runs", "users", column: "initiated_by_id"
  add_foreign_key "admin_task_uploads", "admin_task_runs"
  add_foreign_key "alert_subscriptions", "players"
  add_foreign_key "alert_subscriptions", "users"
  add_foreign_key "alert_subscriptions", "watchlists"
  add_foreign_key "alerts", "alert_subscriptions"
  add_foreign_key "alerts", "player_trend_events"
  add_foreign_key "alerts", "users"
  add_foreign_key "alerts", "users", column: "assigned_to_id"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "batter_split_summaries", "players"
  add_foreign_key "batter_split_summaries", "teams"
  add_foreign_key "game_player_batting_lines", "games"
  add_foreign_key "game_player_batting_lines", "players"
  add_foreign_key "game_player_batting_lines", "teams"
  add_foreign_key "game_player_batting_lines", "teams", column: "opponent_team_id"
  add_foreign_key "game_player_pitching_lines", "games"
  add_foreign_key "game_player_pitching_lines", "players"
  add_foreign_key "game_player_pitching_lines", "teams"
  add_foreign_key "game_player_pitching_lines", "teams", column: "opponent_team_id"
  add_foreign_key "games", "players", column: "away_probable_pitcher_id"
  add_foreign_key "games", "players", column: "home_probable_pitcher_id"
  add_foreign_key "games", "schedules"
  add_foreign_key "games", "teams", column: "away_team_id"
  add_foreign_key "games", "teams", column: "home_team_id"
  add_foreign_key "lineup_entries", "games"
  add_foreign_key "lineup_entries", "players"
  add_foreign_key "lineup_entries", "teams"
  add_foreign_key "lineup_scenario_entries", "lineup_scenarios"
  add_foreign_key "lineup_scenario_entries", "players"
  add_foreign_key "lineup_scenarios", "teams"
  add_foreign_key "lineup_scenarios", "users", column: "owner_id"
  add_foreign_key "need_profiles", "teams"
  add_foreign_key "need_profiles", "users", column: "owner_id"
  add_foreign_key "note_revisions", "notes"
  add_foreign_key "note_revisions", "users", column: "editor_id"
  add_foreign_key "note_taggings", "notes"
  add_foreign_key "note_taggings", "tags"
  add_foreign_key "notes", "users", column: "author_id"
  add_foreign_key "notes", "users", column: "last_edited_by_id"
  add_foreign_key "opponent_reports", "teams"
  add_foreign_key "opponent_reports", "teams", column: "opponent_team_id"
  add_foreign_key "opponent_reports", "users", column: "owner_id"
  add_foreign_key "pitch_data", "games"
  add_foreign_key "pitch_data", "plate_appearances"
  add_foreign_key "pitcher_pitch_type_daily", "players"
  add_foreign_key "pitcher_pitch_type_daily", "teams"
  add_foreign_key "pitcher_split_summaries", "players"
  add_foreign_key "pitcher_split_summaries", "teams"
  add_foreign_key "plate_appearances", "games"
  add_foreign_key "plate_appearances", "players", column: "batter_id"
  add_foreign_key "plate_appearances", "players", column: "pitcher_id"
  add_foreign_key "plate_appearances", "teams", column: "batting_team_id"
  add_foreign_key "plate_appearances", "teams", column: "fielding_team_id"
  add_foreign_key "player_batting_daily", "players"
  add_foreign_key "player_batting_daily", "teams"
  add_foreign_key "player_contracts", "players"
  add_foreign_key "player_metric_percentiles", "league_metric_benchmarks"
  add_foreign_key "player_metric_percentiles", "players"
  add_foreign_key "player_pitching_daily", "players"
  add_foreign_key "player_pitching_daily", "teams"
  add_foreign_key "player_positions", "players"
  add_foreign_key "player_positions", "positions"
  add_foreign_key "player_profiles", "players"
  add_foreign_key "player_season_fielding_stats", "players"
  add_foreign_key "player_season_fielding_stats", "teams"
  add_foreign_key "player_season_stats", "players"
  add_foreign_key "player_season_stats", "stat_types"
  add_foreign_key "player_season_stats", "teams"
  add_foreign_key "player_trend_events", "players"
  add_foreign_key "players", "teams"
  add_foreign_key "roster_players", "players"
  add_foreign_key "roster_players", "rosters"
  add_foreign_key "roster_snapshot_players", "players"
  add_foreign_key "roster_snapshot_players", "roster_snapshots"
  add_foreign_key "roster_snapshots", "teams"
  add_foreign_key "rosters", "teams"
  add_foreign_key "saved_analyses", "users", column: "owner_id"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "tags", "users", column: "created_by_id"
  add_foreign_key "team_daily_metrics", "teams"
  add_foreign_key "team_memberships", "players"
  add_foreign_key "team_memberships", "teams"
  add_foreign_key "trade_participants", "players"
  add_foreign_key "trade_participants", "teams", column: "from_team_id"
  add_foreign_key "trade_participants", "teams", column: "to_team_id"
  add_foreign_key "trade_participants", "trades"
  add_foreign_key "watchlist_entries", "players"
  add_foreign_key "watchlist_entries", "users", column: "candidate_owner_id"
  add_foreign_key "watchlist_entries", "watchlists"
  add_foreign_key "watchlists", "need_profiles"
  add_foreign_key "watchlists", "users", column: "owner_id"
end
