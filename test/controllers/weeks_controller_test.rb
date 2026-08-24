require "test_helper"

class WeeksControllerTest < ActionDispatch::IntegrationTest
  test "lists every matchup of the week with its scoring extremes" do
    get week_url(2023, 1)
    assert_response :success

    assert_select "h1", text: "Week 1 · 2023"
    assert_match "Scoreboard", response.body
    assert_match "League · high 100.0 · low 70.5 · average 85.1", response.body

    assert_select ".blueprint", count: 2 # one card per matchup
    assert_match "Alice Anders", response.body
    assert_match "Dan Diaz", response.body
    assert_match "Margin 10.0", response.body
    assert_match "Margin 9.5", response.body
  end

  test "tags the week's high and low scores only" do
    get week_url(2023, 1)
    assert_response :success

    assert_select "span.tag.tag-accent", text: "HIGH", count: 1
    assert_select "span.tag.tag-outline", text: "LOW", count: 1
  end

  test "each card opens its matchup and each side shows its season context" do
    get week_url(2023, 1)
    assert_response :success

    assert_select "a[href=?]", "/matchups/#{games(:g2023_w1_ab).id}"
    assert_select "a[href=?]", "/matchups/#{games(:g2023_w1_cd).id}"
    # Alice averaged 105.0 in 2023 and scored 100.0 here.
    assert_match "Anders Originals · -5.0 vs season avg", response.body
  end

  test "week buttons cover the weeks on record and mark the current one" do
    get week_url(2023, 2)
    assert_response :success

    assert_select "a[href=?]", "/seasons/2023/weeks/1", text: "1"
    assert_select "a.btn-primary", text: "2"
    assert_select "a.btn-secondary", text: "1"
  end

  test "split seasons get a tier switch and keep the tiers apart" do
    get week_url(2024, 1, tier: :premier)
    assert_response :success

    assert_match "Premier · high 120.0", response.body
    assert_match "Alice Anders", response.body
    assert_no_match(/Carol Chen/, response.body)
    assert_select "a[href=?]", "/seasons/2024/weeks/1?tier=challenger", text: "Challenger"

    get week_url(2024, 1, tier: :challenger)
    assert_match "Challenger · high 90.0", response.body
    assert_match "Carol Chen", response.body
    assert_no_match(/Alice Anders/, response.body)
  end

  test "split seasons default to Premier" do
    get week_url(2024, 1)
    assert_response :success
    assert_match "Premier · high 120.0", response.body
  end

  test "playoff weeks name the round" do
    get week_url(2024, 2, tier: :premier)
    assert_response :success

    assert_match "Championship", response.body
    assert_match "Margin 30.0", response.body
  end

  test "links back to the season" do
    get week_url(2024, 1, tier: :challenger)
    assert_response :success
    assert_select "a[href=?]", "/seasons/2024?tier=challenger", text: "2024 season"
  end

  test "the season page's week columns open the scoreboard" do
    get season_url(2023)
    assert_response :success
    assert_select "a[href=?]", "/seasons/2023/weeks/1", text: "W1"
    assert_select "a[href=?]", "/seasons/2023/weeks/2", text: "W2"

    get season_url(2024, tier: :challenger)
    assert_select "a[href=?]", "/seasons/2024/weeks/1?tier=challenger", text: "W1"
  end

  test "unplayed weeks and unknown seasons 404" do
    get "/seasons/2023/weeks/9"
    assert_response :not_found

    get "/seasons/1999/weeks/1"
    assert_response :not_found
  end
end
