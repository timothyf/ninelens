export const USER_TOKEN_STORAGE_KEY = 'ninelens_user_token'

export function authRequestHeaders(headers = {}) {
  let userToken = ''
  try {
    if (typeof localStorage !== 'undefined' && typeof localStorage.getItem === 'function') {
      userToken = localStorage.getItem(USER_TOKEN_STORAGE_KEY) || ''
    }
  } catch {
    userToken = ''
  }
  return userToken ? { ...headers, Authorization: `Bearer ${userToken}` } : headers
}

export function adminRequestHeaders(headers = {}) {
  return authRequestHeaders(headers)
}
