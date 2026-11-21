require "rails_helper"

RSpec.describe MlbPlayerTeamHistoriesSyncJob, type: :job do
  let(:download) do
    { success: true, data: { payload: { "transactions" => [] }, source_url: "https://example.test", fetched_at: Time.current.iso8601 } }
  end

  it "persists player-by-player progress and the current player" do
    first = create_player(attributes: { first_name: "First", last_name: "Player" })
    second = create_player(attributes: { first_name: "Second", last_name: "Player" })
    run = AdminTaskRun.create!(task_name: "mlb_player_team_histories_sync", total_items: 1)
    allow(MlbPlayerTransactionsDownloader).to receive(:call) do |player_mlb_id:|
      if player_mlb_id == second.mlb_id
        expect(run.reload).to have_attributes(total_items: 2, completed_items: 1, failed_items: 0,
          current_item_mlb_id: second.mlb_id)
        expect(run.estimated_remaining_seconds).to be_a(Integer)
      end
      download
    end
    allow(MlbPlayerTeamHistoryImporter).to receive(:call).and_return(
      success: true, data: { transaction_count: 0, tenure_count: 0 }
    )

    described_class.perform_now(run.id)

    expect(run.reload).to have_attributes(status: "completed", total_items: 2,
      completed_items: 2, failed_items: 0, current_item_mlb_id: nil, current_item_label: nil)
    expect(run.result_data).to include("progress_unit" => "players", "success" => true)
    expect(run.result_data.dig("data", "selected_player_count")).to eq(2)
    expect(MlbPlayerTransactionsDownloader).to have_received(:call).with(player_mlb_id: first.mlb_id)
  end

  it "stops after the current player when cancellation is requested" do
    first = create_player
    create_player
    run = AdminTaskRun.create!(task_name: "mlb_player_team_histories_sync", total_items: 2)
    allow(MlbPlayerTransactionsDownloader).to receive(:call) do |player_mlb_id:|
      run.update!(cancel_requested_at: Time.current)
      download
    end
    allow(MlbPlayerTeamHistoryImporter).to receive(:call).and_return(
      success: true, data: { transaction_count: 0, tenure_count: 0 }
    )

    described_class.perform_now(run.id)

    expect(run.reload).to have_attributes(status: "cancelled", completed_items: 1,
      failed_items: 0, current_item_mlb_id: nil)
    expect(run.result_data.dig("data", "cancelled")).to be(true)
    expect(MlbPlayerTransactionsDownloader).to have_received(:call).once.with(player_mlb_id: first.mlb_id)
  end

  it "retains successful and failed player counts on a failed run" do
    first = create_player
    second = create_player
    run = AdminTaskRun.create!(task_name: "mlb_player_team_histories_sync", total_items: 2)
    allow(MlbPlayerTransactionsDownloader).to receive(:call) do |player_mlb_id:|
      player_mlb_id == first.mlb_id ? download : { success: false, message: "MLB request failed", data: {} }
    end
    allow(MlbPlayerTeamHistoryImporter).to receive(:call).and_return(
      success: true, data: { transaction_count: 0, tenure_count: 0 }
    )

    described_class.perform_now(run.id)

    expect(run.reload).to have_attributes(status: "failed", total_items: 2,
      completed_items: 1, failed_items: 1, error_message: include("1 of 2"))
    expect(run.result_data.dig("data", "failures")).to include(include("mlb_id" => second.mlb_id))
  end
end
