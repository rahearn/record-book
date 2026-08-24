require "test_helper"

class OwnersHelperTest < ActionView::TestCase
  include LeagueHelper

  FakeScore = Struct.new(:result)

  test "finish_display stars first place" do
    assert_equal "1st ★", finish_display(1)
    assert_equal "2nd", finish_display(2)
    assert_equal "4th", finish_display(4)
  end

  test "owner_blurb summarizes tenure and next tier" do
    almanac = Almanac.new(promotion_count: 1, relegation_count: 1)
    assert_equal "2 seasons · joined 2023 · Premier in 2025",
      owner_blurb(almanac, almanac.career_for(owners(:alice)))
    assert_equal "2 seasons · joined 2023 · Challenger in 2025",
      owner_blurb(almanac, almanac.career_for(owners(:bob)))
  end

  test "owner_blurb omits the tier without a ladder" do
    owner_a = Owner.new(name: "Solo A")
    owner_b = Owner.new(name: "Solo B")
    game = Game.new(season: Season.new(year: 2030), week: 1)
    game.performances.build(owner: owner_a, points: 100)
    game.performances.build(owner: owner_b, points: 90)

    almanac = Almanac.new(games: [ game ])
    assert_equal "1 season · joined 2030", owner_blurb(almanac, almanac.career_for(owner_a))
  end

  test "league_rank_note and best_finish_note" do
    assert_equal "League rank 2 of 20", league_rank_note(2, 20)

    almanac = Almanac.new
    assert_equal "Best finish: 1st", best_finish_note(almanac.career_for(owners(:alice)))
    assert_equal "Best finish: 2nd", best_finish_note(almanac.career_for(owners(:dan)))
  end

  test "luck_note direction" do
    assert_equal "Opponents underperform vs. me", luck_note(3.2)
    assert_equal "Opponents get up for me", luck_note(-1.5)
  end

  test "bar_percent scales against the maximum" do
    assert_equal "50.0%", bar_percent(60, 120)
    assert_equal "83.3%", bar_percent(100, 120)
  end

  test "week result labels and tags" do
    assert_equal "W", week_result_label(FakeScore.new(:win))
    assert_equal "L", week_result_label(FakeScore.new(:loss))
    assert_equal "T", week_result_label(FakeScore.new(:tie))
    assert_equal "tag-accent", week_result_tag_class(FakeScore.new(:win))
    assert_equal "tag-neutral", week_result_tag_class(FakeScore.new(:loss))
    assert_equal "tag-outline", week_result_tag_class(FakeScore.new(:tie))
  end
end
