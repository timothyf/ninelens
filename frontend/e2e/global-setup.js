import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const backendDirectory = fileURLToPath(new URL('../../backend', import.meta.url))
const e2ePassword = 'playwright-password-123'
const rubyBinPath = '/Users/timothyfisher/.rvm/gems/ruby-3.2.3/bin:/Users/timothyfisher/.rvm/gems/ruby-3.2.3@global/bin:/Users/timothyfisher/.rvm/rubies/ruby-3.2.3/bin'
const seedUsers = `
  [
    { email: 'e2e.viewer@ninelens.test', name: 'E2E Viewer', role: 'viewer' },
    { email: 'e2e.admin@ninelens.test', name: 'E2E Administrator', role: 'administrator' },
    { email: 'e2e.task-admin@ninelens.test', name: 'E2E Task Administrator', role: 'administrator' },
    { email: 'e2e.editor@ninelens.test', name: 'E2E Editor', role: 'editor' }
  ].each do |attributes|
    user = User.find_or_initialize_by(email: attributes.fetch(:email))
    user.assign_attributes(attributes.merge(disabled_at: nil, system_account: false))
    user.password = '${e2ePassword}'
    user.save!
  end
`
const seedPlayerComparisonScenario = `
  team = Team.find_or_initialize_by(mlb_id: 9_990_001)
  team.assign_attributes(
    name: 'E2E Testers',
    abbreviation: 'E2E',
    team_name: 'Testers',
    location_name: 'End-to-End',
    short_name: 'E2E',
    team_code: 'e2e',
    file_code: 'e2e'
  )
  team.save!

  players = [
    { mlb_id: 9_990_101, first_name: 'E2E', last_name: 'Slugger', home_runs: 99_999, at_bats: 500, average: 0.400, ops: 1.200, war: 12.0, rbi: 999 },
    { mlb_id: 9_990_102, first_name: 'E2E', last_name: 'Rival', home_runs: 99_998, at_bats: 500, average: 0.390, ops: 1.150, war: 11.0, rbi: 998 }
  ]
  stat_types = {
    home_runs: ['homeRuns', 'HR'],
    at_bats: ['atBats', 'AB'],
    average: ['avg', 'AVG'],
    ops: ['ops', 'OPS'],
    war: ['WAR', 'WAR'],
    rbi: ['rbi', 'RBI']
  }.transform_values do |name, label|
    StatType.find_or_create_by!(category: 'batting', name: name) { |stat_type| stat_type.label = label }
  end

  players.each do |attributes|
    player = Player.find_or_initialize_by(mlb_id: attributes.fetch(:mlb_id))
    player.assign_attributes(team: team, first_name: attributes.fetch(:first_name), last_name: attributes.fetch(:last_name))
    player.save!

    profile = PlayerProfile.find_or_initialize_by(player: player)
    profile.assign_attributes(
      birth_date: Date.new(1995, 5, 10),
      height_inches: 74,
      weight_pounds: 210,
      bats: 'R',
      throws: 'R',
      mlb_debut_date: Date.new(2020, 7, 24),
      headshot_id: player.mlb_id.to_s,
      raw_data: { 'active' => true },
      source_name: 'Playwright',
      last_synced_at: Time.current
    )
    profile.save!

    stat_types.each do |key, stat_type|
      stat = PlayerSeasonStat.find_or_initialize_by(
        player: player,
        team: team,
        stat_type: stat_type,
        season: 2026,
        scope_type: 'team',
        scope_key: team.abbreviation
      )
      stat.value = attributes.fetch(key)
      stat.save!
    end
  end
`

function rails(...argumentsList) {
  execFileSync('bundle', ['exec', 'rails', ...argumentsList], {
    cwd: backendDirectory,
    env: { ...process.env, PATH: `${rubyBinPath}:${process.env.PATH}`, RAILS_ENV: 'test' },
    stdio: 'inherit',
  })
}

export default function globalSetup() {
  rails('db:prepare')
  rails('test:reset')
  rails('runner', seedUsers)
  rails('runner', seedPlayerComparisonScenario)
}
