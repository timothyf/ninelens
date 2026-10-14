# Changelog

All notable changes to NineLens are documented here.

## [Unreleased]

- Updates intended for the next release go here.

## [1.1.0] - 2026-10-14

### Added

- Expanded postseason coverage with postseason schedules, standings context, leaders, and player postseason statistics.
- Added player recent-game logs, salary and contract details, improved profile headers, and themed team profile pages.
- Added alert inboxes, configurable alert subscriptions, and alert-digest preferences.
- Added opponent-preparation reports and richer team, watchlist, acquisition, and lineup workflows.
- Added adjusted comparison weights, benchmark-aware player comparisons, and more detailed player and team analytics.
- Added production Docker Compose deployment with Caddy TLS termination, PostgreSQL, Solid Queue workers, health checks, persistent volumes, and deployment environment templates.
- Added an idempotent `users:bootstrap_admin` task for securely provisioning the first production administrator.

### Changed

- Improved administrator data-sync, import, task-launching, progress, data-health, and audit-history workflows.
- Centralized MLB Stats API access and strengthened data-import, roster, statistics, and postseason processing.
- Upgraded the backend runtime to Ruby 3.4.11 and declared Ruby 3.4 bundled dependencies explicitly.
- Improved browser and backend automated test coverage for task lifecycle, authentication, ownership, and production behavior.

### Security

- Disabled anonymous production registration; administrators now provision user accounts.
- Added login and registration throttling by IP address and account identifier.
- Replaced long-lived authentication tokens with expiring, revocable server-side session records.
- Increased password hashing work factors and transparently upgrades legacy hashes after successful sign-in.
- Require users with temporary or reset passwords to set a new password before accessing the application.
- Added an authenticated password-change screen, revoked other sessions after a password change, and narrowed administrative API-token enforcement to operational endpoints.
- Preserved role- and ownership-based permissions for authorized analyst, coach, scout, and viewer writes in production.

### Fixed

- Fixed pitch-data synchronization, team-profile behavior, postseason/data-health edge cases, and innings-to-outs calculations.
- Made the readiness endpoint database-aware for more reliable uptime monitoring.
- Stabilized the administrator task-lifecycle browser test by targeting the task-result panel directly.

## [1.0.0] - 2026-09-16

Initial public release.

### Included

- MLB schedules, games, standings, rosters, player profiles, and team profiles.
- Season statistics, Statcast exploration, trends, benchmarks, and comparisons.
- Saved analyses, notes, tags, watchlists, acquisition workflows, and lineup tools.
- Administrator workflows for data synchronization, imports, task monitoring, and data health.
- Rails API, Vue frontend, background jobs, and automated unit, request, service, and browser coverage.
