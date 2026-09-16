# Test-only database reset helper. Every caller is guarded so it cannot be used
# against a development or production database by mistake.
module TestDatabaseCleaner
  EXCLUDED_TABLES = %w[schema_migrations ar_internal_metadata].freeze

  def self.reset!
    raise "TestDatabaseCleaner may only run in the test environment" unless Rails.env.test?

    connection = ActiveRecord::Base.connection
    tables = connection.tables - EXCLUDED_TABLES
    return if tables.empty?

    quoted_tables = tables.map { |table| connection.quote_table_name(table) }
    connection.execute("TRUNCATE TABLE #{quoted_tables.join(', ')} RESTART IDENTITY CASCADE")
  end
end
