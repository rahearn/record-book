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

  test "compares the requested owners with a full meeting log" do
    get head_to_head_url(a: owners(:alice).id, b: owners(:bob).id)
    assert_response :success

    assert_match "2–0", response.body
    assert_match "2 regular-season meetings since 2023", response.body
    assert_select "tbody tr", count: 2
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
    idle = Owner.create!(name: "Idle Ivan", team_name: "Idle FC")
    get head_to_head_url(a: idle.id, b: owners(:bob).id)
    assert_response :not_found
  end

  test "renders an empty state when no games are on record" do
    Performance.delete_all
    Game.delete_all
    Season.delete_all
    Owner.delete_all

    get head_to_head_url
    assert_response :success
    assert_match "No games on record yet", response.body
  end
end
