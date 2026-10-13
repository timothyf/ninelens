function numberSetting(rawValue, fallback) {
  const value = Number(rawValue)
  return Number.isFinite(value) && value >= 0 ? value : fallback
}

export const frontendConfig = Object.freeze({
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL || '',
  pollingIntervalMs: numberSetting(import.meta.env.VITE_POLL_INTERVAL_MS, 1500),
  searchDebounceMs: numberSetting(import.meta.env.VITE_SEARCH_DEBOUNCE_MS, 250),
  playerSuggestionDebounceMs: numberSetting(import.meta.env.VITE_PLAYER_SUGGESTION_DEBOUNCE_MS, 180),
  playerSearchLimit: numberSetting(import.meta.env.VITE_PLAYER_SEARCH_LIMIT, 8),
  teamSearchLimit: numberSetting(import.meta.env.VITE_TEAM_SEARCH_LIMIT, 8),
  playerSuggestionLimit: numberSetting(import.meta.env.VITE_PLAYER_SUGGESTION_LIMIT, 8),
  comparisonPlayerLimit: numberSetting(import.meta.env.VITE_COMPARISON_PLAYER_LIMIT, 6),
  adminProfileBatchSize: numberSetting(import.meta.env.VITE_ADMIN_PROFILE_BATCH_SIZE, 50),
  defaultPitchDataPerPage: numberSetting(import.meta.env.VITE_DEFAULT_PITCH_DATA_PER_PAGE, 20),
  defaultStatsPerPage: numberSetting(import.meta.env.VITE_DEFAULT_STATS_PER_PAGE, 15),
  externalUrls: Object.freeze({
    mlbStaticBaseUrl: import.meta.env.VITE_MLB_STATIC_BASE_URL || 'https://www.mlbstatic.com',
    mlbHeadshotBaseUrl: import.meta.env.VITE_MLB_HEADSHOT_BASE_URL || 'https://img.mlbstatic.com',
    mlbPlayerBaseUrl: import.meta.env.VITE_MLB_PLAYER_BASE_URL || 'https://www.mlb.com/player',
    mlbTeamBaseUrl: import.meta.env.VITE_MLB_TEAM_BASE_URL || 'https://www.mlb.com',
    fangraphsBaseUrl: import.meta.env.VITE_FANGRAPHS_BASE_URL || 'https://www.fangraphs.com/players',
    fangraphsLegacyUrl: import.meta.env.VITE_FANGRAPHS_LEGACY_URL || 'https://www.fangraphs.com/players.aspx',
    baseballReferenceBaseUrl: import.meta.env.VITE_BASEBALL_REFERENCE_BASE_URL || 'https://www.baseball-reference.com/players',
    baseballReferenceSearchUrl: import.meta.env.VITE_BASEBALL_REFERENCE_SEARCH_URL || 'https://www.baseball-reference.com/search/search.fcgi',
    baseballSavantPlayerBaseUrl: import.meta.env.VITE_BASEBALL_SAVANT_PLAYER_BASE_URL || 'https://baseballsavant.mlb.com/savant-player',
    baseballSavantTeamBaseUrl: import.meta.env.VITE_BASEBALL_SAVANT_TEAM_BASE_URL || 'https://baseballsavant.mlb.com/team',
    baseballReferenceTeamBaseUrl: import.meta.env.VITE_BASEBALL_REFERENCE_TEAM_BASE_URL || 'https://www.baseball-reference.com/teams',
    fangraphsTeamBaseUrl: import.meta.env.VITE_FANGRAPHS_TEAM_BASE_URL || 'https://www.fangraphs.com/teams',
  }),
})

export const API_BASE_URL = frontendConfig.apiBaseUrl

export function teamLogoUrl(mlbId) {
  return `${frontendConfig.externalUrls.mlbStaticBaseUrl}/team-logos/${mlbId}.svg`
}
