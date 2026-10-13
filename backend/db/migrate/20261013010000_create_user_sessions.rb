class CreateUserSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :user_sessions, :token_digest, unique: true
    add_index :user_sessions, [ :user_id, :expires_at ]
    add_index :user_sessions, :revoked_at

    # Legacy bearer tokens had no expiry or session identity. Invalidate them
    # rather than silently converting them into long-lived sessions.
    remove_index :users, :auth_token_digest
    remove_column :users, :auth_token_digest, :string
  end
end
