import { apiUrl } from '../config'

describe('apiUrl', () => {
  it('keeps same-origin API paths when no API origin is configured', () => {
    expect(apiUrl('/api/teams')).toBe('/api/teams')
  })

  it('uses the configured API origin without adding a double slash', async () => {
    vi.stubEnv('VITE_API_BASE_URL', 'https://api.example.com/')
    vi.resetModules()
    try {
      const { apiUrl: configuredApiUrl } = await import('../config')
      expect(configuredApiUrl('/api/teams/1/lineup_scenarios'))
        .toBe('https://api.example.com/api/teams/1/lineup_scenarios')
    } finally {
      vi.unstubAllEnvs()
    }
  })
})
