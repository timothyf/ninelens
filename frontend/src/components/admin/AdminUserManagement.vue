<script setup>
import { onMounted, reactive } from 'vue'

import { useAdminUsers } from '../../composables/useAdminUsers'
import { formatTimestamp } from '../../utils/adminFormatting'

const {
  users,
  roles,
  summary,
  loading,
  error,
  actionUserId,
  creating,
  temporaryAccess,
  loadUsers,
  createUser,
  updateUser,
  resetAccess,
  clearTemporaryAccess,
} = useAdminUsers()

const newUser = reactive({ name: '', email: '', role: 'viewer' })

onMounted(loadUsers)

function changeRole(user, event) {
  const role = event.target.value
  if (role === user.role) return
  updateUser(user.id, { role })
}

function toggleDisabled(user) {
  const verb = user.disabled ? 'enable' : 'disable'
  if (!window.confirm(`Are you sure you want to ${verb} ${user.name}?`)) return
  updateUser(user.id, { disabled: !user.disabled })
}

function requestReset(user) {
  if (!window.confirm(`Reset access for ${user.name}? Their current session will be revoked.`)) return
  resetAccess(user)
}

async function submitNewUser() {
  const created = await createUser(newUser)
  if (!created) return

  newUser.name = ''
  newUser.email = ''
  newUser.role = 'viewer'
}
</script>

<template>
  <section class="user-management" data-test="admin-user-management">
    <header class="user-management__header">
      <div>
        <p class="eyebrow">Workspace security</p>
        <h2>User access</h2>
        <p>Assign roles, suspend accounts, and issue one-time replacement credentials.</p>
      </div>
      <button type="button" :disabled="loading" @click="loadUsers">{{ loading ? 'Refreshing…' : 'Refresh users' }}</button>
    </header>

    <div class="user-management__summary" aria-label="User access summary">
      <article><strong>{{ summary.activeCount }}</strong><span>Active accounts</span></article>
      <article><strong>{{ summary.administratorCount }}</strong><span>Administrators</span></article>
      <article><strong>{{ summary.disabledCount }}</strong><span>Disabled accounts</span></article>
    </div>

    <form class="create-user" data-test="create-user-form" @submit.prevent="submitNewUser">
      <div class="create-user__heading">
        <strong>Create user</strong>
        <span>An initial temporary password will be generated and shown once.</span>
      </div>
      <label>
        <span>Name</span>
        <input v-model.trim="newUser.name" name="name" type="text" autocomplete="off" required />
      </label>
      <label>
        <span>Email</span>
        <input v-model.trim="newUser.email" name="email" type="email" autocomplete="off" required />
      </label>
      <label>
        <span>Role</span>
        <select v-model="newUser.role" name="role" required>
          <option v-for="role in roles" :key="role.value" :value="role.value">{{ role.label }}</option>
        </select>
      </label>
      <button type="submit" :disabled="creating || loading">{{ creating ? 'Creating…' : 'Create user' }}</button>
    </form>

    <p v-if="error" class="user-management__error" role="alert">{{ error }}</p>

    <aside v-if="temporaryAccess" class="temporary-access" data-test="temporary-access">
      <div>
        <p>One-time temporary password</p>
        <strong>{{ temporaryAccess.userName }}</strong>
        <span>{{ temporaryAccess.email }}</span>
      </div>
      <code>{{ temporaryAccess.password }}</code>
      <p>{{ temporaryAccess.message }}</p>
      <button type="button" @click="clearTemporaryAccess">Dismiss</button>
    </aside>

    <div v-if="users.length" class="user-table-wrap">
      <table class="user-table">
        <thead>
          <tr><th>User</th><th>Status</th><th>Role</th><th>Last sign-in</th><th><span class="visually-hidden">Actions</span></th></tr>
        </thead>
        <tbody>
          <tr v-for="user in users" :key="user.id" :class="{ 'is-disabled': user.disabled }" :data-test="`admin-user-${user.id}`">
            <td>
              <strong>{{ user.name }}</strong>
              <span>{{ user.email }}</span>
              <small v-if="user.current_user">Current account</small>
              <small v-else-if="user.system_account">Automation account</small>
              <small v-else-if="user.password_change_required">Password replacement pending</small>
            </td>
            <td><span :class="['user-status', { 'user-status--disabled': user.disabled }]">{{ user.disabled ? 'Disabled' : 'Active' }}</span></td>
            <td>
              <select
                :value="user.role"
                :disabled="user.system_account || user.current_user || actionUserId === user.id"
                :aria-label="`Role for ${user.name}`"
                @change="changeRole(user, $event)"
              >
                <option v-for="role in roles" :key="role.value" :value="role.value">{{ role.label }}</option>
              </select>
            </td>
            <td>{{ formatTimestamp(user.last_signed_in_at, 'Never') }}</td>
            <td>
              <div class="user-actions">
                <button
                  type="button"
                  :disabled="user.system_account || user.current_user || actionUserId === user.id"
                  @click="toggleDisabled(user)"
                >
                  {{ user.disabled ? 'Enable' : 'Disable' }}
                </button>
                <button
                  type="button"
                  :disabled="user.system_account || user.current_user || actionUserId === user.id"
                  @click="requestReset(user)"
                >
                  {{ actionUserId === user.id ? 'Working…' : 'Reset access' }}
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p v-else-if="!loading" class="user-management__empty">No user accounts were found.</p>
  </section>
</template>

