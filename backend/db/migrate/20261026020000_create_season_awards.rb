class CreateSeasonAwards < ActiveRecord::Migration[7.1]
  def change
    create_table :season_awards do |t|
      t.integer :season, null: false
      t.string :award_id, null: false
      t.string :award_name, null: false
      t.bigint :player_mlb_id, null: false
      t.string :player_name, null: false
      t.bigint :team_mlb_id
      t.string :position
      t.date :awarded_on
      t.string :source_url, null: false
      t.timestamps
    end
    add_index :season_awards, [ :season, :award_id, :player_mlb_id ], unique: true,
      name: "idx_season_awards_unique_recipient"

    create_table :season_award_syncs do |t|
      t.integer :season, null: false
      t.datetime :last_checked_at
      t.datetime :last_synced_at
      t.timestamps
    end
    add_index :season_award_syncs, :season, unique: true
  end
end
