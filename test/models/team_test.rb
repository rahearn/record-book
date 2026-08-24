require "test_helper"

class TeamTest < ActiveSupport::TestCase
  test "fixture teams are valid" do
    assert teams(:alice_2023).valid?
  end

  test "requires a name" do
    team = Team.new(owner: owners(:alice), season: seasons(:y2023))
    assert_not team.valid?
    assert_includes team.errors[:name], "can't be blank"
  end

  test "an owner fields one team per season" do
    duplicate = Team.new(owner: owners(:alice), season: seasons(:y2023), name: "Second Squad")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:owner_id], "has already been taken"
  end
end
