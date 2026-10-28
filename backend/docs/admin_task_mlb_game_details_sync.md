# Admin task: MLB game detail synchronization

`mlb_game_details_sync` selects **existing** games by MLB game ID or by an inclusive official-date range. A date-range run excludes cancelled games and unplayed conditional postseason games. It downloads a box score and live feed for each selected game. A game must already exist in `games`; this task does not create a game or schedule.

## Direct game-detail writes

```mermaid
flowchart TB
    A["Admin starts game detail sync"] --> AUD["audit_logs — INSERT<br/>user_id, action = import_started<br/>auditable_type, auditable_id<br/>metadata: task_name and submitted parameters"]
    A --> RUN["admin_task_runs — INSERT then UPDATE<br/>task_name, task_parameters, initiated_by_id<br/>status: queued → running → completed / failed / cancelled<br/>total_items, completed_items, failed_items<br/>current_item_mlb_id, current_item_label<br/>started_at, last_heartbeat_at, finished_at<br/>remaining_time_anchor_at, result_data, error_message"]
    RUN --> Q["Solid Queue — enqueue MlbGameDetailsSyncJob"]
    Q --> SEL["Select stored games; fetch box score and live feed per game"]

    subgraph TX["One transaction per successfully downloaded game"]
      direction TB
      G["games — UPDATE existing row<br/>official_date, scheduled_at, status, detailed_status<br/>home_score, away_score, game_number, doubleheader<br/>details_source_url, details_last_synced_at<br/>boxscore_raw_data, live_feed_raw_data"]
      P["players — INSERT only if MLB ID is new<br/>mlb_id, first_name, last_name, team_id<br/>existing player rows unchanged"]
      B["game_player_batting_lines — UPSERT by game_id + player_id<br/>team_id, opponent_team_id, home, starter, batting_order, position<br/>plate_appearances, at_bats, runs, hits, doubles, triples, home_runs<br/>runs_batted_in, walks, strikeouts, stolen_bases, caught_stealing<br/>batting_average, on_base_percentage, slugging_percentage, ops<br/>source_name, source_url, last_synced_at, raw_data"]
      PI["game_player_pitching_lines — UPSERT by game_id + player_id<br/>team_id, opponent_team_id, home, starter, appearance_order<br/>innings_pitched, outs_recorded, batters_faced, hits, runs<br/>earned_runs, home_runs, walks, strikeouts, pitches, strikes<br/>era, whip, decision, holds, saves, blown_saves<br/>source_name, source_url, last_synced_at, raw_data"]
      L["lineup_entries — UPSERT by game_id + team_id + player_id<br/>batting_order, batting_slot, starter, position<br/>all_positions, substitutions<br/>source_name, source_url, last_synced_at, raw_data"]
      PA["plate_appearances — UPSERT by game_id + at_bat_index<br/>plate_appearance_number, batter_id, pitcher_id<br/>batting_team_id, fielding_team_id, inning, half_inning<br/>event, event_type, description, runs_batted_in<br/>away_score, home_score, outs_after, complete<br/>started_at, ended_at, source_name, source_url<br/>last_synced_at, raw_data"]
      PD["pitch_data — UPDATE existing matching pitches only<br/>game_id, plate_appearance_id, updated_at"]
      G --> P
      P --> B
      P --> PI
      P --> L
      P --> PA
      PA --> PD
    end

    SEL -->|valid response| G
    SEL -->|download fails| ERR["Record failed game in admin_task_runs"]
    B -->|authoritative batter list| DELB["DELETE stale batting lines for that game and side"]
    PI -->|authoritative pitcher list| DELP["DELETE stale pitching lines for that game and side"]
    TX -->|import error: roll back this game| ERR
    TX -->|commit: record success and date| DER["Refresh derived analytics for successful dates"]
```

The importer updates each selected `games` row with live-feed status, timing, scores, and raw responses. Missing live-feed values usually preserve the prior schedule values for dates, scores, game number, and doubleheader flag. The `games` schedule and team links are unchanged.

Players are created from box-score participants and plate-appearance batter/pitcher identities when absent. Existing `players` rows are not refreshed. Batting and pitching lines are deleted when the newer box score supplies an authoritative `batters` or `pitchers` ID list that omits them. `lineup_entries` and `plate_appearances` are upserted but not pruned when missing from a later response. Existing `pitch_data` rows are linked by `game_pk` and `at_bat_number`; pitch values are not downloaded or replaced here.

All direct writes for one game are in one transaction. A failed game does not roll back other games in the batch. Rails also sets `created_at` on inserted rows and refreshes `updated_at` for changed rows.

