class CreateAlertCenter < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :alert_digest_frequency, :string, null: false, default: "off"
    add_column :users, :alert_digest_day, :integer
    add_column :users, :alert_digest_hour, :integer, null: false, default: 8
    add_check_constraint :users, "alert_digest_frequency IN ('off', 'daily', 'weekly')", name: "users_valid_alert_digest_frequency"
    add_check_constraint :users, "alert_digest_day IS NULL OR alert_digest_day BETWEEN 0 AND 6", name: "users_valid_alert_digest_day"
    add_check_constraint :users, "alert_digest_hour BETWEEN 0 AND 23", name: "users_valid_alert_digest_hour"

    create_table :alert_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :player, foreign_key: true
      t.references :watchlist, foreign_key: true
      t.string :name
      t.string :minimum_severity, null: false, default: "warning"
      t.string :event_types, array: true, null: false, default: []
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :alert_subscriptions, [ :user_id, :player_id ], unique: true, where: "player_id IS NOT NULL", name: "idx_alert_subscriptions_user_player"
    add_index :alert_subscriptions, [ :user_id, :watchlist_id ], unique: true, where: "watchlist_id IS NOT NULL", name: "idx_alert_subscriptions_user_watchlist"
    add_check_constraint :alert_subscriptions, "(player_id IS NOT NULL) <> (watchlist_id IS NOT NULL)", name: "alert_subscriptions_one_target"
    add_check_constraint :alert_subscriptions, "minimum_severity IN ('warning', 'critical')", name: "alert_subscriptions_valid_severity"

    create_table :alerts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :player_trend_event, null: false, foreign_key: true
      t.references :alert_subscription, foreign_key: true
      t.references :assigned_to, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "active"
      t.jsonb :supporting_evidence, null: false, default: {}
      t.jsonb :links, null: false, default: {}
      t.datetime :acknowledged_at
      t.datetime :snoozed_until
      t.datetime :resolved_at
      t.datetime :last_digest_at
      t.timestamps
    end
    add_index :alerts, [ :user_id, :status, :created_at ], name: "idx_alerts_user_inbox"
    add_index :alerts, [ :user_id, :player_trend_event_id ], unique: true, name: "idx_alerts_user_event_unique"
    add_check_constraint :alerts, "status IN ('active', 'acknowledged', 'snoozed', 'resolved')", name: "alerts_valid_status"
  end
end
