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

  test "defaults to showing current owners, with the Current filter marked active" do
    get root_url
    assert_response :success
    assert_select ".seg-on", text: "Current"
  end

  test "rows number 1-n over the rows actually shown, not by all-time rank" do
    # A former owner who outranks everyone all time: without him the four
    # current owners still number 1..4 rather than starting at 2.
    eve = Owner.create!(name: "Eve Ellis")
    frank = Owner.create!(name: "Frank Ford")
    past_season = Season.create!(year: 2010)
    Team.create!(owner: eve, season: past_season, name: "Ellis Eagles")
    Team.create!(owner: frank, season: past_season, name: "Ford Falcons")
    game = Game.create!(season: past_season, week: 1)
    Performance.create!(game: game, owner: eve, points: 999)
    Performance.create!(game: game, owner: frank, points: 1)

    get root_url
    assert_response :success
    assert_equal %w[1 2 3 4], css_select("tbody tr td:first-child").map(&:text)

    # And the numbering follows the rows as sorted, staying 1..n.
    get root_url(sort: "pag", direction: "asc")
    assert_response :success
    assert_equal %w[1 2 3 4], css_select("tbody tr td:first-child").map(&:text)

    get root_url(scope: "all")
    assert_response :success
    assert_equal %w[1 2 3 4 5 6], css_select("tbody tr td:first-child").map(&:text)
  end

  test "an owner without a team in the most recent season is hidden by default and shown under All" do
    eve = Owner.create!(name: "Eve Ellis")
    frank = Owner.create!(name: "Frank Ford")
    past_season = Season.create!(year: 2010)
    Team.create!(owner: eve, season: past_season, name: "Ellis Eagles")
    Team.create!(owner: frank, season: past_season, name: "Ford Falcons")
    game = Game.create!(season: past_season, week: 1)
    Performance.create!(game: game, owner: eve, points: 50)
    Performance.create!(game: game, owner: frank, points: 40)

    get root_url
    assert_response :success
    assert_no_match "Eve Ellis", response.body

    get root_url(scope: "all")
    assert_response :success
    assert_select ".seg-on", text: "All"
    assert_match "Eve Ellis", response.body
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
