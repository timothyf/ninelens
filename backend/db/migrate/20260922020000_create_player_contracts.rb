class CreatePlayerContracts < ActiveRecord::Migration[7.1]
  def change
    create_table :player_contracts do |t|
      t.references :player, null: false, foreign_key: true
      t.integer :season, null: false
      t.string :team_slug
      t.string :contract
      t.integer :aav_amount
      t.integer :salary_amount
      t.jsonb :salary_by_year, null: false, default: {}
      t.string :source_player_id
      t.string :source_url, null: false
      t.datetime :fetched_at, null: false
      t.timestamps
    end

    add_index :player_contracts, [:player_id, :season], unique: true
    add_index :player_contracts, :season
  end
end
