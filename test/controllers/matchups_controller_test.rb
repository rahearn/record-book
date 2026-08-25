require "test_helper"

class MatchupsControllerTest < ActionDispatch::IntegrationTest
  test "shows both sides, the lineups and the benches" do
    get matchup_url(games(:g2023_w1_ab), owner: owners(:alice).id)
    assert_response :success

    assert_match "Week 1 · 2023", response.body
    assert_match "Alice Anders", response.body
    assert_match "Anders Originals", response.body # her 2023 team name
    assert_match "Bob Barker", response.body
    assert_match "100.0", response.body
    assert_match "90.0", response.body
    assert_match "Alice Anders wins by 10.0", response.body

    assert_match "Starting lineups", response.body
    assert_select "div.grid.grid-cols-\\[1fr_46px_1fr\\]", count: 9
    assert_match "Grant Feltz", response.body
    assert_match "Judd Trask", response.body
    # Each player carries the NFL team they played for.
    assert_select "span.truncate", html: %r{Grant Feltz <span class="text-ink/55">BUF</span>}
    assert_match "FLEX", response.body
    assert_match "D/ST", response.body

    # Benches, best score first, and the points they cost her.
    assert_match "Alice Anders — bench", response.body
    assert_match "Rex Calloway", response.body
    assert_select "td", html: %r{Rex Calloway <span class="text-ink/55">SF</span>}
    # He is eligible at two positions, and the bench says so.
    assert_select "td", text: "RB/WR"
    # An injured player is still listed, marked, and left out of the total.
    assert_select "td", html: %r{Vance Ibarra .*<span class="tag tag-outline ml-1">IR</span>}m
    assert_match "9.0 left on the bench", response.body
    assert_no_match(/24\.0 left on the bench/, response.body)
    assert_select ".blueprint", count: 4 # scoreboard, lineups, two benches
    assert_match "9.0 left on the bench", response.body
    assert_match "0.0 left on the bench", response.body
  end

  test "sets each side's season context" do
    get matchup_url(games(:g2023_w1_ab), owner: owners(:alice).id)
    assert_response :success

    # Alice went 2–0 in 2023 averaging 105.0; this 100.0 was 5.0 under.
    assert_match "2–0 that year · season avg 105.0 (-5.0 this week)", response.body
    assert_match "0–2 that year · season avg 87.5 (+2.5 this week)", response.body
  end

  test "the owner parameter chooses the left-hand side" do
    game = games(:g2023_w1_ab)

    get matchup_url(game, owner: owners(:bob).id)
    assert_response :success
    assert_operator response.body.index("Bob Barker"), :<, response.body.index("Alice Anders")

    get matchup_url(game, owner: owners(:alice).id)
    assert_operator response.body.index("Alice Anders"), :<, response.body.index("Bob Barker")
  end

  test "an unknown owner parameter is ignored" do
    get matchup_url(games(:g2023_w1_ab), owner: 999_999)
    assert_response :success
    assert_match "Alice Anders", response.body
  end

  test "links out to the week scoreboard and the series" do
    get matchup_url(games(:g2023_w1_ab), owner: owners(:alice).id)
    assert_response :success

    assert_select "a[href=?]", "/seasons/2023/weeks/1", text: "← Week 1 scoreboard"
    assert_select "a[href=?]",
      "/head-to-head?a=#{owners(:alice).id}&b=#{owners(:bob).id}", text: "Series history"
    assert_select "a[href=?]", "/owners/#{owners(:alice).id}", text: "Alice Anders"
  end

  test "a tiered matchup links back to its own tier's scoreboard" do
    get matchup_url(games(:g2024_w1_cd))
    assert_response :success

    assert_match "Challenger", response.body
    assert_select "a[href=?]", "/seasons/2024/weeks/1?tier=challenger",
      text: "← Week 1 scoreboard"
  end

  test "playoff matchups name the round" do
    get matchup_url(games(:g2024_final_premier))
    assert_response :success
    assert_match "Week 2 · 2024 · Championship", response.body
  end

  test "matchups without lineups on record still show the score" do
    get matchup_url(games(:g2023_w1_cd))
    assert_response :success

    assert_match "Carol Chen wins by 9.5", response.body
    assert_match "No lineups are on record for this matchup", response.body
    assert_select ".blueprint", count: 1 # the scoreboard only
  end

  test "unknown matchups 404" do
    get "/matchups/999999"
    assert_response :not_found
  end

  test "games without two sides 404" do
    lonely = Game.create!(season: seasons(:y2023), week: 5, tier: :unified)
    lonely.performances.create!(owner: owners(:alice), points: 100)

    get matchup_url(lonely)
    assert_response :not_found
  end
end
