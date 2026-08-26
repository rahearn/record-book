require "test_helper"

class HeadToHeadControllerTest < ActionDispatch::IntegrationTest
  test "defaults to the top two all-time owners" do
    get head_to_head_url
    assert_response :success

    # Alice (1st) vs Carol (2nd): one meeting, 2023 week 2.
    assert_match "Alice Anders", response.body
    assert_match "Carol Chen", response.body
    assert_match "1–0", response.body
    assert_match "1 regular-season meeting since 2023", response.body
    assert_match "Every meeting", response.body
  end

  test "defaults skip a higher-ranked former owner in favor of the top two current owners" do
    eve = Owner.create!(name: "Eve Ellis")
    frank = Owner.create!(name: "Frank Ford")
    past_season = Season.create!(year: 2010)
    Team.create!(owner: eve, season: past_season, name: "Ellis Eagles")
    Team.create!(owner: frank, season: past_season, name: "Ford Falcons")
    game = Game.create!(season: past_season, week: 1)
    Performance.create!(game: game, owner: eve, points: 999)
    Performance.create!(game: game, owner: frank, points: 1)

    almanac = Almanac.new
    assert_equal eve, almanac.all_time_standings.first.owner # outranks Alice and Carol all time...

    get head_to_head_url
    assert_response :success
    # ...but neither fielded a 2024 team, so Alice and Carol default in instead.
    assert_select "#owner_a option[selected]", text: "Alice Anders — Anders Aces"
    assert_select "#owner_b option[selected]", text: "Carol Chen — Chen Chargers"
  end

  test "compares the requested owners with a full meeting log" do
    get head_to_head_url(a: owners(:alice).id, b: owners(:bob).id)
    assert_response :success

    assert_match "2–0", response.body
    assert_match "2 regular-season meetings since 2023", response.body
    assert_select "tbody tr", count: 2
    # Each meeting row is addressable so week-by-week chart links can target it.
    assert_select "tr#meeting-2024-w1"
    assert_select "tr#meeting-2023-w1"
    # Every meeting opens on its own matchup page, from owner A's side.
    assert_select "a[href=?]",
      "/matchups/#{games(:g2023_w1_ab).id}?owner=#{owners(:alice).id}", text: "Matchup"
    assert_select "a[href=?]",
      "/matchups/#{games(:g2024_w1_ab).id}?owner=#{owners(:alice).id}", text: "Matchup"
    assert_match "Career PF/g", response.body
    assert_match "Avg in series", response.body
    # 2024 meeting: 120.0 to 95.0, margin 25.0.
    assert_match "25.0", response.body
  end

  test "owners who never met" do
    get head_to_head_url(a: owners(:alice).id, b: owners(:dan).id)
    assert_response :success
    assert_match "0–0", response.body
    assert_match "These owners have never met", response.body
    assert_match "No games between these owners are on record", response.body
  end

  test "unknown owners 404" do
    get head_to_head_url(a: owners(:alice).id, b: 999_999)
    assert_response :not_found
  end

  test "owners without games 404" do
    idle = Owner.create!(name: "Idle Ivan")
    get head_to_head_url(a: idle.id, b: owners(:bob).id)
    assert_response :not_found
  end

  test "renders an empty state when no games are on record" do
    wipe_league_data

    get head_to_head_url
    assert_response :success
    assert_match "No games on record yet", response.body
  end
end
