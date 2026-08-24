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

  test "playoff and regular_season scopes partition games" do
    assert_equal 2, Game.playoff.count
    assert_equal Game.count - 2, Game.regular_season.count
    assert Game.playoff.all?(&:playoff?)
  end

  test "a round name marks a game as a playoff game" do
    assert_predicate games(:g2024_final_premier), :playoff?
    assert_not games(:g2024_final_premier).regular_season?
    assert_predicate games(:g2024_w1_ab), :regular_season?
    assert_not games(:g2024_w1_ab).playoff?
  end

  test "championship and third place rounds are recognized by name" do
    assert_predicate games(:g2024_final_premier), :championship?
    assert_not games(:g2024_final_premier).third_place?
    assert_predicate Game.new(round_name: "Third Place"), :third_place?
    assert_not Game.new(round_name: "Semifinal").championship?
  end

  test "playoff-week games must carry a round name" do
    game = Game.new(season: seasons(:y2024), tier: :premier, week: 2)
    assert_not game.valid?
    assert_includes game.errors[:round_name], "must be set for playoff week 2 and later"

    game.round_name = "Championship"
    assert game.valid?
  end

  test "round names are not allowed before the playoff start week" do
    game = Game.new(season: seasons(:y2024), tier: :premier, week: 1, round_name: "Semifinal")
    assert_not game.valid?
    assert_includes game.errors[:round_name], "cannot be set before playoff week 2"
  end

  test "each tier follows its own playoff format" do
    # Challenger playoffs start week 3, so its week 2 is still regular season.
    assert_predicate Game.new(season: seasons(:y2024), tier: :challenger, week: 2), :valid?
    assert_not Game.new(season: seasons(:y2024), tier: :challenger, week: 3).valid?
  end

  test "seasons without a playoff format are unconstrained" do
    assert_predicate Game.new(season: seasons(:y2023), week: 9), :valid?
    assert_predicate Game.new(season: seasons(:y2023), week: 3, round_name: "Championship"), :valid?
  end
end
