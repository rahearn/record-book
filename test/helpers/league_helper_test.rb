require "test_helper"

class LeagueHelperTest < ActionView::TestCase
  FakeRecord = Struct.new(:wins, :losses, :ties)
  FakeBook = Struct.new(:first_year, :latest_year) do
    def empty? = false
  end

  test "points_display formats to two decimals" do
    assert_equal "110.00", points_display(110)
    assert_equal "93.33", points_display(BigDecimal("280") / 3)
  end

  test "signed_points_display keeps the sign" do
    assert_equal "+5.00", signed_points_display(5)
    assert_equal "-4.08", signed_points_display(-4.08)
    assert_equal "+0.00", signed_points_display(0)
  end

  test "win_percentage_display shows a percentage" do
    assert_equal "100.0%", win_percentage_display(1.0)
    assert_equal "66.7%", win_percentage_display(2.0 / 3)
  end

  test "record_display hides ties unless present" do
    assert_equal "10–4", record_display(FakeRecord.new(10, 4, 0))
    assert_equal "10–4–1", record_display(FakeRecord.new(10, 4, 1))
  end

  test "titles_display uses an em dash for zero" do
    assert_equal "—", titles_display(0)
    assert_equal "2", titles_display(2)
  end

  test "tier labels and tag classes" do
    assert_equal "Premier", tier_label(:premier)
    assert_equal "Challenger", tier_label("challenger")
    assert_equal "Open", tier_label("unified")
    assert_equal "tag-accent", tier_tag_class(:premier)
    assert_equal "tag-neutral", tier_tag_class("challenger")
    assert_equal "tag-outline", tier_tag_class("unified")
  end

  test "movement labels and tag classes" do
    assert_equal "UP", movement_label(:promoted)
    assert_equal "DOWN", movement_label(:relegated)
    assert_equal "HELD", movement_label(:held)
    assert_equal "tag-accent", movement_tag_class(:promoted)
    assert_equal "tag-neutral", movement_tag_class(:relegated)
    assert_equal "tag-outline", movement_tag_class(:held)
  end

  test "sortable_header marks the active column and toggles direction" do
    inactive = sortable_header("PF/g", "pfg", active_sort: "win_pct", direction: "desc")
    assert_includes inactive, ">PF/g</a>"
    assert_includes inactive, "sort=pfg"
    assert_includes inactive, "direction=desc"

    active = sortable_header("PF/g", "pfg", active_sort: "pfg", direction: "desc")
    assert_includes active, "PF/g ▼"
    assert_includes active, "direction=asc"

    flipped = sortable_header("PF/g", "pfg", active_sort: "pfg", direction: "asc")
    assert_includes flipped, "PF/g ▲"
    assert_includes flipped, "direction=desc"
  end

  test "league_tagline covers the recorded era" do
    assert_equal "Record book", league_tagline(Almanac.new(games: []))
    assert_equal "Record book · 2011—2025", league_tagline(FakeBook.new(2011, 2025))
    assert_equal "Record book · 2023", league_tagline(FakeBook.new(2023, 2023))
  end

  test "founders_note pluralizes" do
    assert_equal "1 founder remains", founders_note(1)
    assert_equal "8 founders remain", founders_note(8)
  end
end
