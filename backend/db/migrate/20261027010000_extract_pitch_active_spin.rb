class ExtractPitchActiveSpin < ActiveRecord::Migration[7.1]
  def up
    add_column :pitch_data, :active_spin, :float

    # Match the profile's previous lookup order: active_spin takes precedence,
    # then spin_efficiency. Ruby's to_f returned 0 for nonnumeric source text.
    execute <<~SQL
      UPDATE pitch_data
      SET active_spin = COALESCE(
        substring(
          COALESCE(raw_data ->> 'active_spin', raw_data ->> 'spin_efficiency')
          FROM '^[[:space:]]*[+-]?(?:[0-9]+(?:[.][0-9]*)?|[.][0-9]+)(?:[eE][+-]?[0-9]+)?'
        )::double precision,
        0.0
      )
      WHERE raw_data ->> 'active_spin' IS NOT NULL
         OR raw_data ->> 'spin_efficiency' IS NOT NULL
    SQL

    remove_column :pitch_data, :raw_data
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Pitch source JSON cannot be reconstructed after removal"
  end
end
