class Current < ActiveSupport::CurrentAttributes
  attribute :user, :session, :request_id
end
