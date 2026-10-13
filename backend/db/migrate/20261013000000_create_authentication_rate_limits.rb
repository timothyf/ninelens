class CreateAuthenticationRateLimits < ActiveRecord::Migration[7.1]
  def change
    create_table :authentication_rate_limits do |t|
      t.string :action, null: false
      t.string :identifier_digest, null: false
      t.datetime :window_started_at, null: false
      t.integer :attempt_count, null: false, default: 0
      t.timestamps
    end

    add_index :authentication_rate_limits,
      [ :action, :identifier_digest ],
      unique: true,
      name: "idx_auth_rate_limits_action_identifier"
    add_index :authentication_rate_limits, :window_started_at
    add_check_constraint :authentication_rate_limits,
      "attempt_count >= 0",
      name: "authentication_rate_limits_nonnegative_attempts"
  end
end
