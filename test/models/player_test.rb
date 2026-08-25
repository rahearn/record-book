require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  test "fixture players are valid" do
    assert players(:alice_qb).valid?
    assert_equal %w[qb], players(:alice_qb).positions
    assert_equal "BUF", players(:alice_qb).nfl_team
    assert_equal %w[dst], players(:alice_dst).positions
  end

  test "a name, an NFL team and a position are required" do
    player = Player.new
    assert_not player.valid?
    assert_includes player.errors[:name], "can't be blank"
    assert_includes player.errors[:nfl_team], "can't be blank"
    assert_includes player.errors[:positions], "can't be blank"
  end

  test "positions are normalized and checked against the known ones" do
    player = Player.new(name: "Test Player", nfl_team: " sea ", positions: [ " RB ", :wr, "rb" ])
    assert_equal %w[rb wr], player.positions # cased down, trimmed, deduped
    assert_equal "SEA", player.nfl_team
    assert player.valid?

    player.positions = %w[rb punter]
    assert_not player.valid?
    assert_includes player.errors[:positions], "punter is not a position"
  end

  test "a player can be eligible at more than one position" do
    swing = players(:alice_rb4)
    assert_equal %w[rb wr], swing.positions
    assert swing.eligible_for?(:rb)
    assert swing.eligible_for?("wr")
    assert_not swing.eligible_for?(:te)
  end

  test "a name repeats only on another team" do
    starter = players(:alice_qb)
    duplicate = Player.new(name: starter.name, positions: %w[qb], nfl_team: starter.nfl_team)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"

    # Normalization applies before the name is checked for uniqueness.
    duplicate.nfl_team = starter.nfl_team.downcase
    assert_not duplicate.valid?

    # Changing what they play does not make them somebody else.
    duplicate.positions = %w[rb]
    assert_not duplicate.valid?

    # Two Grant Feltzes are fine as long as they play for different teams.
    duplicate.nfl_team = "SEA"
    assert duplicate.valid?
  end

  test "positions cover every scoring slot" do
    assert_equal %w[qb rb wr te k dst], Player::POSITIONS
  end
end
