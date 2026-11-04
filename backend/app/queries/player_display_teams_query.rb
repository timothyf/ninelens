class PlayerDisplayTeamsQuery
  def self.call(players:, on: Date.current)
    new(players: players, on: on).result
  end

  def initialize(players:, on:)
    @players = players
    @on = on
  end

  def result
    display_teams = players.to_h { |player| [ player.id, player.team ] }
    retired, current = players.partition { |player| player.profile&.raw_data.to_h["active"] == false }

    current_membership_teams(current).each { |player_id, team| display_teams[player_id] = team }
    retired_history_teams(retired).each { |player_id, team| display_teams[player_id] = team }
    display_teams
  end

  private

  attr_reader :players, :on

  def current_membership_teams(current)
    return {} if current.empty?

    TeamMembership.active_on(on).where(player_id: current.map(&:id)).preload(:team)
      .group_by(&:player_id).transform_values do |memberships|
        memberships.min_by do |membership|
          [ MlbRosterStatus.priority(membership.roster_status), -membership.starts_on.jd, membership.id ]
        end.team
      end
  end

  def retired_history_teams(retired)
    return {} if retired.empty?

    rows = PlayerSeasonStat.where(player_id: retired.map(&:id)).where.not(team_id: nil)
      .distinct.pluck(:player_id, :team_id, :season)
    preferred_team_ids = rows.group_by(&:first).transform_values do |player_rows|
      player_rows.group_by { |row| row[1] }
        .max_by { |team_id, team_rows| [ team_rows.length, team_rows.map(&:last).max || 0, team_id ] }
        &.first
    end
    teams_by_id = Team.where(id: preferred_team_ids.values).index_by(&:id)
    preferred_team_ids.filter_map do |player_id, team_id|
      [ player_id, teams_by_id.fetch(team_id) ] if teams_by_id.key?(team_id)
    end.to_h
  end
end
