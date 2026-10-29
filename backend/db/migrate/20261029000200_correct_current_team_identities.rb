class CorrectCurrentTeamIdentities < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      UPDATE teams AS team
      SET name = current_team.name,
          abbreviation = current_team.abbreviation,
          team_name = current_team.team_name,
          location_name = current_team.location_name,
          short_name = current_team.short_name,
          updated_at = CURRENT_TIMESTAMP
      FROM (VALUES
        (113, 'Cincinnati Reds', 'CIN', 'Reds', 'Cincinnati', 'Reds'),
        (114, 'Cleveland Guardians', 'CLE', 'Guardians', 'Cleveland', 'Guardians'),
        (117, 'Houston Astros', 'HOU', 'Astros', 'Houston', 'Astros'),
        (119, 'Los Angeles Dodgers', 'LAD', 'Dodgers', 'Los Angeles', 'Dodgers'),
        (133, 'Athletics', 'ATH', 'Athletics', 'Athletics', 'Athletics'),
        (137, 'San Francisco Giants', 'SF', 'Giants', 'San Francisco', 'Giants'),
        (140, 'Texas Rangers', 'TEX', 'Rangers', 'Texas', 'Rangers'),
        (142, 'Minnesota Twins', 'MIN', 'Twins', 'Minnesota', 'Twins'),
        (144, 'Atlanta Braves', 'ATL', 'Braves', 'Atlanta', 'Braves')
      ) AS current_team(mlb_id, name, abbreviation, team_name, location_name, short_name)
      WHERE team.mlb_id = current_team.mlb_id
        AND (team.name, team.abbreviation, team.team_name, team.location_name, team.short_name)
            IS DISTINCT FROM
            (current_team.name, current_team.abbreviation, current_team.team_name, current_team.location_name, current_team.short_name)
    SQL
  end

  def down
    # Historical names cannot be reconstructed from the shared team record.
  end
end
