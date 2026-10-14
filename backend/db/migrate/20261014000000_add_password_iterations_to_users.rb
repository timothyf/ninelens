class AddPasswordIterationsToUsers < ActiveRecord::Migration[7.1]
  LEGACY_PASSWORD_ITERATIONS = 120_000
  CURRENT_PASSWORD_ITERATIONS = 600_000

  def up
    add_column :users, :password_iterations, :integer,
      null: false,
      default: LEGACY_PASSWORD_ITERATIONS
    change_column_default :users, :password_iterations,
      from: LEGACY_PASSWORD_ITERATIONS,
      to: CURRENT_PASSWORD_ITERATIONS
    add_check_constraint :users,
      "password_iterations >= #{LEGACY_PASSWORD_ITERATIONS}",
      name: "users_password_iterations_minimum"
  end

  def down
    remove_check_constraint :users, name: "users_password_iterations_minimum"
    remove_column :users, :password_iterations
  end
end
