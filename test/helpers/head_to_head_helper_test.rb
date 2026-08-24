require "test_helper"

class HeadToHeadHelperTest < ActionView::TestCase
  include LeagueHelper

  setup do
    @almanac = Almanac.new
  end

  test "series_display shows wins and any ties" do
    series = @almanac.series_between(owners(:alice), owners(:bob))
    assert_equal "2–0", series_display(series)

    with_ties = Struct.new(:wins_a, :wins_b, :ties).new(3, 2, 1)
    assert_equal "3–2–1", series_display(with_ties)
  end

  test "series_note counts meetings" do
    assert_equal "2 regular-season meetings since 2023",
      series_note(@almanac.series_between(owners(:alice), owners(:bob)))
    assert_equal "These owners have never met.",
      series_note(@almanac.series_between(owners(:alice), owners(:dan)))
  end

  test "comparison rows scale bars to the leader" do
    rows = h2h_comparison_rows(
      @almanac.series_between(owners(:alice), owners(:bob)),
      @almanac.career_for(owners(:alice)),
      @almanac.career_for(owners(:bob)))

    assert_equal [ "Avg in series", "Career PF/g", "Career PA/g", "Career win%", "Luck" ],
      rows.map(&:label)

    pf = rows.second
    assert_equal "110.0", pf.a_display
    assert_equal "90.0", pf.b_display
    assert_equal "100%", pf.a_bar
    assert_equal "81%", pf.b_bar

    win_pct = rows.fourth
    assert_equal "100.0%", win_pct.a_display
    assert_equal "0.0%", win_pct.b_display
    assert_equal "0%", win_pct.b_bar
  end
end
