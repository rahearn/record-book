require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  test "fixture players are valid" do
    assert players(:alice_qb).valid?
    assert_equal "qb", players(:alice_qb).position
    assert_equal "dst", players(:alice_dst).position
  end

  test "a name is required" do
    player = Player.new(position: :rb)
    assert_not player.valid?
    assert_includes player.errors[:name], "can't be blank"
  end

  test "names are unique within a position but reusable across positions" do
    duplicate = Player.new(name: players(:alice_qb).name, position: :qb)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"

    assert Player.new(name: players(:alice_qb).name, position: :rb).valid?
  end

  test "positions cover every scoring slot" do
    assert_equal %w[qb rb wr te k dst], Player.positions.keys
  end
end
