import { flushPromises, shallowMount } from '@vue/test-utils'
import { describe, expect, it, vi } from 'vitest'

import App from '../App.vue'

const mocks = vi.hoisted(() => ({
  loadCurrentUser: vi.fn(),
  logout: vi.fn(() => Promise.resolve()),
  replace: vi.fn(() => Promise.resolve()),
  route: {
    name: 'watchlists',
    fullPath: '/watchlists?watchlist=7',
    meta: { requiresAuth: true },
  },
}))

vi.mock('../composables/useAuth', async () => {
  const { ref } = await import('vue')
  const user = ref({ name: 'Alex Scout', email: 'alex@example.com', role: 'scout' })

  return {
    useAuth: () => ({
      user,
      loadCurrentUser: mocks.loadCurrentUser,
      logout: mocks.logout,
    }),
  }
})

vi.mock('../composables/usePostseason', async () => {
  const { ref } = await import('vue')
  return {
    usePostseason: () => ({ postseason: ref({ active: false }), load: vi.fn() }),
  }
})

vi.mock('vue-router', () => ({
  useRoute: () => mocks.route,
  useRouter: () => ({ replace: mocks.replace }),
}))

describe('App', () => {
  it('renders a site-wide link to the project repository', () => {
    const wrapper = shallowMount(App, {
      global: { stubs: { RouterLink: true, RouterView: true } },
    })

    expect(wrapper.get('.app-footer a').attributes('href')).toBe('https://github.com/timothyf/ninelens')
  })

  it('leaves a protected route immediately when the user signs out', async () => {
    const wrapper = shallowMount(App, {
      global: {
        renderStubDefaultSlot: true,
        stubs: {
          RouterLink: true,
          RouterView: true,
        },
      },
    })

    await wrapper.get('.app-account__trigger').trigger('click')
    await wrapper.get('.app-account__menu button[role="menuitem"]').trigger('click')
    await flushPromises()

    expect(mocks.logout).toHaveBeenCalledOnce()
    expect(mocks.replace).toHaveBeenCalledWith({
      name: 'login',
      query: { redirect: '/watchlists?watchlist=7' },
    })
  })

  it('offers signed-in users an authenticated password-change screen', async () => {
    const wrapper = shallowMount(App, {
      global: {
        renderStubDefaultSlot: true,
        stubs: {
          RouterLink: true,
          RouterView: true,
        },
      },
    })

    await wrapper.get('.app-account__trigger').trigger('click')

    const changePasswordLink = wrapper.findAll('[role="menuitem"]')
      .find((item) => item.text() === 'Change password')
    expect(changePasswordLink).toBeTruthy()
  })

  it('uses mutually exclusive mobile navigation and search panels', async () => {
    const wrapper = shallowMount(App, {
      global: { stubs: { RouterLink: true, RouterView: true } },
    })

    await wrapper.get('button[aria-label="Open navigation"]').trigger('click')
    expect(wrapper.get('.app-navigation-shell').classes()).toContain('is-open')
    expect(wrapper.find('.app-mobile-scrim').exists()).toBe(true)

    await wrapper.get('button[aria-label="Search"]').trigger('click')
    expect(wrapper.get('.app-navigation-shell').classes()).not.toContain('is-open')
    expect(wrapper.get('.app-search-shell').classes()).toContain('is-open')

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))
    await wrapper.vm.$nextTick()
    expect(wrapper.get('.app-search-shell').classes()).not.toContain('is-open')
    expect(wrapper.find('.app-mobile-scrim').exists()).toBe(false)
  })

  it('shows Compare and Season Review under Tools after Teams', async () => {
    const wrapper = shallowMount(App, {
      global: {
        renderStubDefaultSlot: true,
        stubs: { RouterLink: true, RouterView: true },
      },
    })

    const nav = wrapper.get('.app-primary-nav')
    expect(nav.text()).toContain('Teams')
    expect(nav.text()).toContain('Tools')
    expect(nav.text().indexOf('Teams')).toBeLessThan(nav.text().indexOf('Tools'))
    expect(nav.text()).not.toContain('Player Compare')

    await nav.get('.app-tools__trigger').trigger('click')
    expect(nav.get('.app-tools__trigger').attributes('aria-expanded')).toBe('true')
    expect(nav.get('.app-tools__menu').text()).toBe('Player CompareSeason Review')

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))
    await wrapper.vm.$nextTick()
    expect(nav.find('.app-tools__menu').exists()).toBe(false)
  })
})
