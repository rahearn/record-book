require "test_helper"

class WeeksHelperTest < ActionView::TestCase
  include LeagueHelper

  setup { @book = Almanac.new }

  test "week_title names the week and year" do
    assert_equal "Week 3 · 2024", week_title(2024, 3)
  end

  test "week_summary reports the league or tier with the week's spread" do
    assert_equal "League · high 100.0 · low 70.5 · average 85.1",
      week_summary(@book.scoreboard_for(2023, 1, :unified), split: false)
    assert_equal "Premier · high 120.0 · low 95.0 · average 107.5",
      week_summary(@book.scoreboard_for(2024, 1, :premier), split: true)
  end

  test "badges mark only the week's best and worst scores" do
    board = @book.scoreboard_for(2023, 1, :unified)
    by_owner = board.sides.index_by(&:owner)

    assert_equal [ "HIGH", "tag-accent" ], scoreboard_badge(board, by_owner[owners(:alice)])
    assert_equal [ "LOW", "tag-outline" ], scoreboard_badge(board, by_owner[owners(:dan)])
    assert_nil scoreboard_badge(board, by_owner[owners(:bob)])
  end

  test "the winning side of a card is emphasized" do
    matchup = @book.scoreboard_for(2023, 1, :unified).matchups
      .find { |game| game.sides.map(&:owner).include?(owners(:alice)) }
    alice, bob = matchup.sides.partition { |side| side.owner == owners(:alice) }.flatten

    assert_equal "font-semibold", scoreboard_side_class(matchup, alice)
    assert_nil scoreboard_side_class(matchup, bob)
  end

  test "the current week's button is the primary one" do
    assert_equal "btn btn-primary min-w-[38px] px-2 py-1", week_button_class(3, 3)
    assert_equal "btn btn-secondary min-w-[38px] px-2 py-1", week_button_class(4, 3)
  end
end
