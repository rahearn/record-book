require "test_helper"

class OwnerTest < ActiveSupport::TestCase
  test "fixture owners are valid" do
    assert owners(:alice).valid?
  end

  test "requires a name" do
    owner = Owner.new(team_name: "The Team")
    assert_not owner.valid?
    assert_includes owner.errors[:name], "can't be blank"
  end

  test "requires a team name" do
    owner = Owner.new(name: "New Owner")
    assert_not owner.valid?
    assert_includes owner.errors[:team_name], "can't be blank"
  end

  test "name must be unique" do
    owner = Owner.new(name: owners(:alice).name, team_name: "Copycats")
    assert_not owner.valid?
    assert_includes owner.errors[:name], "has already been taken"
  end

  test "initials come from each part of the name" do
    assert_equal "AA", owners(:alice).initials
    assert_equal "MO", Owner.new(name: "Marcy Ostrander").initials
    assert_equal "BS", Owner.new(name: "bobby sarnicola").initials
  end
end
