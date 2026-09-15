# NineLens Backend

The backend is a Rails 7.1 JSON API backed by PostgreSQL. It stores normalized MLB schedules, games, rosters, player profiles, season statistics, Statcast pitches, derived analytics, saved analyses, notes, and user-owned scouting workflows.

## Requirements

- Ruby 3.2.3 (see `.ruby-version`)
- PostgreSQL
- Bundler

## Local setup

```sh
bundle install
bin/rails db:prepare
bin/rails server
```

The development API listens on `http://127.0.0.1:3000` by default. `db:prepare` creates the development database when needed and applies migrations. After pulling schema changes, use `bin/rails db:migrate` before starting the API.

Development Puma starts Solid Queue automatically. In production, start the queue worker separately:

```sh
bin/jobs start
```

Alternatively, set `SOLID_QUEUE_IN_PUMA=1` to run the worker in Puma.

## Configuration

Operational defaults and external-service endpoints are in `config/ninelens.yml` and are available through `Rails.application.config.x.ninelens`. Every configured external URL, timeout, sync-worker limit, retry setting, and task estimate can be overridden with an environment variable.

Database credentials use standard Rails configuration. `DATABASE_URL` takes precedence when supplied; production also supports `BACKEND_DATABASE_PASSWORD` through `config/database.yml`.

`ADMIN_API_TOKEN` protects unsafe operational API requests when configured. In production, unsafe requests fail closed unless the token is set. Send it as either `Authorization: Bearer <token>` or `X-Admin-Token: <token>`.

## Common data workflows

Most imports and synchronization jobs can be launched from the Admin page, which persists progress in Solid Queue task runs. The same operations are available from the command line:

```sh
# Schedule and game details
bin/rails 'mlb_schedule:sync[2026-04-01,2026-04-30]'
bin/rails 'mlb_game_details:sync[2026-04-01,2026-04-07]'

# Player season statistics and Statcast pitch data
bin/rails 'player_stats:download[batting,2026,2026]'
bin/rails 'player_stats:download[pitching,2026,2026]'
bin/rails 'pitch_data:download[2026-04-01,2026-04-07]'

# Roster snapshots and player profiles
bin/rails 'mlb_roster:sync[116,2026]'
bin/rails 'mlb_roster_snapshots:sync[116,2026-07-15]'
bin/rails mlb_player_profiles:sync

# Derived analytics and cached benchmarks
bin/rails 'daily_analytics:refresh[2026-04-01,2026-04-30]'
bin/rails 'contextual_benchmarks:refresh[2026-04-01,2026-04-30]'
```

Run the complete dated in-season sequence with:

```sh
DATE=2026-08-13 bin/rails daily_in_season:sync
```

Run the same integrity checks used by the Admin data-health report with:

```sh
bin/rails db_health:check
```

For a real-data development bootstrap covering April-May 2025 and April-May 2026:

```sh
DRY_RUN=1 bin/rails sample_data:bootstrap
bin/rails sample_data:bootstrap
```

See [sample-data instructions](docs/sample_data.md) and [roster synchronization details](docs/roster_sync.md) for available controls and model contracts.

## Testing

```sh
bundle exec rspec
```

The suite covers models, queries, services, requests, jobs, and authorization. Run a focused spec with, for example:

```sh
bundle exec rspec spec/requests/api/home_spec.rb
```

## API and project structure

`config/routes.rb` is the source of truth for endpoints. The API includes public baseball data such as `/api/home`, `/api/players`, `/api/teams`, `/api/standings`, `/api/games`, and `/api/player_season_stats`, plus authenticated resources for notes, saved analyses, watchlists, lineups, opponent reports, and administration.

Game detail responses include the official `mlb_id`, MLB-style batting and pitching notes, situational analysis, and the normalized box-score, play-by-play, and pitch-analysis data consumed by the frontend.

- `app/controllers/api/` — JSON endpoints and authorization boundaries
- `app/queries/` — read models for profiles, dashboards, leaderboards, and reports
- `app/services/` — MLB/Statcast synchronization, imports, and business operations
- `app/jobs/` — persisted background work
- `app/models/` — normalized baseball and workspace records
- `lib/tasks/` — repeatable Rake workflows
- `spec/` — RSpec coverage

See the repository [README](../README.md) for the full API overview, frontend setup, and end-to-end workflow.
