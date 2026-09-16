# NineLens Frontend

The frontend is a Vue 3 single-page application for the NineLens baseball intelligence workspace. It uses Vue Router, Vite, and the Rails API in `../backend`.

## Requirements

- Node.js 20.19+ or 22.12+
- A running NineLens Rails API (normally `http://127.0.0.1:3000`)

## Local development

```sh
npm install
npm run dev
```

Vite proxies `/api` to `http://127.0.0.1:3000` by default. Point the development proxy to another Rails API with:

```sh
VITE_DEV_API_TARGET=http://127.0.0.1:3001 npm run dev
```

When serving the app without the development proxy, set the API origin directly:

```sh
VITE_API_BASE_URL=https://api.example.com npm run dev
```

## Commands

```sh
npm run dev       # start Vite with hot reload
npm run build     # produce a production build in dist/
npm run preview   # serve the production build locally
npm test          # run Vitest in watch mode
npm run test:run  # run the full Vitest suite once
npm run test:e2e  # run Playwright browser tests against the Rails test database
```

## End-to-end browser tests

Playwright starts an isolated Rails server in the `test` environment on port 3001 and Vite on port 4173. It uses a dedicated PID file, so it can run while the normal development Rails server is running. Before each run it prepares and resets the Rails test database, then upserts dedicated test accounts and scenario data. The database is reset again after the run so E2E data cannot leak into RSpec or a later run:

- `e2e.viewer@ninelens.test`
- `e2e.admin@ninelens.test`

The initial suite covers sign-in, the authenticated Watchlists route, and viewer versus administrator access to `/admin`. Install the Chromium browser once before the first run:

```sh
npx playwright install chromium
npm run test:e2e
```

Set `E2E_BASE_URL` to run the tests against already-running servers; that mode does not start local servers.

## Application areas

- Home dashboard with daily schedule, league leaders, league filter, and team pulse
- Schedule, standings, Stat Explorer, and pitch-data exploration
- Player profiles, advanced statistics, trends, notes, and saved analyses
- Two- or three-player comparison with season/career alignment, overall weighted scores, per-at-bat normalization for batting counting statistics, and user-adjustable Settings; retired-player comparisons show career totals only
- Team directory and Team Profiles, including all-MLB Hitting/Pitching Team Stats
- Game summaries with box score, MLB-style detail notes, official MLB game ID in the header, pitching, batted-ball, situational, and play-by-play views
- Signed-in watchlists, opponent reports, lineup scenarios, and saved analyses
- Administrator-only synchronization, imports, task monitoring, and data-health workflows

## Routes

- `/` — Home dashboard
- `/schedule` — schedule browser
- `/standings` — standings
- `/explore` — Stat Explorer (`/stat-board` redirects here)
- `/games/:id` — Game Summary
- `/players/:id` — Player Profile
- `/compare` — Player Comparison
- `/saved/:id` — saved-analysis redirect
- `/teams` and `/teams/:id` — team directory and Team Profile
- `/watchlists` — authenticated watchlists
- `/admin` — administrator workspace
- `/login` — authentication

## Runtime configuration

`src/config.js` centralizes defaults. Vite environment variables can override:

- `VITE_API_BASE_URL` and `VITE_DEV_API_TARGET`
- `VITE_ADMIN_API_TOKEN`
- polling, debounce, page-size, and search-limit settings
- MLB, FanGraphs, Baseball Reference, and Baseball Savant URL bases used for outbound links and assets

`VITE_ADMIN_API_TOKEN` must match the backend `ADMIN_API_TOKEN` when using admin imports or task controls with system-token authentication. Signed-in administrator sessions can also authorize those controls.

## Project structure

- `src/views/` — route-level screens
- `src/components/` — reusable UI, tables, pickers, and Admin controls
- `src/composables/` — API access, state, authentication, and workflow logic
- `src/router/` — routes and access guards
- `src/utils/` — display formatting and UI helpers
- `src/**/__tests__/` — Vitest component, composable, utility, and view tests

See the repository [README](../README.md) for the backend workflow, API overview, and full feature inventory.
