require "test_helper"

class HistoryControllerTest < ActionDispatch::IntegrationTest
  def rows(table)
    css_select("##{table} tbody tr")
  end

  test "lists every owner's season across the years, best scoring first" do
    get history_url
    assert_response :success

    assert_select "h1", text: "Seasons"
    assert_select "nav a.btn-primary", text: "History"
    # Four owners in each of 2023 and 2024; 2024's tiers sit side by side.
    assert_equal 8, rows("history-seasons").size
    top = rows("history-seasons").first
    assert_match "2024", top.text
    assert_match "Alice Anders", top.text
    assert_match "120.00", top.text # PF/g
  end

  test "re-sorts the seasons by any column" do
    get history_url(view: "seasons", sort: "low", direction: "asc")
    assert_response :success

    lowest = rows("history-seasons").first
    assert_match "2023", lowest.text
    assert_match "Dan Diaz", lowest.text # 70.50 in week 1
    assert_select "#history-seasons th a", text: "Low ▲"
  end

  test "sorting on clutch leaves the seasons without one at the bottom either way" do
    %w[desc asc].each do |direction|
      get history_url(view: "seasons", sort: "clutch", direction: direction)
      assert_response :success
      rows = css_select("#history-seasons tbody tr")
      expected = direction == "desc" ? "Alice Anders" : "Bob Barker"
      assert_match expected, rows.first.text
      assert_equal [ "—" ] * 4, rows.to_a.last(4).map { |row| row.css("td")[11].text }
    end
  end

  test "filters the seasons to one owner" do
    get history_url(view: "seasons", owner: owners(:bob).id)
    assert_response :success

    assert_equal 2, rows("history-seasons").size
    assert rows("history-seasons").all? { |row| row.text.include?("Bob Barker") }
  end

  test "lists regular-season scores, highest first" do
    get history_url(view: "games")
    assert_response :success

    assert_select "h2", text: /Highest scores/
    assert_match "12 scores", response.body # six games, two sides each
    top = rows("history-games").first
    assert_match "Alice Anders", top.text
    assert_match "120.00", top.text
    # Playoff games stay out: Alice's 130 in the 2024 final is not on the list.
    assert_no_match "130.00", response.body
  end

  test "the bottom of the margin column is the worst loss" do
    get history_url(view: "games", sort: "margin", direction: "asc")
    assert_response :success

    assert_select "h2", text: /Worst losses/
    worst = rows("history-games").first
    assert_match "Bob Barker", worst.text
    assert_match "-25.00", worst.text
  end

  test "combined scores list each game once" do
    get history_url(view: "games", sort: "combined")
    assert_response :success

    assert_match "6 games", response.body
    top = rows("history-games").first
    assert_match "215.00", top.text
    assert_match "Alice Anders", top.text
  end

  test "totals players across their starts" do
    get history_url(view: "players")
    assert_response :success

    assert_select "h2", text: "Player careers"
    top = rows("history-players").first
    assert_match "Grant Feltz", top.text
    assert_match "22.50", top.text
    # Reserves score nothing: Vance Ibarra's 25 came on injured reserve.
    assert_no_match "Vance Ibarra", response.body
  end

  test "the bench table takes in players who never started" do
    get history_url(view: "players", sort: "bench")
    assert_response :success

    top = rows("history-players").first
    assert_match "Rex Calloway", top.text
    assert_match "18.00", top.text
  end

  test "filters players by position and keeps the filter across groupings" do
    get history_url(view: "players", position: "qb")
    assert_response :success

    assert_equal 2, rows("history-players").size
    assert_select ".seg a[href*='position=qb']", text: "Single games"
  end

  test "lists the best single starts" do
    get history_url(view: "players", by: "game")
    assert_response :success

    assert_select "h2", text: "Single-game starts"
    top = rows("history-players").first
    assert_match "Grant Feltz", top.text
    assert_match "QB", top.text
    assert_select "#history-players tbody tr a[href=?]",
      matchup_path(games(:g2023_w1_ab), owner: owners(:alice).id)
  end

  test "points per start needs enough starts to qualify" do
    get history_url(view: "players", sort: "ppg")
    assert_response :success

    assert_empty rows("history-players")
    assert_match "needs 10 starts to qualify", response.body
  end

  test "shows an empty state with no games" do
    wipe_league_data
    get history_url
    assert_response :success
    assert_match "No games on record yet.", response.body
  end
end
