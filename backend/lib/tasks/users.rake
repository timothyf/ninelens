namespace :users do
  desc "Create the first human administrator (ADMIN_EMAIL, ADMIN_NAME, and ADMIN_PASSWORD required)"
  task bootstrap_admin: :environment do
    result = AdministratorBootstrap.call(
      email: ENV.fetch("ADMIN_EMAIL"),
      name: ENV.fetch("ADMIN_NAME"),
      password: ENV.fetch("ADMIN_PASSWORD")
    )

    if result.created
      puts "Created administrator #{result.user.email}."
    else
      puts "Administrator #{result.user.email} already exists; no changes made."
    end
  rescue KeyError => error
    abort "Missing required environment variable: #{error.key}"
  rescue AdministratorBootstrap::AlreadyProvisionedError, ActiveRecord::RecordInvalid => error
    abort "Administrator bootstrap failed: #{error.message}"
  end
end
