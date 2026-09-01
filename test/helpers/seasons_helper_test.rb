require "test_helper"

class SeasonsHelperTest < ActionView::TestCase
  FakeCell = Struct.new(:highest, :lowest)

  setup do
    @almanac = Almanac.new(promotion_count: 1, relegation_count: 1)
  end

  test "season_summary describes a split season" do
    assert_equal "2 in Premier, 2 in Challenger · 1 promoted, 1 relegated",
      season_summary(@almanac, 2024, owner_count: 2, week_count: 1)
  end

  test "season_summary describes a unified season" do
    assert_equal "4 owners, one league · 2 weeks",
      season_summary(@almanac, 2023, owner_count: 4, week_count: 2)
  end

  test "season_zone_note per tier" do
    ordering = "Ordered by final finish — playoff finishers first, then regular-season order."
    assert_equal "#{ordering} Shaded: bottom 1 relegate to Challenger for 2025.",
      season_zone_note(@almanac, 2024, :premier)
    assert_equal "#{ordering} Shaded: top 1 promote to Premier for 2025.",
      season_zone_note(@almanac, 2024, :challenger)
    assert_equal "#{ordering} Single-tier season — promotion and relegation began in 2024.",
      season_zone_note(@almanac, 2023, :unified)
    assert_equal "#{ordering} Single-tier season.",
      season_zone_note(Almanac.new(games: []), 2023, :unified)
  end

  test "luck_column_note explains the three luck columns" do
    assert_equal "xW is the record a week's score earned against the whole field; Luck is wins " \
      "above it. Opp ± is how far opponents scored below (+) or above (−) their own season average.",
      luck_column_note
  end

  test "season_zone_class shades relegation and promotion" do
    premier = @almanac.standings_for(2024, :premier)
    assert_nil season_zone_class(@almanac, premier.first)
    assert_equal "zone-down", season_zone_class(@almanac, premier.second)

    challenger = @almanac.standings_for(2024, :challenger)
    assert_equal "zone-up", season_zone_class(@almanac, challenger.first)
    assert_nil season_zone_class(@almanac, challenger.second)
  end

  test "matrix_cell_class highlights extremes" do
    assert_equal "tag tag-accent", matrix_cell_class(FakeCell.new(true, false))
    assert_equal "tag tag-outline", matrix_cell_class(FakeCell.new(false, true))
    assert_equal "tag", matrix_cell_class(FakeCell.new(false, false))
    assert_equal "tag tag-accent", matrix_cell_class(FakeCell.new(true, true))
  end
end
