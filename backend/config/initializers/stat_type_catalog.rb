Rails.application.config.to_prepare do
  begin
    StatType.load_catalog_cache!
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError, PG::ConnectionBad
    # Allow Rails to boot before the database is available. The first cached
    # lookup will retry through Active Record once a connection exists.
    StatType.invalidate_catalog_cache!
  rescue ActiveRecord::StatementInvalid => error
    # A fresh database has no lookup tables until db:prepare runs. Do not let
    # the cache warm-up prevent Rails from booting in that first-run state.
    raise unless error.cause.is_a?(PG::UndefinedTable)

    StatType.invalidate_catalog_cache!
  end
end
