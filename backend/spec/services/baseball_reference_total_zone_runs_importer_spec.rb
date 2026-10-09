require "rails_helper"

RSpec.describe BaseballReferenceTotalZoneRunsImporter, type: :service do
  it "parses Baseball-Reference player fielding rows and maps Rtot to TZR" do
    body = <<~HTML
      <table id="players_standard_fielding">
        <tbody>
          <tr>
            <td data-stat="name_display" data-append-csv="trammal01">Alan Trammell</td>
            <td data-stat="team_name_abbr">DET</td>
            <td data-stat="f_tz_runs_total">18</td>
          </tr>
        </tbody>
      </table>
    HTML
    response = instance_double(Net::HTTPSuccess, body: body)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_return(response)
    allow(PlayerIdMapping).to receive(:where).with(no_args).and_return(
      double(not: double(pluck: [["trammal01", 123437]]))
    )
    allow(Player).to receive(:where).with(mlb_id: [123437]).and_return(
      [double(mlb_id: 123437, first_name: "Alan", last_name: "Trammell")]
    )

    result = described_class.call(start_year: 1984, end_year: 1984, delay: 0)

    expect(result[:success]).to be(true)
    row = CSV.parse(result.dig(:data, :csv_data), headers: true).first.to_h
    expect(row).to include(
      "season" => "1984",
      "playerId" => "123437",
      "playerFirstName" => "Alan",
      "playerLastName" => "Trammell",
      "TZR" => "18"
    )
  end
end
