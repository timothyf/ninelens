class GameSerializer
  def self.call(game, include_schedule: true)
    new(game, include_schedule: include_schedule).as_json
  end

  def initialize(game, include_schedule: true)
    @game = game
    @include_schedule = include_schedule
  end

  def as_json
    data = {
      id: game.id,
      mlb_id: game.mlb_id,
      official_date: game.official_date,
      scheduled_at: game.scheduled_at,
      game_type: game.game_type,
      series_description: game.raw_data.to_h["seriesDescription"],
      series_game_number: game.raw_data.to_h["seriesGameNumber"],
      if_necessary: game.raw_data.to_h["ifNecessary"] == "Y",
      status: game.status,
      detailed_status: game.detailed_status,
      venue_name: game.venue_name,
      game_number: game.game_number,
      doubleheader: game.doubleheader,
      home_score: game.home_score,
      away_score: game.away_score,
      home_team: serialize_team(game.home_team),
      away_team: serialize_team(game.away_team),
      home_probable_pitcher: serialize_player(game.home_probable_pitcher),
      away_probable_pitcher: serialize_player(game.away_probable_pitcher),
      source_name: game.source_name,
      source_url: game.source_url,
      last_synced_at: game.last_synced_at,
      details_last_synced_at: game.details_last_synced_at,
      created_at: game.created_at,
      updated_at: game.updated_at
    }
    data[:schedule] = serialize_schedule(game.schedule) if include_schedule
    data
  end

  private

  attr_reader :game, :include_schedule

  def serialize_team(team)
    {
      id: team.id,
      mlb_id: team.mlb_id,
      name: team.name,
      abbreviation: team.abbreviation,
      team_name: team.team_name,
      location_name: team.location_name,
      short_name: team.short_name
    }
  end

  def serialize_player(player)
    return if player.nil?

    {
      id: player.id,
      mlb_id: player.mlb_id,
      first_name: player.first_name,
      last_name: player.last_name,
      full_name: player.full_name
    }
  end

  def serialize_schedule(schedule)
    {
      id: schedule.id,
      season: schedule.season,
      schedule_type: schedule.schedule_type,
      start_date: schedule.start_date,
      end_date: schedule.end_date,
      source_key: schedule.source_key,
      last_synced_at: schedule.last_synced_at
    }
  end
end
