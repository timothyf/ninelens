require "digest"
require "json"
require "shellwords"

class StorageAudit
  ARCHIVAL_JSON_COLUMNS = [
    { table: "games", column: "raw_data" },
    { table: "games", column: "boxscore_raw_data" },
    { table: "games", column: "live_feed_raw_data" },
    { table: "plate_appearances", column: "raw_data" },
    { table: "lineup_entries", column: "raw_data" },
    { table: "game_player_batting_lines", column: "raw_data" },
    { table: "game_player_pitching_lines", column: "raw_data" }
  ].freeze

  CRITICAL_TABLES = %w[
    games
    pitch_data
    plate_appearances
    player_season_stats
    players
    teams
    game_player_batting_lines
    game_player_pitching_lines
    lineup_entries
    stat_types
    schedules
  ].freeze

  MINIMUM_FREE_DISK_BYTES_FOR_REWRITE = 4.gigabytes

  def self.call(connection: ActiveRecord::Base.connection)
    new(connection: connection).call
  end

  def initialize(connection: ActiveRecord::Base.connection)
    @connection = connection
  end

  def call
    row_counts = fetch_row_counts
    json_columns = fetch_json_column_sizes
    archival_json = summarize_archival_json(json_columns)

    {
      audited_at: Time.current.iso8601,
      rails_env: Rails.env,
      database: database_name,
      postgresql_version: postgresql_version,
      database_size_bytes: database_size_bytes,
      database_size_pretty: database_size_pretty,
      migration_targets: {
        expected_post_archival_database_size_bytes: estimate_post_archival_size(database_size_bytes, archival_json[:total_bytes]),
        expected_post_archival_database_size_pretty: number_to_human_size(
          estimate_post_archival_size(database_size_bytes, archival_json[:total_bytes])
        ),
        archival_json_bytes: archival_json[:total_bytes],
        archival_json_pretty: number_to_human_size(archival_json[:total_bytes])
      },
      tables: fetch_table_sizes,
      row_counts: row_counts,
      critical_row_counts: row_counts.slice(*CRITICAL_TABLES),
      row_count_checksum: row_count_checksum(row_counts),
      critical_table_fingerprints: critical_table_fingerprints,
      integrity_checksum: integrity_checksum(critical_table_fingerprints),
      json_columns: json_columns,
      archival_json_columns: archival_json,
      disk_space: disk_space_info,
      rewrite_readiness: rewrite_readiness
    }
  end

  private

  attr_reader :connection

  def database_name
    connection.current_database
  end

  def postgresql_version
    connection.select_value("SELECT version()")
  end

  def database_size_bytes
    connection.select_value("SELECT pg_database_size(current_database())").to_i
  end

  def database_size_pretty
    connection.select_value("SELECT pg_size_pretty(pg_database_size(current_database()))")
  end

  def fetch_table_sizes
    rows = connection.select_all(<<~SQL.squish)
      SELECT
        c.relname AS table_name,
        pg_total_relation_size(c.oid) AS total_bytes,
        pg_relation_size(c.oid) AS heap_bytes,
        pg_indexes_size(c.oid) AS index_bytes,
        COALESCE(pg_total_relation_size(c.reltoastrelid), 0) AS toast_bytes
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relkind = 'r'
      ORDER BY total_bytes DESC
    SQL

    rows.map do |row|
      {
        table_name: row["table_name"],
        total_bytes: row["total_bytes"].to_i,
        total_pretty: number_to_human_size(row["total_bytes"].to_i),
        heap_bytes: row["heap_bytes"].to_i,
        index_bytes: row["index_bytes"].to_i,
        toast_bytes: row["toast_bytes"].to_i
      }
    end
  end

  def fetch_row_counts
    table_names = connection.select_values(<<~SQL.squish)
      SELECT c.relname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relkind = 'r'
      ORDER BY c.relname
    SQL

    table_names.index_with do |table_name|
      connection.select_value("SELECT COUNT(*) FROM #{connection.quote_table_name(table_name)}").to_i
    end
  end

  def fetch_json_column_sizes
    json_columns = connection.select_all(<<~SQL.squish)
      SELECT table_name, column_name
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND udt_name = 'jsonb'
      ORDER BY table_name, column_name
    SQL

    json_columns.map do |row|
      table_name = row["table_name"]
      column_name = row["column_name"]
      quoted_table = connection.quote_table_name(table_name)
      quoted_column = connection.quote_column_name(column_name)

      stats = connection.select_one(<<~SQL.squish)
        SELECT
          COUNT(*) AS row_count,
          COUNT(*) FILTER (WHERE #{quoted_column} IS NOT NULL AND #{quoted_column} <> '{}'::jsonb) AS populated_row_count,
          COALESCE(SUM(pg_column_size(#{quoted_column})), 0) AS payload_bytes
        FROM #{quoted_table}
      SQL

      {
        table_name: table_name,
        column_name: column_name,
        row_count: stats["row_count"].to_i,
        populated_row_count: stats["populated_row_count"].to_i,
        payload_bytes: stats["payload_bytes"].to_i,
        payload_pretty: number_to_human_size(stats["payload_bytes"].to_i)
      }
    end
  end

  def summarize_archival_json(json_columns)
    indexed = json_columns.index_by { |entry| [ entry[:table_name], entry[:column_name] ] }
    columns = ARCHIVAL_JSON_COLUMNS.map do |definition|
      entry = indexed[[ definition[:table], definition[:column] ]]
      if entry
        entry.merge(archival: true, present: true)
      else
        {
          table_name: definition[:table],
          column_name: definition[:column],
          row_count: 0,
          populated_row_count: 0,
          payload_bytes: 0,
          payload_pretty: number_to_human_size(0),
          archival: true,
          present: false
        }
      end
    end

    total_bytes = columns.sum { |entry| entry[:payload_bytes] }

    {
      total_bytes: total_bytes,
      total_pretty: number_to_human_size(total_bytes),
      columns: columns
    }
  end

  def row_count_checksum(row_counts)
    canonical = row_counts.sort.to_h
    Digest::SHA256.hexdigest(JSON.generate(canonical))
  end

  def critical_table_fingerprints
    CRITICAL_TABLES.index_with do |table_name|
      quoted_table = connection.quote_table_name(table_name)
      value = connection.select_value(<<~SQL.squish)
        SELECT COUNT(*)::text || ':' ||
          COALESCE(SUM(hashtextextended(row_to_json(records)::text, 0)::numeric), 0)::text
        FROM #{quoted_table} records
      SQL

      Digest::SHA256.hexdigest(value.to_s)
    end
  end

  def integrity_checksum(fingerprints)
    Digest::SHA256.hexdigest(JSON.generate(fingerprints.sort.to_h))
  end

  def estimate_post_archival_size(database_size_bytes, archival_json_bytes)
    [ database_size_bytes - archival_json_bytes, 0 ].max
  end

  def disk_space_info
    data_directory = connection.select_value("SHOW data_directory")
    backup_directory = baseline_directory.to_s
    paths = [ data_directory, existing_path(backup_directory) ].uniq

    paths.map do |path|
      stat = filesystem_stat(path)
      {
        path: path,
        total_bytes: stat[:total_bytes],
        available_bytes: stat[:available_bytes],
        used_bytes: stat[:used_bytes],
        available_pretty: number_to_human_size(stat[:available_bytes]),
        total_pretty: number_to_human_size(stat[:total_bytes])
      }
    end
  end

  def rewrite_readiness
    data_directory = connection.select_value("SHOW data_directory")
    data_directory_stat = filesystem_stat(data_directory)
    backup_directory_stat = filesystem_stat(existing_path(baseline_directory.to_s))
    available_bytes = data_directory_stat[:available_bytes].to_i
    database_size = database_size_bytes
    recommended_free_bytes = [ MINIMUM_FREE_DISK_BYTES_FOR_REWRITE, database_size ].max

    {
      minimum_free_bytes_required: MINIMUM_FREE_DISK_BYTES_FOR_REWRITE,
      recommended_free_bytes: recommended_free_bytes,
      recommended_free_pretty: number_to_human_size(recommended_free_bytes),
      database_directory: data_directory,
      database_directory_available_bytes: data_directory_stat[:available_bytes],
      database_directory_available_pretty: number_to_human_size(data_directory_stat[:available_bytes].to_i),
      backup_directory_available_bytes: backup_directory_stat[:available_bytes],
      backup_directory_available_pretty: number_to_human_size(backup_directory_stat[:available_bytes].to_i),
      database_size_bytes: database_size,
      ready_for_table_rewrite: available_bytes >= recommended_free_bytes && available_bytes.positive?
    }
  end

  def baseline_directory
    Rails.root.join("tmp/storage_baselines")
  end

  def filesystem_stat(path)
    return { total_bytes: nil, available_bytes: nil, used_bytes: nil } unless File.exist?(path)

    output = `df -Pk #{Shellwords.escape(path)} 2>/dev/null | tail -1`
    fields = output.split
    if fields.length >= 4
      total_kib = fields[1].to_i
      available_kib = fields[3].to_i
      used_kib = fields[2].to_i
      {
        total_bytes: total_kib * 1024,
        available_bytes: available_kib * 1024,
        used_bytes: used_kib * 1024
      }
    else
      { total_bytes: nil, available_bytes: nil, used_bytes: nil }
    end
  end

  def existing_path(path)
    candidate = Pathname.new(path)
    candidate = candidate.parent until candidate.exist? || candidate.root?
    candidate.to_s
  end

  def number_to_human_size(number)
    ActiveSupport::NumberHelper.number_to_human_size(number)
  end
end
