require "test_helper"

class LineupSlotTest < ActiveSupport::TestCase
  test "fixture lineup slots are valid" do
    assert lineup_slots(:alice_slot_flex).valid?
  end

  test "starters are everything off the bench" do
    assert lineup_slots(:alice_slot_qb).starter?
    assert_not lineup_slots(:alice_slot_qb).bench?
    assert_not lineup_slots(:alice_bench_rb).starter?
    assert lineup_slots(:alice_bench_rb).bench?
  end

  test "flex takes a back, receiver or tight end but not a quarterback" do
    slot = lineup_slots(:alice_slot_flex)
    assert_equal %w[rb wr te], slot.eligible_positions

    slot.player = players(:alice_te2)
    assert slot.valid?

    slot.player = players(:alice_qb)
    assert_not slot.valid?
    assert_includes slot.errors[:player], "cannot fill the flex slot"
  end

  test "a dedicated slot only takes its own position" do
    slot = lineup_slots(:alice_slot_rb1)
    slot.player = players(:alice_wr1)
    assert_not slot.valid?
    assert_includes slot.errors[:player], "cannot fill the rb slot"
  end

  test "the bench takes anyone" do
    slot = lineup_slots(:alice_bench_rb)
    slot.player = players(:alice_qb)
    assert slot.valid?
  end

  test "sequence is unique within a performance" do
    duplicate = LineupSlot.new(performance: performances(:alice_2023_w1),
                               player: players(:bob_qb), slot: :bench, sequence: 1, points: 5)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:sequence], "has already been taken"

    duplicate.performance = performances(:bob_2023_w1)
    duplicate.sequence = 14
    assert duplicate.valid?
  end

  test "points and a positive sequence are required" do
    slot = LineupSlot.new(performance: performances(:carol_2023_w1), player: players(:bob_qb))
    assert_not slot.valid?
    assert_includes slot.errors[:points], "can't be blank"
    assert_includes slot.errors[:sequence], "can't be blank"

    slot.sequence = 0
    slot.valid?
    assert_includes slot.errors[:sequence], "must be greater than 0"
  end

  test "ordered reads the lineup top to bottom" do
    assert_equal (1..13).to_a, performances(:alice_2023_w1).lineup_slots.map(&:sequence)
  end
end
