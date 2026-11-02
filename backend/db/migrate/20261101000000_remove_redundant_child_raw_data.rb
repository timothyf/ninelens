class RemoveRedundantChildRawData < ActiveRecord::Migration[7.1]
  def up
    # Keep source payloads and child rows stable between validation and removal.
    execute "LOCK TABLE roster_snapshot_players, roster_snapshots, trade_participants, trades IN SHARE ROW EXCLUSIVE MODE"

    execute <<~SQL
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1
          FROM roster_snapshot_players AS child
          JOIN roster_snapshots AS snapshot ON snapshot.id = child.roster_snapshot_id
          WHERE child.raw_data <> '{}'::jsonb
            AND NOT EXISTS (
              SELECT 1
              FROM jsonb_array_elements(COALESCE(snapshot.raw_data -> 'roster', '[]'::jsonb)) AS entry
              WHERE entry = child.raw_data
            )
        ) THEN
          RAISE EXCEPTION 'roster_snapshot_players.raw_data contains values absent from parent snapshots';
        END IF;

        IF EXISTS (
          SELECT 1
          FROM trade_participants AS child
          JOIN trades AS trade ON trade.id = child.trade_id
          WHERE child.raw_data <> '{}'::jsonb
            AND NOT EXISTS (
              SELECT 1
              FROM jsonb_array_elements(COALESCE(trade.raw_data -> 'transactions', '[]'::jsonb)) AS entry
              WHERE entry = child.raw_data
            )
        ) THEN
          RAISE EXCEPTION 'trade_participants.raw_data contains values absent from parent trades';
        END IF;
      END
      $$;
    SQL

    remove_column :roster_snapshot_players, :raw_data
    remove_column :trade_participants, :raw_data
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Child source JSON cannot be reconstructed after removal"
  end
end
