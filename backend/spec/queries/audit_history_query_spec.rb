require "rails_helper"

RSpec.describe AuditHistoryQuery do
  it "returns serialized history for an auditable and its related records" do
    user = create_user(role: "scout")
    watchlist = Watchlist.create!(name: "Deadline targets", owner: user)
    entry = watchlist.entries.create!(player: create_player)
    unrelated = Watchlist.create!(name: "Unrelated", owner: user)
    AuditLog.create!(
      user:,
      action: "created",
      auditable_type: "Watchlist",
      auditable_id: watchlist.id,
      change_set: { "name" => [ nil, watchlist.name ] },
      created_at: 2.minutes.ago
    )
    AuditLog.create!(
      user:,
      action: "updated",
      auditable_type: "WatchlistEntry",
      auditable_id: entry.id,
      change_set: { "priority" => %w[medium high] },
      metadata: { "source" => "spec" },
      created_at: 1.minute.ago
    )
    AuditLog.create!(
      user:,
      action: "updated",
      auditable_type: "Watchlist",
      auditable_id: unrelated.id
    )

    history = described_class.call(
      auditable: watchlist,
      related: { WatchlistEntry => [ entry.id ] }
    )

    expect(history.pluck(:action)).to eq(%w[updated created])
    expect(history.first).to include(
      auditable_type: "WatchlistEntry",
      auditable_id: entry.id,
      metadata: { "source" => "spec" },
      user: UserSummarySerializer.call(user)
    )
  end

  it "applies the requested history limit" do
    user = create_user
    watchlist = Watchlist.create!(name: "Limited history", owner: user)
    2.times do |index|
      AuditLog.create!(
        user:,
        action: "update_#{index}",
        auditable_type: "Watchlist",
        auditable_id: watchlist.id,
        created_at: index.minutes.ago
      )
    end

    history = described_class.call(auditable: watchlist, limit: 1)

    expect(history.one?).to be(true)
    expect(history.first.fetch(:action)).to eq("update_0")
  end
end
