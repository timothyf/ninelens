import { computed, ref } from 'vue'

import { USER_TOKEN_STORAGE_KEY } from './apiAuth'
import { API_BASE_URL } from '../config'
const user = ref(null)
const loading = ref(false)
const error = ref('')

async function request(path, options = {}) {
  const response = await fetch(`${API_BASE_URL}${path}`, options)
  const payload = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(payload?.message || 'Authentication request failed.')
  return payload?.data
}

export function useAuth() {
  async function login(email, password) {
    loading.value = true
    error.value = ''
    try {
      const session = await request('/api/auth/login', {
        method: 'POST',
        headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      })
      localStorage.setItem(USER_TOKEN_STORAGE_KEY, session.token)
      user.value = session
      return session
    } catch (requestError) {
      error.value = requestError.message
      throw requestError
    } finally {
      loading.value = false
    }
  }

  async function register(name, email, password) {
    loading.value = true
    error.value = ''
    try {
      const session = await request('/api/auth/register', {
        method: 'POST',
        headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, email, password }),
      })
      localStorage.setItem(USER_TOKEN_STORAGE_KEY, session.token)
      user.value = session
      return session
    } catch (requestError) {
      error.value = requestError.message
      throw requestError
    } finally {
      loading.value = false
    }
  }

  async function loadCurrentUser() {
    const token = localStorage.getItem(USER_TOKEN_STORAGE_KEY)
    if (!token) return null
    try {
      user.value = await request('/api/auth/me', { headers: { Accept: 'application/json', Authorization: `Bearer ${token}` } })
    } catch (_error) {
      localStorage.removeItem(USER_TOKEN_STORAGE_KEY)
      user.value = null
    }
    return user.value
  }

  async function changePassword(currentPassword, password, passwordConfirmation) {
    loading.value = true
    error.value = ''
    try {
      const token = localStorage.getItem(USER_TOKEN_STORAGE_KEY)
      const updatedUser = await request('/api/auth/password', {
        method: 'PATCH',
        headers: {
          Accept: 'application/json',
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          current_password: currentPassword,
          password,
          password_confirmation: passwordConfirmation,
        }),
      })
      user.value = updatedUser
      return updatedUser
    } catch (requestError) {
      error.value = requestError.message
      throw requestError
    } finally {
      loading.value = false
    }
  }

  async function logout() {
    const token = localStorage.getItem(USER_TOKEN_STORAGE_KEY)
    localStorage.removeItem(USER_TOKEN_STORAGE_KEY)
    user.value = null
    if (token) await request('/api/auth/logout', { method: 'DELETE', headers: { Authorization: `Bearer ${token}` } }).catch(() => {})
  }

  return { user: computed(() => user.value), loading, error, login, register, loadCurrentUser, changePassword, logout }
}
