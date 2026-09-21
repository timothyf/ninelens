class PlayerSeasonStatsLeaderboardQuery
  DEFAULT_PAGE = 1
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100
  DEFAULT_CATEGORY = "batting"
  FIXED_SORT_FIELDS = {
    "player_name" => "players.last_name",
    "team_name" => "teams.team_name",
    "season" => "player_season_stats.season"
  }.freeze
  SCOPE_TYPES = %w[team combined league].freeze
  COLUMN_DEFINITIONS_BY_CATEGORY = {
    "batting" => [
      { key: "gamesPlayed", label: "G", aliases: %w[gamesPlayed G] },
      { key: "atBats", label: "AB", aliases: %w[atBats AB] },
      { key: "runs", label: "R", aliases: %w[runs R] },
      { key: "hits", label: "H", aliases: %w[hits H] },
      { key: "doubles", label: "2B", aliases: %w[doubles 2B] },
      { key: "triples", label: "3B", aliases: %w[triples 3B] },
      { key: "homeRuns", label: "HR", aliases: %w[homeRuns HR] },
      { key: "rbi", label: "RBI", aliases: %w[rbi RBI] },
      { key: "baseOnBalls", label: "BB", aliases: %w[baseOnBalls BB] },
      { key: "strikeOuts", label: "SO", aliases: %w[strikeOuts SO] },
      { key: "stolenBases", label: "SB", aliases: %w[stolenBases SB] },
      { key: "caughtStealing", label: "CS", aliases: %w[caughtStealing CS] },
      { key: "avg", label: "AVG", aliases: %w[avg AVG] },
      { key: "obp", label: "OBP", aliases: %w[obp OBP] },
      { key: "slg", label: "SLG", aliases: %w[slg SLG] },
      { key: "ops", label: "OPS", aliases: %w[ops OPS] },
      { key: "WAR", label: "WAR", aliases: %w[WAR war] }
    ],
    "pitching" => [
      { key: "W", label: "W", aliases: %w[W wins] },
      { key: "L", label: "L", aliases: %w[L losses] },
      { key: "ERA", label: "ERA", aliases: %w[ERA era] },
      { key: "G", label: "G", aliases: %w[G gamesPitched gamesPlayed] },
      { key: "GS", label: "GS", aliases: %w[GS gamesStarted] },
      { key: "CG", label: "CG", aliases: %w[CG completeGames] },
      { key: "ShO", label: "SHO", aliases: %w[ShO shutouts shutout] },
      { key: "SV", label: "SV", aliases: %w[SV saves] },
      { key: "SVO", label: "SVO", aliases: %w[SVO saveOpportunities] },
      { key: "inningsPitched", label: "IP", aliases: %w[inningsPitched IP] },
      { key: "hits", label: "H", aliases: %w[hits H] },
      { key: "runs", label: "R", aliases: %w[runs R] },
      { key: "ER", label: "ER", aliases: %w[ER earnedRuns], derived_from: :earned_runs },
      { key: "homeRuns", label: "HR", aliases: %w[homeRuns HR] },
      { key: "hitByPitch", label: "HB", aliases: %w[hitByPitch hitBatsmen HBP] },
      { key: "baseOnBalls", label: "BB", aliases: %w[baseOnBalls BB] },
      { key: "strikeOuts", label: "SO", aliases: %w[strikeOuts SO] },
      { key: "whip", label: "WHIP", aliases: %w[whip WHIP] },
      { key: "avg", label: "AVG", aliases: %w[avg AVG] },
      { key: "WAR", label: "WAR", aliases: %w[WAR war] }
    ],
    "pitchStats" => [
      { key: "pitch", label: "Count", aliases: %w[pitch] },
      { key: "release_speed", label: "Velocity", aliases: %w[release_speed velocity] },
      { key: "pfx_z", label: "iVB", aliases: %w[pfx_z] },
      { key: "pfx_x", label: "HB", aliases: %w[pfx_x] },
      { key: "release_spin_rate", label: "Spin", aliases: %w[release_spin_rate] },
      { key: "release_extension", label: "Ext.", aliases: %w[release_extension] },
      { key: "xwoba", label: "xwOBA", aliases: %w[xwoba] },
      { key: "pitch_usage", label: "Pitch%", aliases: %w[pitch_usage] },
      { key: "whiff_rate", label: "Whiff%", aliases: %w[whiff_rate] },
      { key: "in_zone_rate", label: "Zone%", aliases: %w[in_zone_rate] },
      { key: "chase_rate", label: "Chase%", aliases: %w[chase_rate] },
      { key: "delta_run_exp_per_100", label: "RV/100", aliases: %w[delta_run_exp_per_100] }
    ]
  }.freeze
  DEFAULT_SORTS_BY_CATEGORY = {
    "batting" => "-homeRuns",
    "pitching" => "-strikeOuts",
    "pitchStats" => "-pitch_usage"
  }.freeze

  def initialize(params:, relation: PlayerSeasonStat.all, stat_type_relation: StatType.cached_all)
    @params = params
    @relation = relation
    @stat_type_relation = stat_type_relation
  end

  def results
    connection.select_all(paginated_relation.to_sql).map.with_index do |row, index|
      serialize_row(row, index)
    end
  end

  def metadata
    base_metadata.merge(
      total_count: total_count,
      total_pages: total_pages,
      data_range: data_range,
      available_seasons: available_seasons,
      available_teams: available_teams,
      available_positions: available_positions,
      facets_complete: true
    )
  end

  def base_metadata
    {
      page: page,
      per_page: per_page,
      sort: normalized_sort,
      filters: normalized_filters,
      category: category,
      facets_complete: false,
      columns: visible_column_definitions.map do |column_definition|
        {
          key: column_definition.fetch(:key),
          label: column_definition.fetch(:label),
          align: "numeric"
        }
      end
    }
  end

  private

  attr_reader :params, :relation, :stat_type_relation

  def connection
    PlayerSeasonStat.connection
  end

  def base_relation
    @base_relation ||= relation.joins(:player).left_outer_joins(:team)
  end

  def filtered_relation
    @filtered_relation ||= apply_filters(base_relation, include_season: true, include_team: true)
  end

  def season_scope
    @season_scope ||= apply_filters(base_relation, include_season: false, include_team: true)
  end

  def team_scope
    @team_scope ||= apply_filters(base_relation, include_season: true, include_team: false)
  end

  def grouped_relation
    @grouped_relation ||= filtered_relation
      .select(*group_select_fields, *stat_select_fields)
      .group(*group_by_fields)
  end

  def paginated_relation
    return standard_paginated_relation unless initial_default_stat_page?

    keys = paginated_sort_keys
    return standard_paginated_relation if keys.length < per_page

    grouped_relation
      .where(Arel.sql(group_key_predicate(keys)))
      .order(Arel.sql(order_expression))
  end

  def standard_paginated_relation
    grouped_relation
      .order(Arel.sql(order_expression))
      .offset((page - 1) * per_page)
      .limit(per_page)
  end

  def initial_default_stat_page?
    page == DEFAULT_PAGE &&
      requested_sort_field == default_sort.delete_prefix("-") &&
      sort_direction == "DESC" &&
      !column_definition_for(sort_field).key?(:derived_from) &&
      !single_player_results?
  end

  def paginated_sort_keys
    sort_definition = column_definition_for(sort_field)
    stat_names = Array(sort_definition.fetch(:aliases))
    key_relation = apply_filters(base_relation, include_season: true, include_team: true, stat_names: stat_names)
      .select(*group_select_fields, "#{aggregate_expression(sort_definition)} AS leaderboard_sort_value")
      .group(*group_by_fields)
      .order(Arel.sql(order_expression))
      .limit(per_page)

    connection.select_all(key_relation.to_sql)
  end

  def group_key_predicate(keys)
    keys.map do |key|
      [
        null_safe_equality("player_season_stats.player_id", key["player_id"]),
        null_safe_equality("player_season_stats.team_id", key["team_id"]),
        null_safe_equality("player_season_stats.season", key["season"]),
        null_safe_equality("player_season_stats.scope_type", key["scope_type"]),
        null_safe_equality("player_season_stats.scope_key", key["scope_key"])
      ].join(" AND ").then { |condition| "(#{condition})" }
    end.join(" OR ")
  end

  def null_safe_equality(column, value)
    "#{column} IS NOT DISTINCT FROM #{connection.quote(value)}"
  end

  def order_expression
    return "player_season_stats.season ASC" if single_player_results?

    "#{sort_expression} #{sort_direction} NULLS LAST, players.last_name ASC, players.first_name ASC, player_season_stats.season DESC"
  end

  def group_select_fields
    [
      "players.id AS player_id",
      "players.mlb_id AS player_mlb_id",
      "players.first_name AS player_first_name",
      "players.last_name AS player_last_name",
      "teams.id AS team_id",
      "teams.mlb_id AS team_mlb_id",
      "teams.name AS team_name",
      "teams.abbreviation AS team_abbreviation",
      "teams.team_name AS team_team_name",
      "teams.location_name AS team_location_name",
      "teams.short_name AS team_short_name",
      "player_season_stats.scope_type AS scope_type",
      "player_season_stats.scope_key AS scope_key",
      "player_season_stats.season AS season"
    ]
  end

  def stat_select_fields
    visible_column_definitions.map do |column_definition|
      "#{aggregate_expression(column_definition)} AS #{stat_alias(column_definition.fetch(:key))}"
    end
  end

  def aggregate_expression(column_definition)
    alias_expressions = Array(column_definition.fetch(:aliases)).map do |alias_name|
      max_case_expression(alias_name)
    end

    alias_expressions << derived_earned_runs_expression if column_definition[:derived_from] == :earned_runs

    "COALESCE(#{alias_expressions.join(', ')})"
  end

  def max_case_expression(alias_name)
    stat_type_ids = stat_type_ids_for_names([ alias_name ])
    ids_sql = stat_type_ids.presence&.join(", ") || "NULL"
    "MAX(CASE WHEN player_season_stats.stat_type_id IN (#{ids_sql}) THEN player_season_stats.value END)"
  end

  def stat_type_ids_for_category
    @stat_type_ids_for_category ||= StatType.cached_where(category: category).map(&:id)
  end

  def stat_type_ids_for_names(names)
    names = Array(names).map(&:to_s)
    StatType.cached_all
      .select { |stat_type| stat_type.category == category && names.include?(stat_type.name) }
      .map(&:id)
  end

  def group_by_fields
    [
      "players.id",
      "players.mlb_id",
      "players.first_name",
      "players.last_name",
      "teams.id",
      "teams.mlb_id",
      "teams.name",
      "teams.abbreviation",
      "teams.team_name",
      "teams.location_name",
      "teams.short_name",
      "player_season_stats.scope_type",
      "player_season_stats.scope_key",
      "player_season_stats.season"
    ]
  end

  def column_definitions
    @column_definitions ||= COLUMN_DEFINITIONS_BY_CATEGORY.fetch(category, COLUMN_DEFINITIONS_BY_CATEGORY.fetch(DEFAULT_CATEGORY))
  end

  def column_definition_for(column_key)
    column_definitions.find { |column_definition| column_definition.fetch(:key) == column_key } ||
      column_definitions.find { |column_definition| Array(column_definition.fetch(:aliases)).include?(column_key) } ||
      column_definitions.first
  end

  def total_count
    @total_count ||= begin
      sql = <<~SQL.squish
        SELECT COUNT(*) FROM (
          #{count_relation.to_sql}
        ) leaderboard_rows
      SQL
      connection.select_value(sql).to_i
    end
  end

  def count_relation
    filtered_relation
      .select("players.id", "player_season_stats.season", "player_season_stats.scope_type", "player_season_stats.scope_key")
      .group("players.id", "player_season_stats.season", "player_season_stats.scope_type", "player_season_stats.scope_key")
  end

  def single_player_results?
    @single_player_results ||= player_filter_present? && filtered_relation.distinct.count("players.id") == 1
  end

  def player_filter_present?
    normalized_filters[:player_id].present? || normalized_filters[:player_name].present?
  end

  def total_pages
    return 0 if total_count.zero?

    (total_count.to_f / per_page).ceil
  end

  def available_seasons
    @available_seasons ||= season_scope
      .distinct
      .order("player_season_stats.season DESC")
      .pluck("player_season_stats.season")
  end

  def data_range
    @data_range ||= begin
      scope = relation.where(player_season_stats: { stat_type_id: stat_type_ids_for_category })
      min_season = scope.minimum(:season)
      max_season = scope.maximum(:season)

      {
        type: "season",
        start: min_season,
        end: max_season
      }
    end
  end

  def available_teams
    @available_teams ||= team_scope
      .distinct
      .order("teams.abbreviation ASC", "teams.team_name ASC")
      .pluck("teams.id", "teams.mlb_id", "teams.abbreviation", "teams.name", "teams.team_name", "teams.location_name", "teams.short_name")
      .map do |id, mlb_id, abbreviation, name, team_name, location_name, short_name|
        {
          id: id,
          mlb_id: mlb_id,
          abbreviation: abbreviation,
          name: name,
          team_name: team_name,
          location_name: location_name,
          short_name: short_name
        }
      end
  end

  def available_positions
    @available_positions ||= begin
      position_scope = apply_filters(
        base_relation.joins(player: { player_positions: :position }),
        include_season: true,
        include_team: true,
        position_filter: false
      )
      position_scope
        .distinct
        .order("positions.sort_order ASC", "positions.abbreviation ASC")
        .pluck("positions.id", "positions.abbreviation", "positions.name", "positions.sort_order")
        .map { |id, abbreviation, name, _sort_order| { id: id, abbreviation: abbreviation, name: name } }
    end
  end

  def requested_sort
    @requested_sort ||= (params["sort"] || params[:sort]).presence || default_sort
  end

  def default_sort
    DEFAULT_SORTS_BY_CATEGORY.fetch(category, DEFAULT_SORTS_BY_CATEGORY.fetch(DEFAULT_CATEGORY))
  end

  def requested_sort_field
    requested_sort.delete_prefix("-")
  end

  def allowed_sort_fields
    FIXED_SORT_FIELDS.keys + visible_column_definitions.map { |column_definition| column_definition.fetch(:key) }
  end

  def sort_field
    @sort_field ||= allowed_sort_fields.include?(requested_sort_field) ? requested_sort_field : default_sort.delete_prefix("-")
  end

  def sort_expression
    return FIXED_SORT_FIELDS.fetch(sort_field) if FIXED_SORT_FIELDS.key?(sort_field)

    "CAST(#{aggregate_expression(column_definition_for(sort_field))} AS NUMERIC)"
  end

  def sort_direction
    if allowed_sort_fields.include?(requested_sort_field)
      requested_sort.start_with?("-") ? "DESC" : "ASC"
    else
      default_sort.start_with?("-") ? "DESC" : "ASC"
    end
  end

  def normalized_sort
    prefix = sort_direction == "DESC" ? "-" : ""
    "#{prefix}#{sort_field}"
  end

  def page
    @page ||= positive_integer(params["page"] || params[:page], DEFAULT_PAGE)
  end

  def per_page
    @per_page ||= [ positive_integer(params["per_page"] || params[:per_page], DEFAULT_PER_PAGE), MAX_PER_PAGE ].min
  end

  def normalized_filters
    @normalized_filters ||= begin
      filters = raw_filters
        .slice("season", "season_start", "season_end", "team_id", "position_id", "league", "scope_type", "scope_key", "player_id", "team_name", "player_name", "category")
        .transform_values { |value| value.is_a?(String) ? value.strip : value }
        .compact_blank

      integer_filter!(filters, "season")
      integer_filter!(filters, "season_start")
      integer_filter!(filters, "season_end")
      integer_filter!(filters, "team_id")
      integer_filter!(filters, "position_id")
      integer_filter!(filters, "player_id")
      filters.delete("league") unless %w[american national].include?(filters["league"])
      normalize_scope_type!(filters)
      normalize_season_bounds!(filters)
      filters["category"] = normalize_category(filters["category"])
      filters["category"] ||= DEFAULT_CATEGORY

      filters.symbolize_keys
    end
  end

  def raw_filters
    filters = params.fetch("filter", params.fetch(:filter, {}))
    filters.respond_to?(:to_h) ? filters.to_h.deep_stringify_keys : {}
  end

  def league_team_mlb_ids
    MlbRosterBatchSync::TEAM_IDS_BY_LEAGUE.fetch(normalized_filters[:league])
  end

  def category
    normalized_filters[:category] || DEFAULT_CATEGORY
  end

  def normalize_category(raw_category)
    category_name = raw_category.to_s
    COLUMN_DEFINITIONS_BY_CATEGORY.key?(category_name) ? category_name : nil
  end

  def positive_integer(value, fallback)
    integer = value.to_i
    integer.positive? ? integer : fallback
  end

  def integer_filter!(filters, key)
    return unless filters[key].present?

    integer = Integer(filters[key], exception: false)
    integer.present? ? filters[key] = integer : filters.delete(key)
  end

  def like_pattern(value)
    "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
  end

  def normalize_season_bounds!(filters)
    return unless filters["season_start"].present? && filters["season_end"].present?
    return unless filters["season_start"] > filters["season_end"]

    filters["season_start"], filters["season_end"] = filters["season_end"], filters["season_start"]
  end

  def apply_filters(scope, include_season:, include_team:, stat_names: available_alias_names, position_filter: true)
    filtered_scope = scope.where(player_season_stats: { stat_type_id: stat_type_ids_for_names(stat_names) })

    if position_filter && normalized_filters[:position_id].present?
      filtered_scope = filtered_scope.joins(player: { player_positions: :position })
        .where(positions: { id: normalized_filters[:position_id] })
    end

    if include_season && normalized_filters[:season].present?
      filtered_scope = filtered_scope.where(player_season_stats: { season: normalized_filters[:season] })
    elsif include_season
      if normalized_filters[:season_start].present?
        filtered_scope = filtered_scope.where("player_season_stats.season >= ?", normalized_filters[:season_start])
      end

      if normalized_filters[:season_end].present?
        filtered_scope = filtered_scope.where("player_season_stats.season <= ?", normalized_filters[:season_end])
      end
    end

    if include_team && normalized_filters[:team_id].present?
      filtered_scope = filtered_scope.where(player_season_stats: { scope_type: "team", team_id: normalized_filters[:team_id] })
    end

    if normalized_filters[:league].present?
      filtered_scope = filtered_scope.where(teams: { mlb_id: league_team_mlb_ids })
    end

    if normalized_filters[:scope_type].present?
      filtered_scope = filtered_scope.where(player_season_stats: { scope_type: normalized_filters[:scope_type] })
    end

    if normalized_filters[:scope_key].present?
      filtered_scope = filtered_scope.where("player_season_stats.scope_key ILIKE ?", like_pattern(normalized_filters[:scope_key]))
    end

    if normalized_filters[:player_id].present?
      filtered_scope = filtered_scope.where(player_season_stats: { player_id: normalized_filters[:player_id] })
    end

    if include_team && normalized_filters[:team_name].present?
      team_name_pattern = like_pattern(normalized_filters[:team_name])
      filtered_scope = filtered_scope.where("teams.name ILIKE :pattern OR teams.team_name ILIKE :pattern", pattern: team_name_pattern)
    end

    if normalized_filters[:player_name].present?
      player_name_pattern = like_pattern(normalized_filters[:player_name])
      filtered_scope = filtered_scope.where(
        "concat_ws(' ', players.first_name, players.last_name) ILIKE :pattern OR players.last_name ILIKE :pattern",
        pattern: player_name_pattern
      )
    end

    filtered_scope
  end

  def stat_alias(column_name)
    "stat_#{column_name.to_s.gsub(/[^a-zA-Z0-9]+/, "_").downcase.gsub(/_+/, "_").sub(/_$/, "")}"
  end

  def serialize_row(row, index)
    team_abbreviation = row["team_abbreviation"].presence || row["scope_key"]
    team_name = row["team_name"].presence || row["scope_key"]
    team_team_name = row["team_team_name"].presence || row["scope_key"]

    {
      id: "#{row["player_id"]}-#{row["season"]}-#{category}-#{row["scope_type"]}-#{row["scope_key"]}",
      rank: ((page - 1) * per_page) + index + 1,
      season: row["season"].to_i,
      category: category,
      scope: {
        type: row["scope_type"],
        key: row["scope_key"]
      },
      player: {
        id: row["player_id"].to_i,
        mlb_id: row["player_mlb_id"].to_i,
        first_name: row["player_first_name"],
        last_name: row["player_last_name"],
        full_name: [ row["player_first_name"], row["player_last_name"] ].compact.join(" ")
      },
      team: {
        id: row["team_id"]&.to_i,
        mlb_id: row["team_mlb_id"]&.to_i,
        name: team_name,
        abbreviation: team_abbreviation,
        team_name: team_team_name,
        location_name: row["team_location_name"],
        short_name: row["team_short_name"]
      },
      stats: visible_column_definitions.each_with_object({}) do |column_definition, stats|
        stats[column_definition.fetch(:key)] = format_stat_value(row[stat_alias(column_definition.fetch(:key))])
      end
    }
  end

  def format_stat_value(value)
    return nil if value.nil?

    value.respond_to?(:to_s) ? value.to_s : value
  end

  def available_alias_names
    @available_alias_names ||= column_definitions.flat_map { |column_definition| Array(column_definition.fetch(:aliases)) }.uniq
  end

  def visible_column_definitions
    @visible_column_definitions ||= begin
      visible_columns = column_definitions.select { |column_definition| column_available?(column_definition) }
      visible_columns.presence || column_definitions
    end
  end

  def column_available?(column_definition)
    aliases = Array(column_definition.fetch(:aliases))
    return true if (aliases & available_stat_names).any?

    return false unless column_definition[:derived_from] == :earned_runs

    alias_group_available?(%w[ERA era]) && alias_group_available?(%w[inningsPitched IP])
  end

  def alias_group_available?(aliases)
    (Array(aliases) & available_stat_names).any?
  end

  def available_stat_names
    @available_stat_names ||= if stat_type_relation.respond_to?(:where) && stat_type_relation.respond_to?(:pluck)
      stat_type_relation.where(category: category, name: available_alias_names).pluck(:name)
    else
      stat_type_relation
        .select { |stat_type| stat_type.category == category && available_alias_names.include?(stat_type.name) }
        .map(&:name)
    end
  end

  def normalize_scope_type!(filters)
    return unless filters["scope_type"].present?

    scope_type = filters["scope_type"].to_s.downcase
    SCOPE_TYPES.include?(scope_type) ? filters["scope_type"] = scope_type : filters.delete("scope_type")
  end

  def derived_earned_runs_expression
    era_expression = coalesced_alias_expression(%w[ERA era])
    innings_expression = coalesced_alias_expression(%w[inningsPitched IP])

    <<~SQL.squish
      CASE
        WHEN #{era_expression} IS NULL OR #{innings_expression} IS NULL THEN NULL
        ELSE ROUND(
          (
            #{era_expression} *
            (
              FLOOR(#{innings_expression}) +
              ((#{innings_expression} - FLOOR(#{innings_expression})) * 10.0 / 3.0)
            )
          ) / 9.0,
          0
        )
      END
    SQL
  end

  def coalesced_alias_expression(alias_names)
    expressions = alias_names.map { |alias_name| max_case_expression(alias_name) }
    "COALESCE(#{expressions.join(', ')})"
  end
end
