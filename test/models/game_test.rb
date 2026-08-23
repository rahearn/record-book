require "test_helper"

class GameTest < ActiveSupport::TestCase
  test "fixture games are valid" do
    assert games(:g2023_w1_ab).valid?
  end

  test "tier defaults to unified" do
    assert_predicate Game.new, :unified?
  end

  test "tiered fixtures use their tiers" do
    assert_predicate games(:g2024_w1_ab), :premier?
    assert_predicate games(:g2024_w1_cd), :challenger?
  end

  test "week must be a positive integer" do
    game = Game.new(season: seasons(:y2023), week: 0)
    assert_not game.valid?
    assert_includes game.errors[:week], "must be greater than 0"
  end
end
