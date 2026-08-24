require "test_helper"

class LeagueControllerTest < ActionDispatch::IntegrationTest
  test "renders the league page" do
    get root_url
    assert_response :success

    assert_select "h2", text: "All-time by owner"
    assert_match "Alice Anders", response.body
    assert_match "Anders Aces", response.body

    # Record cards: highest single score and biggest blowout from fixtures.
    assert_match "Highest score, any week", response.body
    assert_match "120.0", response.body
    assert_match "Alice Anders over Bob Barker", response.body

    # Ladder for the season after the latest tiered season.
    assert_match "2025 ladder", response.body
  end

  test "renders an empty state when no games are on record" do
    wipe_league_data

    get root_url
    assert_response :success
    assert_match "No games on record yet", response.body
  end
end
