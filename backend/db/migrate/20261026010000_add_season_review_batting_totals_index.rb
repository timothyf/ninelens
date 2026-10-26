class AddSeasonReviewBattingTotalsIndex < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :game_player_batting_lines, :game_id,
      name: "idx_game_batting_lines_review_totals",
      include: %i[hits strikeouts walks home_runs triples],
      algorithm: :concurrently
  end
end
