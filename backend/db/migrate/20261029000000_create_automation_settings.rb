class CreateAutomationSettings < ActiveRecord::Migration[7.1]
  def change
    create_table :automation_settings do |t|
      t.string :key, null: false
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :automation_settings, :key, unique: true
  end
end
