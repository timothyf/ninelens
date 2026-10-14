import { flushPromises, mount } from '@vue/test-utils'
import { createMemoryHistory, createRouter } from 'vue-router'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import LoginView from '../LoginView.vue'

async function mountLogin(initialPath) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', name: 'home', component: { template: '<div>Home</div>' } },
      { path: '/login', name: 'login', component: LoginView },
      { path: '/change-password', name: 'change-password', component: { template: '<div>Change password</div>' } },
      { path: '/explore', name: 'stat-explorer', component: { template: '<div>Explore</div>' } },
    ],
  })
  await router.push(initialPath)
  await router.isReady()
  const wrapper = mount(LoginView, { global: { plugins: [router] } })
  return { wrapper, router }
}

describe('LoginView', () => {
  beforeEach(() => {
    const storage = new Map()
    vi.stubGlobal('localStorage', {
      getItem: (key) => storage.get(key) || null,
      setItem: (key, value) => storage.set(key, String(value)),
      removeItem: (key) => storage.delete(key),
      clear: () => storage.clear(),
    })
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('offers local account bootstrap outside production builds', async () => {
    const { wrapper } = await mountLogin('/login')

    expect(wrapper.get('.login-switch').text()).toBe('Create the first workspace account')
  })

  it('returns to the page supplied by the sign-in redirect', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ data: { token: 'session-token', name: 'Scout' } }),
    }))
    const { wrapper, router } = await mountLogin('/login?redirect=/explore%3Fcategory%3Dpitching')

    await wrapper.get('input[type="email"]').setValue('scout@example.com')
    await wrapper.get('input[type="password"]').setValue('password123')
    await wrapper.get('form').trigger('submit')
    await flushPromises()

    expect(router.currentRoute.value.fullPath).toBe('/explore?category=pitching')
  })

  it('falls back to home for an unsafe external redirect', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ data: { token: 'session-token', name: 'Scout' } }),
    }))
    const { wrapper, router } = await mountLogin('/login?redirect=//example.com')

    await wrapper.get('input[type="email"]').setValue('scout@example.com')
    await wrapper.get('input[type="password"]').setValue('password123')
    await wrapper.get('form').trigger('submit')
    await flushPromises()

    expect(router.currentRoute.value.fullPath).toBe('/')
  })

  it('sends a user with a temporary password to the required replacement page', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ data: { token: 'session-token', name: 'Scout', password_change_required: true } }),
    }))
    const { wrapper, router } = await mountLogin('/login?redirect=/explore')

    await wrapper.get('input[type="email"]').setValue('scout@example.com')
    await wrapper.get('input[type="password"]').setValue('temporary-password')
    await wrapper.get('form').trigger('submit')
    await flushPromises()

    expect(router.currentRoute.value.fullPath).toBe('/change-password?redirect=/explore')
  })
})
