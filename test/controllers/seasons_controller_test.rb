require "test_helper"

class SeasonsControllerTest < ActionDispatch::IntegrationTest
  test "defaults to the latest season's premier standings" do
    get seasons_url
    assert_response :success

    assert_select "h1", text: "2024"
    assert_select "h2", text: /Premier standings/
    assert_match "Alice Anders", response.body
    assert_match "Scores by week", response.body
    assert_no_match "Carol Chen", response.body

    # The week-2 Championship is a playoff game and stays out of the
    # regular-season matrix.
    assert_select "th", text: "W1"
    assert_select "th", text: "W2", count: 0
  end

  test "standings carry the schedule beside the record" do
    get season_url(2023)
    assert_response :success

    assert_select "#standings th", text: "xW"
    assert_select "#standings th", text: "Luck"
    assert_select "#standings th", text: "Opp ±"
    assert_match "Luck is wins above it", response.body

    # Alice outscored the field in both weeks, so her two wins were the
    # two her scores earned.
    alice = css_select("#standings tbody tr").find { |row| row.text.include?("Alice Anders") }
    assert_equal [ "2.00", "+0.00" ], alice.css("td")[7, 2].map(&:text)
  end

  test "shows the challenger tier when requested" do
    get season_url(2024, tier: "challenger")
    assert_response :success

    assert_select "h2", text: /Challenger standings/
    assert_match "Carol Chen", response.body
    assert_no_match "Alice Anders", response.body
    assert_match "promote to Premier for 2025", response.body
    # With the league's four promotion spots, both fixture challenger rows shade.
    assert_select "tr.zone-up", count: 2
  end

  test "shades the relegation zone in premier" do
    get season_url(2024)
    assert_response :success
    assert_match "relegate to Challenger for 2025", response.body
    assert_select "tr.zone-down"
  end

  test "shows the playoff bracket for the displayed tier" do
    get season_url(2024)
    assert_response :success

    assert_match "Playoffs", response.body
    assert_match "Top 2 · from week 2", response.body
    assert_match "Championship", response.body
    assert_match "130.0", response.body
    assert_match "CHAMPION", response.body
    # The challenger final stays off the premier page.
    assert_no_match "99.0", response.body

    get season_url(2024, tier: "challenger")
    assert_match "Top 2 · from week 3", response.body
    assert_match "99.0", response.body
    assert_no_match "130.0", response.body
  end

  test "playoff rounds link to their week's matchups" do
    get season_url(2024)
    assert_response :success
    assert_select "a[href=?]", week_path(2024, 2, tier: "premier"), text: "W2"

    get season_url(2024, tier: "challenger")
    assert_response :success
    assert_select "a[href=?]", week_path(2024, 3, tier: "challenger"), text: "W3"
  end

  test "standings put the playoff finishers on top, then regular-season order" do
    # 2025 regular season: Alice 1st, Carol 2nd, Bob 3rd, Dan 4th. Bob
    # wins the title over Carol, and Dan takes third from Alice.
    season = Season.create!(year: 2025)
    play(season, week: 1, scores: { alice: 100.0, bob: 90.0 })
    play(season, week: 1, scores: { carol: 95.0, dan: 80.0 })
    play(season, week: 2, round_name: "Championship", scores: { bob: 120.0, carol: 100.0 })
    play(season, week: 2, round_name: "Third Place", scores: { dan: 90.0, alice: 80.0 })

    get season_url(2025)
    assert_response :success

    assert_equal %w[1 2 3 4], css_select("#standings tbody td:first-child").map { |cell| cell.text.strip }
    assert_equal [ "Bob Barker", "Carol Chen", "Dan Diaz", "Alice Anders" ],
      css_select("#standings tbody td:nth-child(2) a").map(&:text)
    assert_match "Ordered by final finish", response.body
  end

  test "seasons without playoff games have no playoff section" do
    get season_url(2023)
    assert_response :success
    assert_no_match "Playoffs", response.body
  end

  test "standings show that season's team name" do
    get season_url(2023)
    assert_match "Anders Originals", response.body
    assert_no_match "Anders Aces", response.body

    get season_url(2024)
    assert_match "Anders Aces", response.body
    assert_no_match "Anders Originals", response.body
  end

  test "shows a unified season without tier tabs" do
    get season_url(2023)
    assert_response :success

    assert_select "h2", text: /League standings/
    assert_match "4 owners, one league · 2 weeks", response.body
    assert_match "promotion and relegation began in 2024", response.body
    assert_no_match "seg-opt", response.body
    # Every owner appears, with week columns W1 and W2.
    assert_match "Dan Diaz", response.body
    assert_select "th", text: "W1"
    assert_select "th", text: "W2"
  end

  test "accepts the year as a query parameter from the year select" do
    get seasons_url(year: 2023)
    assert_response :success
    assert_select "h1", text: "2023"
  end

  test "unknown years 404" do
    get season_url(1999)
    assert_response :not_found
  end

  test "renders an empty state when no games are on record" do
    wipe_league_data

    get seasons_url
    assert_response :success
    assert_match "No games on record yet", response.body
  end

  private

  def play(season, week:, scores:, round_name: nil)
    game = season.games.create!(week: week, tier: :unified, round_name: round_name)
    scores.each { |owner, points| game.performances.create!(owner: owners(owner), points: points) }
    game
  end
end