<style scoped>
.user-management { width: min(1440px,calc(100vw - 2.5rem)); margin: 1rem auto 0; padding: 1.4rem; border: 1px solid rgba(16,38,61,.12); border-radius: 22px; color: #10263d; background: rgba(255,252,244,.9); box-shadow: 0 16px 40px rgba(73,52,24,.08); }
.user-management__header { display: flex; justify-content: space-between; gap: 1.5rem; align-items: end; }
.user-management__header h2 { margin: .2rem 0; font-family: 'Avenir Next Condensed',sans-serif; font-size: 2rem; line-height: 1; text-transform: uppercase; }
.user-management__header p:last-child { margin: 0; color: #657580; font-size: .82rem; }
.user-management__header button,.user-actions button,.temporary-access button,.create-user button { padding: .55rem .75rem; border: 1px solid rgba(16,38,61,.16); border-radius: 9px; color: #173652; background: #fffdf7; font: inherit; font-size: .72rem; font-weight: 900; cursor: pointer; }
.user-management button:disabled,.user-management select:disabled { opacity: .5; cursor: not-allowed; }
.user-management__summary { display: grid; grid-template-columns: repeat(3,minmax(0,1fr)); gap: .7rem; margin-top: 1rem; }
.user-management__summary article { padding: .8rem; border-radius: 12px; background: rgba(23,54,82,.06); }
.user-management__summary strong,.user-management__summary span { display: block; }.user-management__summary strong { font-family: 'Avenir Next Condensed',sans-serif; font-size: 1.7rem; }.user-management__summary span { color: #687985; font-size: .7rem; font-weight: 800; text-transform: uppercase; }
.create-user { display: grid; grid-template-columns: minmax(220px,1.3fr) repeat(3,minmax(140px,1fr)) auto; gap: .75rem; align-items: end; margin-top: 1rem; padding: 1rem; border: 1px solid rgba(16,38,61,.1); border-radius: 14px; background: rgba(23,54,82,.035); }
.create-user__heading strong,.create-user__heading span,.create-user label span { display: block; }.create-user__heading strong { font-family: 'Avenir Next Condensed',sans-serif; font-size: 1.25rem; text-transform: uppercase; }.create-user__heading span { margin-top: .2rem; color: #687985; font-size: .68rem; line-height: 1.35; }.create-user label span { margin-bottom: .3rem; color: #687985; font-size: .62rem; font-weight: 900; letter-spacing: .05em; text-transform: uppercase; }.create-user input,.create-user select { width: 100%; min-height: 38px; padding: .5rem; border: 1px solid rgba(16,38,61,.16); border-radius: 8px; color: #10263d; background: #fffdf7; font: inherit; font-size: .75rem; box-sizing: border-box; }
.user-management__error { padding: .7rem; border-radius: 10px; color: #8f2d24; background: #f5ddd5; font-size: .78rem; font-weight: 800; }
.temporary-access { display: grid; grid-template-columns: 1fr auto; gap: .55rem 1rem; align-items: center; margin-top: 1rem; padding: 1rem; border: 1px solid rgba(181,120,31,.3); border-radius: 14px; background: #fbefce; }
.temporary-access p,.temporary-access strong,.temporary-access span { display: block; margin: 0; }.temporary-access div p { color: #8f621c; font-size: .64rem; font-weight: 900; text-transform: uppercase; }.temporary-access span { color: #6d7880; font-size: .72rem; }.temporary-access code { grid-row: span 2; padding: .55rem .75rem; border-radius: 8px; color: #10263d; background: #fffdf7; font-size: .9rem; }.temporary-access > p { grid-column: 1 / -1; color: #705722; font-size: .7rem; }.temporary-access > button { grid-column: 1 / -1; justify-self: start; }
.user-table-wrap { margin-top: 1rem; overflow-x: auto; }
.user-table { width: 100%; min-width: 850px; border-collapse: collapse; }
.user-table th,.user-table td { padding: .75rem; border-top: 1px solid rgba(16,38,61,.09); text-align: left; vertical-align: middle; }
.user-table thead th { color: #6c7a84; font-size: .65rem; letter-spacing: .06em; text-transform: uppercase; }
.user-table td:first-child strong,.user-table td:first-child span,.user-table td:first-child small { display: block; }.user-table td:first-child span { color: #697984; font-size: .72rem; }.user-table td:first-child small { margin-top: .18rem; color: #a36d1d; font-size: .62rem; font-weight: 800; text-transform: uppercase; }
.user-table tr.is-disabled { opacity: .65; }
.user-table select { min-width: 145px; padding: .5rem; border: 1px solid rgba(16,38,61,.16); border-radius: 8px; background: #fffdf7; font: inherit; font-size: .75rem; }
.user-status { display: inline-block; padding: .25rem .48rem; border-radius: 999px; color: #17613d; background: rgba(42,145,91,.13); font-size: .64rem; font-weight: 900; text-transform: uppercase; }.user-status--disabled { color: #8f2d24; background: rgba(181,61,48,.12); }
.user-actions { display: flex; justify-content: flex-end; gap: .4rem; }.user-actions button:last-child { color: #8f2d24; }
.user-management__empty { padding: 2rem; color: #697984; text-align: center; }
@media (max-width: 1050px) { .create-user { grid-template-columns: repeat(2,minmax(0,1fr)); }.create-user__heading { grid-column: 1 / -1; } }
@media (max-width: 720px) { .user-management__header { align-items: stretch; flex-direction: column; }.user-management__summary,.create-user { grid-template-columns: 1fr; }.create-user__heading { grid-column: auto; }.temporary-access { grid-template-columns: 1fr; }.temporary-access code { grid-row: auto; }.temporary-access > p,.temporary-access > button { grid-column: auto; } }
</style>
