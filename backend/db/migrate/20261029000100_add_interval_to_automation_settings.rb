class AddIntervalToAutomationSettings < ActiveRecord::Migration[7.1]
  def change
    add_column :automation_settings, :interval_minutes, :integer, null: false, default: 15
    add_column :automation_settings, :last_started_at, :datetime
    add_check_constraint :automation_settings, "interval_minutes BETWEEN 5 AND 1440", name: "automation_settings_valid_interval"
  end
end
