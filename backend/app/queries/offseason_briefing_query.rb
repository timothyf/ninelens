class OffseasonBriefingQuery
  ITEM_LIMIT = 5

  def initialize(on:)
    @on = on
  end

  def result
    return nil unless offseason?

    {
      season: completed_season,
      recent_moves: recent_moves,
      free_agents: free_agents,
      awards: awards
    }
  end

  private

  attr_reader :on

  def offseason?
    [ 11, 12, 1, 2 ].include?(on.month)
  end

  def completed_season
    on.month <= 2 ? on.year - 1 : on.year
  end

  def offseason_start
    Date.new(completed_season, 10, 1)
  end

  def recent_moves
    trades = Trade.where(occurred_on: offseason_start..on).order(occurred_on: :desc, id: :desc).limit(ITEM_LIMIT).includes(:trade_participants)
      .map do |trade|
        participant = trade.trade_participants.first
        {
          id: "trade-#{trade.id}", type: "Trade", date: trade.occurred_on,
          player_id: participant&.player_id, player_name: participant&.player_name,
          description: trade.description
        }
      end

    signings = TeamMembership.where(source_name: MlbPlayerTeamHistoryImporter::SOURCE_NAME, starts_on: offseason_start..on)
      .order(starts_on: :desc, id: :desc).limit(50).includes(:player, :team).filter_map do |membership|
        transaction = membership.raw_data.to_h["start_transaction"].to_h
        next unless transaction["typeCode"].to_s.upcase.in?(%w[SFA SGN]) || transaction["typeDesc"].to_s.match?(/signed/i)

        {
          id: "signing-#{membership.id}", type: "Signing", date: membership.starts_on,
          player_id: membership.player_id, player_name: membership.player.full_name,
          description: "#{membership.player.full_name} signed with #{membership.team.name}"
        }
      end

    (trades + signings).sort_by { |move| [ -move[:date].jd, move[:id] ] }.first(ITEM_LIMIT)
  end

  def free_agents
    departed = TeamMembership.where(source_name: MlbPlayerTeamHistoryImporter::SOURCE_NAME)
      .where(ends_on: (offseason_start - 1.day)..on).order(ends_on: :desc).includes(:player, :team)
      .select do |membership|
        transaction = membership.raw_data.to_h["end_transaction"].to_h
        [ transaction["typeDesc"], transaction["description"] ].any? { |text| text.to_s.match?(/(?:declared|elected) free agency/i) }
      end
    return [] if departed.empty?

    active_ids = TeamMembership.where(source_name: MlbPlayerTeamHistoryImporter::SOURCE_NAME, player_id: departed.map(&:player_id))
      .active_on(on).distinct.pluck(:player_id)
    candidates = departed.uniq(&:player_id).reject { |membership| active_ids.include?(membership.player_id) }
    player_ids = candidates.map(&:player_id)
    war_by_player = PlayerSeasonStat.joins(:stat_type)
      .where(player_id: player_ids, season: ..completed_season, scope_type: %w[combined team], stat_types: { name: %w[WAR war] })
      .pluck(:player_id, :season, :value)
      .group_by(&:first).transform_values do |rows|
        latest_season = rows.map { |row| row[1] }.max
        { season: latest_season, value: rows.select { |row| row[1] == latest_season }.map { |row| row[2].to_f }.max }
      end
    experience_by_player = PlayerSeasonStat.joins(:stat_type)
      .where(player_id: player_ids, season: ..completed_season, scope_type: %w[combined team], stat_types: { category: %w[batting pitching] })
      .distinct.pluck(:player_id, :season).group_by(&:first).transform_values(&:length)

    featured = candidates.sort_by { |membership| [ -(war_by_player.dig(membership.player_id, :value) || 0), -membership.ends_on.jd, membership.player.full_name ] }
      .first(ITEM_LIMIT)
    positions = PlayerPosition.where(player_id: featured.map(&:player_id))
      .where("season IS NULL OR season <= ?", completed_season).includes(:position)
      .group_by(&:player_id).transform_values do |rows|
        rows.select(&:is_primary?).min_by do |row|
          [ row.season == completed_season ? 0 : row.season.nil? ? 1 : 2, -(row.season || 0) ]
        end&.position
      end
    stat_lines = free_agent_stat_lines(featured, positions)

    featured.map do |membership|
        {
          player_id: membership.player_id, player_name: membership.player.full_name,
          former_team: membership.team.abbreviation,
          position: positions[membership.player_id]&.abbreviation,
          stat_line: stat_lines[membership.player_id],
          war: war_by_player.dig(membership.player_id, :value),
          war_season: war_by_player.dig(membership.player_id, :season),
          experience_years: experience_by_player[membership.player_id]
        }
      end
  end

  def free_agent_stat_lines(featured, positions)
    rows = PlayerSeasonStat.joins(:stat_type)
      .where(player_id: featured.map(&:player_id), season: ..completed_season, scope_type: %w[combined team])
      .where(stat_types: { name: %w[AVG OBP SLG W L ERA WHIP avg obp slg whip] })
      .pluck(:player_id, :season, :scope_type, :scope_key, :category, :name, :value)
      .group_by(&:first)

    featured.to_h do |membership|
      category = positions[membership.player_id]&.position_type == "pitcher" ? "pitching" : "batting"
      names = category == "pitching" ? %w[W L ERA WHIP] : %w[AVG OBP SLG]
      groups = Array(rows[membership.player_id]).select { |row| row[4] == category && names.include?(row[5].upcase) }
        .group_by { |row| [ row[1], row[2], row[3] ] }
      selected = groups.max_by do |(season, scope, team), stats|
        [ season, scope == "combined" ? 2 : team == membership.team.abbreviation ? 1 : 0, stats.map { |row| row[5].upcase }.uniq.length ]
      end
      stats = selected&.last&.to_h { |row| [ row[5].upcase, row[6].to_f ] }
      line = if stats.present? && names.any? { |name| stats.key?(name) }
        { season: selected.first[0], type: category, values: stats.slice(*names) }
      end
      [ membership.player_id, line ]
    end
  end

  def awards
    MlbSeasonAwardsSync.call(season: completed_season) if Schedule.exists?(season: completed_season)
    rows = SeasonAward.where(season: completed_season, award_id: %w[ALMVP NLMVP ALCY NLCY ALROY NLROY])
      .order(:award_id).to_a
    players = Player.where(mlb_id: rows.map(&:player_mlb_id)).pluck(:mlb_id, :id).to_h
    rows.map do |award|
      {
        id: award.id, name: award.award_name, player_id: players[award.player_mlb_id],
        player_name: award.player_name, season: award.season
      }
    end
  end
end
