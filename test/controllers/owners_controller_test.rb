require "test_helper"

class OwnersControllerTest < ActionDispatch::IntegrationTest
  test "defaults to the all-time leader" do
    get owners_url
    assert_response :success

    assert_select "h1", text: "Alice Anders"
    assert_match "Anders Aces", response.body
    assert_match "All-time record", response.body
    assert_match "3–0", response.body
    assert_match "Season by season", response.body
    assert_match "2024 week by week · Premier", response.body
    assert_match "Head-to-head, all time", response.body
    assert_match "2–0", response.body # series vs Bob
  end

  test "shows a requested owner" do
    get owner_url(owners(:bob))
    assert_response :success
    assert_select "h1", text: "Bob Barker"
    assert_match "0–3", response.body
  end

  test "week-by-week bars render for losses as well as wins" do
    get owner_url(owners(:bob), season: 2023) # 0-2 that season
    assert_response :success
    assert_select "span.bg-neutral-400[style*='width']", count: 2
    assert_select "span.bg-accent[style*='width']", count: 0

    get owner_url(owners(:alice), season: 2023) # 2-0 that season
    assert_select "span.bg-accent[style*='width']", count: 2
    assert_select "span.bg-neutral-400[style*='width']", count: 0
  end

  test "picks the week-by-week season from the season parameter" do
    get owner_url(owners(:alice), season: 2023)
    assert_response :success
    assert_match "2023 week by week · Open", response.body
    assert_match "Bob Barker", response.body # week 1 opponent
  end

  test "falls back to the latest season for unplayed chart years" do
    get owner_url(owners(:alice), season: 1999)
    assert_response :success
    assert_match "2024 week by week · Premier", response.body
  end

  test "unknown owners 404" do
    get "/owners/999999"
    assert_response :not_found
  end

  test "owners without games 404" do
    idle = Owner.create!(name: "Idle Ivan", team_name: "Idle FC")
    get owner_url(idle)
    assert_response :not_found
  end

  test "renders an empty state when no games are on record" do
    Performance.delete_all
    Game.delete_all
    Season.delete_all
    Owner.delete_all

    get owners_url
    assert_response :success
    assert_match "No games on record yet", response.body
  end
end
