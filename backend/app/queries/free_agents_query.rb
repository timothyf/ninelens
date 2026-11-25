class FreeAgentsQuery
  BATTING_STATS = {
    "gamesplayed" => "G", "avg" => "AVG", "obp" => "OBP", "slg" => "SLG",
    "homeruns" => "HR", "rbi" => "RBI"
  }.freeze
  PITCHING_STATS = {
    "gamesplayed" => "G", "w" => "W", "l" => "L", "era" => "ERA",
    "whip" => "WHIP", "inningspitched" => "IP", "strikeouts" => "SO"
  }.freeze

  def initialize(on:)
    @on = on
  end

  def result
    {
      season: season,
      as_of: cutoff,
      batters: entries.select { |entry| entry[:category] == "batting" },
      pitchers: entries.select { |entry| entry[:category] == "pitching" }
    }
  end

  def entries
    @entries ||= build_entries
  end

  private

  attr_reader :on

  def season
    @season ||= on.month <= 9 ? on.year - 1 : on.year
  end

  def cutoff
    @cutoff ||= [ on, Date.new(season + 1, 2, -1) ].min
  end

  def offseason_start
    Date.new(season, 10, 1)
  end

  def build_entries
    departed = TeamMembership.where(source_name: MlbPlayerTeamHistoryImporter::SOURCE_NAME)
      .where(ends_on: (offseason_start - 1.day)..cutoff)
      .order(ends_on: :desc, id: :desc).includes(:player, :team)
      .select do |membership|
        transaction = membership.raw_data.to_h["end_transaction"].to_h
        [ transaction["typeDesc"], transaction["description"] ].any? { |text| text.to_s.match?(/(?:declared|elected) free agency/i) }
      end
    return [] if departed.empty?

    active_ids = TeamMembership.where(source_name: MlbPlayerTeamHistoryImporter::SOURCE_NAME, player_id: departed.map(&:player_id))
      .active_on(cutoff).distinct.pluck(:player_id).to_set
    candidates = departed.uniq(&:player_id).reject { |membership| active_ids.include?(membership.player_id) }
    return [] if candidates.empty?

    player_ids = candidates.map(&:player_id)
    profiles = PlayerProfile.where(player_id: player_ids).index_by(&:player_id)
    war_by_player = PlayerSeasonStat.joins(:stat_type)
      .where(player_id: player_ids, season: ..season, scope_type: %w[combined team], stat_types: { name: %w[WAR war] })
      .pluck(:player_id, :season, :value)
      .group_by(&:first).transform_values do |rows|
        latest_season = rows.map { |row| row[1] }.max
        { season: latest_season, value: rows.select { |row| row[1] == latest_season }.map { |row| row[2].to_f }.max }
      end
    experience_by_player = PlayerSeasonStat.joins(:stat_type)
      .where(player_id: player_ids, season: ..season, scope_type: %w[combined team], stat_types: { category: %w[batting pitching] })
      .distinct.pluck(:player_id, :season).group_by(&:first).transform_values(&:length)
    positions = PlayerPosition.where(player_id: player_ids)
      .where("season IS NULL OR season <= ?", season).includes(:position)
      .group_by(&:player_id).transform_values do |rows|
        rows.select(&:is_primary?).min_by do |row|
          [ row.season == season ? 0 : row.season.nil? ? 1 : 2, -(row.season || 0) ]
        end&.position
      end
    stat_rows = PlayerSeasonStat.joins(:stat_type)
      .where(player_id: player_ids, season: ..season, scope_type: %w[combined team])
      .where("LOWER(stat_types.name) IN (?)", (BATTING_STATS.keys + PITCHING_STATS.keys).uniq)
      .pluck(:player_id, :season, :scope_type, :scope_key, :category, :name, :value)
      .group_by(&:first)

    candidates.sort_by { |membership| [ -(war_by_player.dig(membership.player_id, :value) || 0), -membership.ends_on.jd, membership.player.full_name ] }
      .map do |membership|
        player_id = membership.player_id
        category = category_for(positions[player_id], stat_rows[player_id])
        {
          player_id: player_id, player_name: membership.player.full_name,
          former_team: membership.team.abbreviation,
          free_agent_since: membership.ends_on,
          position: positions[player_id]&.abbreviation,
          age: profiles[player_id]&.age(on: cutoff),
          category: category,
          stat_line: stat_line_for(membership, category, stat_rows[player_id]),
          war: war_by_player.dig(player_id, :value),
          war_season: war_by_player.dig(player_id, :season),
          experience_years: experience_by_player[player_id]
        }
      end
  end

  def category_for(position, rows)
    return "pitching" if position&.position_type == "pitcher"
    return "batting" if position.present?

    categories = Array(rows).map { |row| row[4] }.uniq
    categories == [ "pitching" ] ? "pitching" : "batting"
  end

  def stat_line_for(membership, category, rows)
    names = category == "pitching" ? PITCHING_STATS : BATTING_STATS
    groups = Array(rows).select { |row| row[4] == category && names.key?(row[5].downcase) }
      .group_by { |row| [ row[1], row[2], row[3] ] }
    selected = groups.max_by do |(year, scope, team), stats|
      [ year, scope == "combined" ? 2 : team == membership.team.abbreviation ? 1 : 0, stats.map { |row| names[row[5].downcase] }.uniq.length ]
    end
    return nil unless selected

    values = selected.last.to_h { |row| [ names[row[5].downcase], row[6].to_f ] }
    { season: selected.first[0], type: category, values: values }
  end
end
