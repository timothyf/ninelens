export const teamThemes = Object.freeze({
  108: { primary: '#ba0021', secondary: '#003263', accent: '#ff5910' }, 109: { primary: '#a71930', secondary: '#2c2c2c', accent: '#e3d4ad' },
  110: { primary: '#df4601', secondary: '#27251f', accent: '#f5a623' }, 111: { primary: '#bd3039', secondary: '#0c2340', accent: '#c4ced4' },
  112: { primary: '#c41e3a', secondary: '#0c2340', accent: '#d4af37' }, 113: { primary: '#c6011f', secondary: '#000000', accent: '#ffffff' },
  114: { primary: '#003b70', secondary: '#e31937', accent: '#ffffff' }, 115: { primary: '#ba0021', secondary: '#003263', accent: '#ff5910' },
  116: { primary: '#0c2340', secondary: '#fa4616', accent: '#c4ced4' }, 117: { primary: '#002d62', secondary: '#d50032', accent: '#ffffff' },
  118: { primary: '#ce1141', secondary: '#000000', accent: '#ffffff' }, 119: { primary: '#005a9c', secondary: '#ef3340', accent: '#c4ced4' },
  120: { primary: '#041e42', secondary: '#ba0c2f', accent: '#ffffff' }, 121: { primary: '#002d72', secondary: '#ff5910', accent: '#ffffff' },
  133: { primary: '#003831', secondary: '#ffb81c', accent: '#ffffff' }, 134: { primary: '#27251f', secondary: '#ffb81c', accent: '#ffffff' },
  135: { primary: '#2f241d', secondary: '#ffc425', accent: '#ffffff' }, 136: { primary: '#0c2340', secondary: '#005c5c', accent: '#c4ced4' },
  137: { primary: '#fd5a1e', secondary: '#27251f', accent: '#ffffff' }, 138: { primary: '#c41e3a', secondary: '#0c2340', accent: '#ffcc00' },
  139: { primary: '#092c5c', secondary: '#8fbce6', accent: '#ffffff' }, 140: { primary: '#003278', secondary: '#c0111f', accent: '#ffffff' },
  141: { primary: '#134a8e', secondary: '#1d2d5c', accent: '#e8291c' }, 142: { primary: '#002b5c', secondary: '#d31145', accent: '#ffffff' },
  143: { primary: '#e81828', secondary: '#002d72', accent: '#ffffff' }, 144: { primary: '#ce1141', secondary: '#13274f', accent: '#eaaa00' },
  145: { primary: '#27251f', secondary: '#c4ced4', accent: '#ffffff' }, 146: { primary: '#00a3e0', secondary: '#ef3340', accent: '#000000' },
  147: { primary: '#0c2340', secondary: '#c4ced4', accent: '#ffffff' }, 158: { primary: '#005c5c', secondary: '#e87429', accent: '#ffffff' },
})

export const defaultTeamTheme = Object.freeze({ primary: '#173652', secondary: '#315b7d', accent: '#e8b276' })

export function teamThemeStyle(teamId) {
  const theme = teamThemes[Number(teamId)] || defaultTeamTheme
  return {
    '--profile-team-primary': theme.primary,
    '--profile-team-secondary': theme.secondary,
    '--profile-team-accent': theme.accent,
  }
}
