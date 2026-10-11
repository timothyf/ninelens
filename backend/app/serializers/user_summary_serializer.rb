class UserSummarySerializer
  def self.call(user)
    return unless user

    {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role
    }
  end
end
