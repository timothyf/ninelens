class AddSeasonReviewPitchSpeedIndex < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :pitch_data, [ :release_speed, :game_date ],
      name: "idx_pitch_data_regular_speed_date",
      order: { release_speed: :desc },
      where: "game_type = 'R' AND release_speed IS NOT NULL",
      algorithm: :concurrently
  end
end
