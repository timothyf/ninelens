import { flushPromises, mount } from '@vue/test-utils'
import { createMemoryHistory, createRouter } from 'vue-router'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import ChangePasswordView from '../ChangePasswordView.vue'

async function mountView(initialPath = '/change-password') {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', name: 'home', component: { template: '<div>Home</div>' } },
      { path: '/change-password', name: 'change-password', component: ChangePasswordView },
      { path: '/watchlists', name: 'watchlists', component: { template: '<div>Watchlists</div>' } },
    ],
  })
  await router.push(initialPath)
  await router.isReady()
  return { wrapper: mount(ChangePasswordView, { global: { plugins: [router] } }), router }
}

describe('ChangePasswordView', () => {
  beforeEach(() => {
    const storage = new Map([['ninelens_user_token', 'session-token']])
    vi.stubGlobal('localStorage', {
      getItem: (key) => storage.get(key) || null,
      setItem: (key, value) => storage.set(key, String(value)),
      removeItem: (key) => storage.delete(key),
    })
  })

  afterEach(() => vi.unstubAllGlobals())

  it('replaces the temporary password and returns to the requested page', async () => {
    const fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ data: { id: 1, password_change_required: false } }),
    })
    vi.stubGlobal('fetch', fetch)
    const { wrapper, router } = await mountView('/change-password?redirect=/watchlists')

    const fields = wrapper.findAll('input[type="password"]')
    await fields[0].setValue('temporary-password-123')
    await fields[1].setValue('replacement-password-456')
    await fields[2].setValue('replacement-password-456')
    await wrapper.get('form').trigger('submit')
    await flushPromises()

    expect(fetch).toHaveBeenCalledWith(expect.stringContaining('/api/auth/password'), expect.objectContaining({
      method: 'PATCH',
      body: JSON.stringify({
        current_password: 'temporary-password-123',
        password: 'replacement-password-456',
        password_confirmation: 'replacement-password-456',
      }),
    }))
    expect(router.currentRoute.value.fullPath).toBe('/watchlists')
  })
})
