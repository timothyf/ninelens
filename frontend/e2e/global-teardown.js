import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const backendDirectory = fileURLToPath(new URL('../../backend', import.meta.url))
const rubyBinPath = '/Users/timothyfisher/.rvm/gems/ruby-3.2.3/bin:/Users/timothyfisher/.rvm/gems/ruby-3.2.3@global/bin:/Users/timothyfisher/.rvm/rubies/ruby-3.2.3/bin'

export default function globalTeardown() {
  execFileSync('bundle', ['exec', 'rails', 'test:reset'], {
    cwd: backendDirectory,
    env: { ...process.env, PATH: `${rubyBinPath}:${process.env.PATH}`, RAILS_ENV: 'test' },
    stdio: 'inherit',
  })
}
