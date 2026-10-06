class GamesIndexQuery
  DEFAULT_PAGE = 1
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  def initialize(params:, relation: Game.all)
    @params = params
    @relation = relation
  end

  def results
    filtered_relation
      .chronological
      .offset((page - 1) * per_page)
      .limit(per_page)
  end

  def metadata
    {
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      filters: normalized_filters
    }
  end

  private

  attr_reader :params, :relation

  def base_relation
    @base_relation ||= relation
      .includes(:schedule, :home_team, :away_team, :home_probable_pitcher, :away_probable_pitcher)
      .joins(:schedule)
  end

  def filtered_relation
    @filtered_relation ||= begin
      # MLB publishes "if necessary" postseason placeholders before it knows
      # whether the game will be needed. They are not real scheduled games
      # when they remain in a scheduled/preview state.
      scope = base_relation.where.not(
        "games.status IN (?) AND COALESCE(games.raw_data ->> 'ifNecessary', 'N') = ?",
        %w[scheduled preview],
        "Y"
      )

      if normalized_filters[:team_id].present?
        scope = scope.where(
          "games.home_team_id = :team_id OR games.away_team_id = :team_id",
          team_id: normalized_filters[:team_id]
        )
      end

      scope = scope.where("games.official_date >= ?", normalized_filters[:start_date]) if normalized_filters[:start_date].present?
      scope = scope.where("games.official_date <= ?", normalized_filters[:end_date]) if normalized_filters[:end_date].present?
      scope = scope.where(schedules: { season: normalized_filters[:season] }) if normalized_filters[:season].present?

      if normalized_filters[:status].present?
        scope = scope.where("LOWER(games.status) = ?", normalized_filters[:status])
      end

      if normalized_filters[:game_type].present?
        scope = scope.where("UPPER(games.game_type) = ?", normalized_filters[:game_type])
      end

      scope
    end
  end

  def normalized_filters
    @normalized_filters ||= begin
      filters = raw_filters
        .slice("team_id", "start_date", "end_date", "season", "status", "game_type")
        .transform_values { |value| value.is_a?(String) ? value.strip : value }
        .compact_blank

      integer_filter!(filters, "team_id")
      integer_filter!(filters, "season")
      date_filter!(filters, "start_date")
      date_filter!(filters, "end_date")
      normalize_date_bounds!(filters)
      filters["status"] = filters["status"].downcase if filters["status"].present?
      filters["game_type"] = filters["game_type"].upcase if filters["game_type"].present?

      filters.symbolize_keys
    end
  end

  def raw_filters
    nested_filters = params.fetch("filter", params.fetch(:filter, {}))
    nested_hash = nested_filters.respond_to?(:to_h) ? nested_filters.to_h.deep_stringify_keys : {}
    top_level_hash = params.to_h.deep_stringify_keys.slice("team_id", "start_date", "end_date", "season", "status", "game_type")

    nested_hash.merge(top_level_hash)
  end

  def page
    @page ||= positive_integer(params["page"] || params[:page], DEFAULT_PAGE)
  end

  def per_page
    @per_page ||= [ positive_integer(params["per_page"] || params[:per_page], DEFAULT_PER_PAGE), MAX_PER_PAGE ].min
  end

  def total_count
    @total_count ||= filtered_relation.count
  end

  def total_pages
    return 0 if total_count.zero?

    (total_count.to_f / per_page).ceil
  end

  def positive_integer(value, fallback)
    integer = Integer(value, exception: false)
    integer&.positive? ? integer : fallback
  end

  def integer_filter!(filters, key)
    return unless filters[key].present?

    integer = Integer(filters[key], exception: false)
    integer.present? ? filters[key] = integer : filters.delete(key)
  end

  def date_filter!(filters, key)
    return unless filters[key].present?

    filters[key] = Date.iso8601(filters[key].to_s)
  rescue ArgumentError
    filters.delete(key)
  end

  def normalize_date_bounds!(filters)
    return unless filters["start_date"].present? && filters["end_date"].present?
    return unless filters["start_date"] > filters["end_date"]

    filters["start_date"], filters["end_date"] = filters["end_date"], filters["start_date"]
  end
end
