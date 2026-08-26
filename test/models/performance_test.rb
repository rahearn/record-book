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

  test "the lineup splits into starters and reserves, the bench ranked by points" do
    performance = performances(:alice_2023_w1)
    assert performance.lineup?
    assert_equal %w[qb wr wr rb rb te wr_rb_te k dst], performance.starters.map(&:slot)
    assert_in_delta 100.0, performance.starters.sum(&:points)

    # Bench best first, then injured reserve however well it scored.
    assert_equal [ 18.0, 4.0, 3.5, 2.0, 25.0 ], performance.reserves.map { |entry| entry.points.to_f }
    assert_equal %w[bench bench bench bench ir], performance.reserves.map(&:slot)
  end

  test "injured reserve is beyond the reach of hindsight" do
    performance = performances(:alice_2023_w1)
    injured = performance.reserves.last

    assert injured.ir?
    assert_not injured.startable?
    # Ibarra's 25.0 would have been her best receiver by seven points, but
    # a player on IR could not have been started.
    assert_in_delta 109.0, performance.optimal_points
    assert_in_delta 9.0, performance.points_left_on_bench

    injured.update!(slot: :bench)
    assert_in_delta 124.0, performance.reload.optimal_points
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
    Performance.includes(:lineup_slots).select(&:lineup?).each do |performance|
      assert_operator performance.optimal_points, :>=, performance.starters.sum(&:points),
        "#{performance.owner.name} could not have done worse than they did"
    end
  end

  test "a slot only opens to a player eligible for it" do
    performance = performances(:alice_2023_w1)
    flex = performance.starters.find(&:wr_rb_te?)

    assert flex.accepts?(lineup_slots(:alice_bench_rb)) # RB/WR
    assert flex.accepts?(lineup_slots(:alice_bench_te))
    assert_not flex.accepts?(lineup_slots(:alice_slot_k))
  end

  test "a lineup nothing on the bench could improve leaves nothing behind" do
    assert_in_delta 90.0, performances(:bob_2023_w1).optimal_points
    assert_in_delta 0.0, performances(:bob_2023_w1).points_left_on_bench
  end

  test "a recorded lineup may leave a spot the season had empty" do
    performance = performances(:alice_2023_w1)
    assert performance.valid?

    # 2023 was played with a kicker, but nobody had to field one.
    performance.lineup_slots.find(&:k?).mark_for_destruction
    assert performance.valid?
  end

  test "a starting spot left empty frees its player up for the bench" do
    performance = performances(:alice_2023_w1)
    performance.lineup_slots.find(&:k?).slot = :bench

    assert performance.valid?
  end

  test "an unused injured reserve spot is not a spare bench spot" do
    performance = performances(:alice_2023_w1)
    performance.lineup_slots.find(&:ir?).slot = :bench

    assert_not performance.valid?
    assert_includes performance.errors[:lineup_slots], "do not match the 2023 roster"
  end

  test "a recorded lineup cannot run deeper than the roster" do
    performance = performances(:alice_2023_w1)
    performance.lineup_slots.build(slot: :bench, sequence: 15, points: 3.0, player_name: "Extra Man",
                                   player_nfl_team: "SEA", player_positions: %w[wr])

    assert_not performance.valid?
    assert_includes performance.errors[:lineup_slots], "do not match the 2023 roster"
  end

  test "a recorded lineup cannot field more of a slot than the season had" do
    performance = performances(:alice_2023_w1)
    performance.lineup_slots.find(&:te?).slot = :k

    assert_not performance.valid?
    assert_includes performance.errors[:lineup_slots], "do not match the 2023 roster"
  end

  test "the order a lineup was written down in does not matter" do
    performance = performances(:alice_2023_w1)
    performance.lineup_slots.each { |entry| entry.sequence = 15 - entry.sequence }
    assert performance.valid?
  end

  test "seasons without a format on record accept any lineup" do
    roster_formats(:y2023).destroy!
    performance = performances(:alice_2023_w1).reload

    performance.lineup_slots.first.destroy!
    assert performance.reload.valid?
  end

  test "performances without a lineup on record leave nothing on the bench" do
    performance = performances(:carol_2023_w1)
    assert_not performance.lineup?
    assert_empty performance.starters
    assert_empty performance.reserves
    assert_equal 0, performance.points_left_on_bench
  end
end
