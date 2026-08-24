require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  test "fixture players are valid" do
    assert players(:alice_qb).valid?
    assert_equal "qb", players(:alice_qb).position
    assert_equal "BUF", players(:alice_qb).nfl_team
    assert_equal "dst", players(:alice_dst).position
  end

  test "a name and an NFL team are required" do
    player = Player.new(position: :rb)
    assert_not player.valid?
    assert_includes player.errors[:name], "can't be blank"
    assert_includes player.errors[:nfl_team], "can't be blank"
  end

  test "NFL teams are stored as upper-case abbreviations" do
    assert_equal "SEA", Player.new(nfl_team: " sea ").nfl_team
  end

  test "a name repeats only on another position or another team" do
    starter = players(:alice_qb)
    duplicate = Player.new(name: starter.name, position: :qb, nfl_team: starter.nfl_team)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"

    # Normalization applies before the name is checked for uniqueness.
    duplicate.nfl_team = starter.nfl_team.downcase
    assert_not duplicate.valid?

    # Two Grant Feltzes are fine as long as they play for different teams.
    duplicate.nfl_team = "SEA"
    assert duplicate.valid?
    assert Player.new(name: starter.name, position: :rb, nfl_team: starter.nfl_team).valid?
  end

  test "positions cover every scoring slot" do
    assert_equal %w[qb rb wr te k dst], Player.positions.keys
  end
end
