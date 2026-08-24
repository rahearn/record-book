require "test_helper"

class OwnerTest < ActiveSupport::TestCase
  test "fixture owners are valid" do
    assert owners(:alice).valid?
  end

  test "requires a name" do
    owner = Owner.new
    assert_not owner.valid?
    assert_includes owner.errors[:name], "can't be blank"
  end

  test "name must be unique" do
    owner = Owner.new(name: owners(:alice).name)
    assert_not owner.valid?
    assert_includes owner.errors[:name], "has already been taken"
  end

  test "initials come from each part of the name" do
    assert_equal "AA", owners(:alice).initials
    assert_equal "MO", Owner.new(name: "Marcy Ostrander").initials
    assert_equal "BS", Owner.new(name: "bobby sarnicola").initials
  end

  test "team_name is the most recent season's name" do
    assert_equal "Anders Aces", owners(:alice).team_name
    assert_equal "Barker Bandits", owners(:bob).team_name
    assert_nil Owner.new(name: "Nameless").team_name
  end

  test "team_name_in returns that season's name, falling back to the most recent" do
    assert_equal "Anders Originals", owners(:alice).team_name_in(2023)
    assert_equal "Anders Aces", owners(:alice).team_name_in(2024)
    assert_equal "Anders Aces", owners(:alice).team_name_in(1999)
  end
end
