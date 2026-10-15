import { beforeEach, describe, expect, it, vi } from 'vitest'

const auth = vi.hoisted(() => ({
  currentUser: null,
  loadCurrentUser: vi.fn(async () => null),
}))

vi.mock('../../composables/useAuth', async () => {
  const { computed } = await import('vue')

  return {
    useAuth: () => ({
      user: computed(() => auth.currentUser),
      loadCurrentUser: auth.loadCurrentUser,
    }),
  }
})

import router from '../index'

describe('private workflow route guards', () => {
  beforeEach(async () => {
    auth.currentUser = null
    auth.loadCurrentUser.mockClear()
    await router.replace('/')
  })

  it.each([
    '/opponent-reports/42',
    '/lineup-scenarios/73',
  ])('redirects signed-out visitors from %s to sign in', async (path) => {
    await router.push(path)

    expect(router.currentRoute.value.name).toBe('login')
    expect(router.currentRoute.value.query).toEqual({ redirect: path })
  })
})
