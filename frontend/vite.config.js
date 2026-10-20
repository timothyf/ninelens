import { execFileSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import { fileURLToPath, URL } from 'node:url'

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'

const packageJson = JSON.parse(readFileSync(new URL('./package.json', import.meta.url), 'utf8'))
const versionFile = fileURLToPath(new URL('../VERSION', import.meta.url))
const applicationVersion = existsSync(versionFile)
  ? readFileSync(versionFile, 'utf8').trim()
  : packageJson.version
let gitCommit = ''

try {
  gitCommit = execFileSync('git', ['rev-parse', 'HEAD'], {
    cwd: fileURLToPath(new URL('.', import.meta.url)),
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'ignore'],
  }).trim()
} catch {
  // The frontend build container does not include the repository's .git directory.
}

// https://vite.dev/config/
export default defineConfig({
  define: {
    __APPLICATION_VERSION__: JSON.stringify(applicationVersion),
    __LOCAL_GIT_COMMIT__: JSON.stringify(gitCommit),
  },
  plugins: [
    vue(),
    vueDevTools(),
  ],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: './src/test/setupTests.js',
    exclude: ['**/node_modules/**', '**/.git/**', 'e2e/**'],
  },
  server: {
    proxy: {
      '/api': {
        target: process.env.VITE_DEV_API_TARGET || 'http://127.0.0.1:3000',
        changeOrigin: true,
      },
    },
  },
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    },
  },
})
