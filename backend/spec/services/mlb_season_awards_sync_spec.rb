require "rails_helper"

RSpec.describe MlbSeasonAwardsSync, type: :service do
  let(:season) { ApplicationCalendar.current_date.year - 1 }

  def recipient(award_id, player_id)
    {
      "id" => award_id,
      "name" => award_id,
      "season" => season.to_s,
      "date" => "#{season}-11-20",
      "player" => { "id" => player_id, "nameFirstLast" => "Winner #{player_id}", "primaryPosition" => { "abbreviation" => "P" } },
      "team" => { "id" => 116 }
    }
  end

  it "stores all six official award lists and reuses the season cache" do
    allow(MlbStatsApiClient).to receive(:get_json) do |url, **|
      award_id = url.match(%r{/awards/([^/]+)/recipients})[1]
      { "awards" => [recipient(award_id, SeasonAward::AWARD_IDS.index(award_id) + 100)] }
    end

    first = described_class.call(season: season)
    inserts = []
    subscriber = ->(*, payload) { inserts << payload[:sql] if payload[:sql].include?('INSERT INTO "season_award_syncs"') }
    second = ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      described_class.call(season: season)
    end

    expect(first[:success]).to be(true)
    expect(first.dig(:data, :award_count)).to eq(6)
    expect(second.dig(:data, :refreshed)).to be(false)
    expect(inserts).to be_empty
    expect(SeasonAward.where(season: season).pluck(:award_id)).to match_array(SeasonAward::AWARD_IDS)
    expect(MlbStatsApiClient).to have_received(:get_json).exactly(6).times
  end

  it "keeps the last complete award set when one league request fails" do
    allow(MlbStatsApiClient).to receive(:get_json) do |url, **|
      award_id = url.match(%r{/awards/([^/]+)/recipients})[1]
      { "awards" => [recipient(award_id, SeasonAward::AWARD_IDS.index(award_id) + 100)] }
    end
    described_class.call(season: season)
    original_ids = SeasonAward.where(season: season).pluck(:award_id, :player_mlb_id)

    allow(MlbStatsApiClient).to receive(:get_json) do |url, **|
      raise "MLB unavailable" if url.include?("/NLGG/")
      { "awards" => [] }
    end
    result = described_class.call(season: season, force: true)

    expect(result[:success]).to be(false)
    expect(SeasonAward.where(season: season).pluck(:award_id, :player_mlb_id)).to eq(original_ids)
  end
end
