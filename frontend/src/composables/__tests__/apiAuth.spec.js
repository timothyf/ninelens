import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  adminRequestHeaders,
  authRequestHeaders,
  USER_TOKEN_STORAGE_KEY,
} from '../apiAuth'

describe('API authentication headers', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('uses the signed-in user session for administrator requests', () => {
    vi.stubGlobal('localStorage', {
      getItem: (key) => key === USER_TOKEN_STORAGE_KEY ? 'signed-in-user-token' : null,
    })

    expect(adminRequestHeaders({ Accept: 'application/json' })).toEqual({
      Accept: 'application/json',
      Authorization: 'Bearer signed-in-user-token',
    })
  })

  it('does not add authorization when there is no signed-in session', () => {
    vi.stubGlobal('localStorage', { getItem: () => null })

    expect(authRequestHeaders({ Accept: 'application/json' })).toEqual({
      Accept: 'application/json',
    })
  })

  it('fails closed when browser storage cannot be read', () => {
    vi.stubGlobal('localStorage', {
      getItem: () => {
        throw new Error('Storage is unavailable')
      },
    })

    expect(adminRequestHeaders()).toEqual({})
  })
})
