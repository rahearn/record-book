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

  test "the lineup splits into starters and a bench ranked by points" do
    performance = performances(:alice_2023_w1)
    assert performance.lineup?
    assert_equal %w[qb rb rb wr wr te flex k dst], performance.starters.map(&:slot)
    assert_equal [ 18.0, 4.0, 3.5, 2.0 ], performance.bench.map { |entry| entry.points.to_f }
    assert_in_delta 100.0, performance.starters.sum(&:points)
  end

  test "optimal points weigh a dual-eligible player against every slot" do
    # Rex Calloway (18.0, RB/WR) is Alice's best back and her second-best
    # receiver. Filling slots one at a time seats him at running back for
    # 108.0; starting him at receiver instead, so Halloran takes the back
    # slot and Pike the flex, is worth a point more.
    assert_in_delta 109.0, performances(:alice_2023_w1).optimal_points
    assert_in_delta 9.0, performances(:alice_2023_w1).points_left_on_bench
  end

  test "optimal points never fall short of the lineup actually started" do
    Performance.includes(lineup_slots: :player).select(&:lineup?).each do |performance|
      assert_operator performance.optimal_points, :>=, performance.starters.sum(&:points),
        "#{performance.owner.name} could not have done worse than they did"
    end
  end

  test "a slot only opens to a player eligible for it" do
    performance = performances(:alice_2023_w1)
    flex = performance.starters.find(&:flex?)

    assert flex.accepts?(players(:alice_rb4)) # RB/WR
    assert flex.accepts?(players(:alice_te2))
    assert_not flex.accepts?(players(:alice_k))
  end

  test "a lineup nothing on the bench could improve leaves nothing behind" do
    assert_in_delta 90.0, performances(:bob_2023_w1).optimal_points
    assert_in_delta 0.0, performances(:bob_2023_w1).points_left_on_bench
  end

  test "performances without a lineup on record leave nothing on the bench" do
    performance = performances(:carol_2023_w1)
    assert_not performance.lineup?
    assert_empty performance.starters
    assert_empty performance.bench
    assert_equal 0, performance.points_left_on_bench
  end
end
