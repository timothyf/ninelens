namespace :test do
  desc "Reset the test database without touching development or production data"
  task reset: :environment do
    TestDatabaseCleaner.reset!
  end
end
