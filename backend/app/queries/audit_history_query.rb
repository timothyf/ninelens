class AuditHistoryQuery
  DEFAULT_LIMIT = 100

  def self.call(auditable:, related: {}, limit: DEFAULT_LIMIT)
    new(auditable:, related:, limit:).call
  end

  def initialize(auditable:, related: {}, limit: DEFAULT_LIMIT)
    @auditable = auditable
    @related = related
    @limit = limit
  end

  def call
    audit_logs.map { |log| AuditLogSerializer.call(log) }
  end

  private

  attr_reader :auditable, :related, :limit

  def audit_logs
    filters = related.each_with_object(base_filter) do |(type, ids), values|
      normalized_type = normalize_type(type)
      values[normalized_type] = (Array(values[normalized_type]) + Array(ids).compact).uniq
    end
    scope = filters.reduce(AuditLog.none) do |relation, (type, ids)|
      next relation if ids.empty?

      relation.or(AuditLog.where(auditable_type: type, auditable_id: ids))
    end

    scope.includes(:user).order(created_at: :desc).limit(limit)
  end

  def base_filter
    { auditable.class.base_class.name => [ auditable.id ] }
  end

  def normalize_type(type)
    type.respond_to?(:base_class) ? type.base_class.name : type.to_s
  end
end