## Automatic downstream writes

After the game workers finish, the task calls `DailyAnalyticsRefresh` for the distinct official dates of **successfully** synchronized games. This is a separate stage; analytics failure does not undo the game-detail imports. No analytics refresh runs if no game synced successfully.

```mermaid
flowchart TB
    D["Successful game dates"] --> CALC["DailyAnalyticsCalculator<br/>For each date + calculation_version:<br/>DELETE prior rows, then INSERT recalculated rows"]
    CALC --> BD["player_batting_daily<br/>player_id, team_id + common columns + metrics"]
    CALC --> PT["player_pitching_daily<br/>player_id, team_id + common columns + metrics"]
    CALC --> PP["pitcher_pitch_type_daily<br/>player_id, team_id, pitch_type, pitch_name<br/>+ common columns + metrics"]
    CALC --> BS["batter_split_summaries<br/>player_id, team_id, split_type, split_value<br/>+ common columns + metrics"]
    CALC --> PS["pitcher_split_summaries<br/>player_id, team_id, split_type, split_value<br/>+ common columns + metrics"]
    CALC --> TM["team_daily_metrics<br/>team_id + common columns + metrics"]
    CALC --> TREND["player_trend_events — INSERT / UPDATE / resolve<br/>identity and metric fields, baseline/current values and dates<br/>sample sizes, thresholds, evidence, status, observed times"]
    TREND --> ALERT["alerts — conditional INSERT / UPDATE / resolve<br/>user_id, player_trend_event_id, alert_subscription_id<br/>supporting_evidence, links, status, resolved_at"]
    ALERT --> RUN["admin_task_runs — final status and result_data"]
```

The six summary tables share these populated columns: `metric_date`, `source_start_date`, `source_end_date`, `sample_size`, `calculation_version`, `calculated_at`, `source_name`, `metrics`, `created_at`, and `updated_at`. The table-specific identity columns are shown in the diagram. Their `metrics` JSON contains the calculated statistics. The refresh replaces rows for each successful date and calculation version, including deleting prior rows when the new calculation produces none.

Trend-event refresh looks up players represented in stored `pitch_data` on those dates. It can create, update, or resolve `player_trend_events`; matching alert subscriptions can cause `alerts` inserts or evidence/link updates, and resolving a trend can resolve its alerts. These writes are conditional on trend detection and subscriptions. This game-detail task calls analytics with `refresh_contextual_benchmarks: false`, so it does not run the contextual benchmark refresh.

| Conditional table | Columns populated or changed |
| --- | --- |
| `player_trend_events` | On creation: `player_id`, `identity_key`, `event_type`, `role`, `metric_key`, `pitch_type`, `direction`, `severity`, `status`, `unit`, `baseline_value`, `current_value`, `change_value`, `threshold_value`, `baseline_sample_size`, `sample_size`, `baseline_start_date`, `baseline_end_date`, `current_start_date`, `current_end_date`, `onset_date`, `detected_at`, `last_observed_at`, `calculation_version`, `thresholds`, `supporting_pitches`, `metadata`. Existing active events refresh candidate fields and `last_observed_at`; resolution changes `status`, `resolved_at`, and `last_observed_at`. |
| `alerts` | For matching subscriptions, a new row gets `user_id`, `player_trend_event_id`, `alert_subscription_id`, `supporting_evidence`, `links`, and default `status = active`. Existing rows can update `alert_subscription_id`, `supporting_evidence`, and `links`. Trend resolution changes `status` to `resolved` and sets `resolved_at`. |

The Admin launch also inserts an `audit_logs` entry and uses Solid Queue tables to process the job. `admin_task_runs` tracks progress per game and stores the final counts, errors, and analytics result. The task clears the home snapshot cache after at least one game sync; that cache operation is outside the database writes shown here.

## Code references

- Admin launch and tracking: `app/controllers/api/admin/tasks_controller.rb`, `app/services/mlb_game_details_task_launcher.rb`, `app/jobs/mlb_game_details_sync_job.rb`, `app/services/mlb_game_details_progress_tracker.rb`
- Game selection and import: `app/services/mlb_game_details_batch_sync.rb`, `app/services/mlb_game_details_downloader.rb`, `app/services/mlb_game_details_importer.rb`
- Derived data: `app/services/daily_analytics_refresh.rb`, `app/services/daily_analytics_calculator.rb`, `app/services/player_trend_event_refresh.rb`, `app/services/alert_inbox_sync.rb`
