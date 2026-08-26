require "test_helper"

class LeagueControllerTest < ActionDispatch::IntegrationTest
  test "renders the league page" do
    get root_url
    assert_response :success

    assert_select "h2", text: "All-time by owner"
    assert_match "Alice Anders", response.body
    assert_match "Anders Aces", response.body

    # Luck left the table; Runner-up sits to the right of Titles.
    assert_select "th", text: "Luck", count: 0
    assert_select "th", text: "Titles"
    assert_select "th", text: "Runner-up"

    # Record cards: highest single score and biggest blowout from fixtures.
    assert_match "Highest score, any week", response.body
    assert_match "120.0", response.body
    assert_match "Alice Anders over Bob Barker", response.body

    # Ladder for the season after the latest tiered season.
    assert_match "2025 ladder", response.body
  end

  test "record cards link to the matchup that set them" do
    get root_url
    assert_response :success

    # Highest score, biggest blowout, and highest combined all come from
    # the same 2024 game; the lowest score from 2023.
    assert_select "a[href=?]", matchup_path(games(:g2024_w1_ab)), count: 3
    assert_select "a[href=?]", matchup_path(games(:g2023_w1_cd)), count: 1
  end

  test "sortable columns reorder the all-time table" do
    # Ascending PA/g puts Dan (85.0) ahead of Bob (108.3).
    get root_url(sort: "pag", direction: "asc")
    assert_response :success
    assert_operator response.body.index("Dan Diaz"), :<, response.body.index("Bob Barker")
    assert_match "PA/g ▲", response.body

    # Runner-up finishes: Bob (1) rises to the top.
    get root_url(sort: "runner_up")
    assert_operator response.body.index("Bob Barker"), :<, response.body.index("Alice Anders")
    assert_match "Runner-up ▼", response.body

    get root_url(sort: "titles")
    assert_operator response.body.index("Alice Anders"), :<, response.body.index("Bob Barker")
  end

  test "unknown sort parameters fall back to the default order" do
    get root_url(sort: "hacked")
    assert_response :success
    assert_operator response.body.index("Alice Anders"), :<, response.body.index("Bob Barker")
    assert_match "Win% ▼", response.body
  end

  test "renders an empty state when no games are on record" do
    wipe_league_data

    get root_url
    assert_response :success
    assert_match "No games on record yet", response.body
  end
end
