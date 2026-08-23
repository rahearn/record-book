require "test_helper"

class PerformanceTest < ActiveSupport::TestCase
  test "fixture performances are valid" do
    assert performances(:alice_2023_w1).valid?
  end

  test "points must be present and non-negative" do
    performance = performances(:alice_2023_w1)
    performance.points = nil
    assert_not performance.valid?

    performance.points = -1
    assert_not performance.valid?
    assert_includes performance.errors[:points], "must be greater than or equal to 0"
  end

  test "an owner appears at most once per game" do
    duplicate = Performance.new(game: games(:g2023_w1_ab), owner: owners(:alice), points: 50)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:owner_id], "has already been taken"
  end
end
