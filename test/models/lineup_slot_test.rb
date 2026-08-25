require "test_helper"

class LineupSlotTest < ActiveSupport::TestCase
  test "fixture lineup slots are valid" do
    assert lineup_slots(:alice_slot_flex).valid?
    assert_equal "Grant Feltz", lineup_slots(:alice_slot_qb).player_name
    assert_equal "BUF", lineup_slots(:alice_slot_qb).player_nfl_team
    assert_equal %w[qb], lineup_slots(:alice_slot_qb).player_positions
    assert_equal %w[dst], lineup_slots(:alice_slot_dst).player_positions
  end

  test "starters are everything off the bench and injured reserve" do
    assert lineup_slots(:alice_slot_qb).starter?
    assert_not lineup_slots(:alice_slot_qb).reserve?

    assert lineup_slots(:alice_bench_rb).reserve?
    assert_not lineup_slots(:alice_bench_rb).starter?

    assert lineup_slots(:alice_ir_wr).reserve?
    assert_not lineup_slots(:alice_ir_wr).starter?
  end

  test "only an injured reserve slot is unstartable" do
    assert lineup_slots(:alice_slot_qb).startable?
    assert lineup_slots(:alice_bench_rb).startable?
    assert_not lineup_slots(:alice_ir_wr).startable?
  end

  test "a player, their team and a position are required" do
    slot = LineupSlot.new
    assert_not slot.valid?
    assert_includes slot.errors[:player_name], "can't be blank"
    assert_includes slot.errors[:player_nfl_team], "can't be blank"
    assert_includes slot.errors[:player_positions], "can't be blank"
  end

  test "the player's team and positions are normalized and checked" do
    slot = lineup_slots(:alice_bench_rb)
    slot.player_nfl_team = " sea "
    slot.player_positions = [ " RB ", :wr, "rb" ]
    assert_equal "SEA", slot.player_nfl_team
    assert_equal %w[rb wr], slot.player_positions # cased down, trimmed, deduped
    assert slot.valid?

    slot.player_positions = %w[rb punter]
    assert_not slot.valid?
    assert_includes slot.errors[:player_positions], "punter is not a position"
  end

  test "injured reserve takes any position" do
    slot = lineup_slots(:alice_ir_wr)
    assert_equal LineupSlot::ANY_POSITION, slot.eligible_positions

    slot.player_positions = %w[dst]
    assert slot.valid?
  end

  test "flex takes a back, receiver or tight end but not a quarterback" do
    slot = lineup_slots(:alice_slot_flex)
    assert_equal %w[rb wr te], slot.eligible_positions

    slot.player_positions = %w[te]
    assert slot.valid?

    slot.player_positions = %w[qb]
    assert_not slot.valid?
    assert_includes slot.errors[:player_positions], "cannot fill a WR/RB/TE slot"
  end

  test "a dedicated slot only takes its own position" do
    slot = lineup_slots(:alice_slot_rb1)
    slot.player_positions = %w[wr]
    assert_not slot.valid?
    assert_includes slot.errors[:player_positions], "cannot fill a RB slot"
  end

  test "one matching position is enough for a dual-eligible player" do
    swing = lineup_slots(:alice_bench_rb) # Rex Calloway, RB/WR
    assert_equal %w[rb wr], swing.player_positions
    assert swing.eligible_for?(:rb)
    assert swing.eligible_for?("wr")
    assert_not swing.eligible_for?(:te)

    assert lineup_slots(:alice_slot_rb1).accepts?(swing)
    assert lineup_slots(:alice_slot_wr1).accepts?(swing)
    assert lineup_slots(:alice_slot_flex).accepts?(swing)
    assert_not lineup_slots(:alice_slot_te).accepts?(swing)
  end

  test "the bench takes anyone" do
    slot = lineup_slots(:alice_bench_rb)
    slot.player_positions = %w[qb]
    assert slot.valid?
  end

  # The whole point of recording the player on the slot: neither fact is
  # fixed for the length of a career, or even of a season.
  test "the same player can change team and eligibility from week to week" do
    september = lineup_slots(:alice_slot_wr1)
    october = LineupSlot.new(performance: performances(:bob_2023_w1),
                             player_name: september.player_name,
                             player_nfl_team: "SF", player_positions: %w[wr rb],
                             slot: :wr, sequence: 15, points: 11.0)

    assert october.valid?
    assert_equal september.player_name, october.player_name
    assert_not_equal september.player_nfl_team, october.player_nfl_team
  end

  test "positions cover every scoring slot" do
    assert_equal %w[qb rb wr te k dst], LineupSlot::ANY_POSITION
  end

  test "sequence is unique within a performance" do
    duplicate = LineupSlot.new(performance: performances(:alice_2023_w1),
                               player_name: "Judd Trask", player_nfl_team: "PHI",
                               player_positions: %w[qb], slot: :bench, sequence: 1, points: 5)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:sequence], "has already been taken"

    duplicate.performance = performances(:bob_2023_w1)
    duplicate.sequence = 15
    assert duplicate.valid?
  end

  test "points and a positive sequence are required" do
    slot = LineupSlot.new(performance: performances(:carol_2023_w1), player_name: "Judd Trask",
                          player_nfl_team: "PHI", player_positions: %w[qb])
    assert_not slot.valid?
    assert_includes slot.errors[:points], "can't be blank"
    assert_includes slot.errors[:sequence], "can't be blank"

    slot.sequence = 0
    slot.valid?
    assert_includes slot.errors[:sequence], "must be greater than 0"
  end

  test "a player reads with the team they played for" do
    assert_equal "Grant Feltz (BUF)", lineup_slots(:alice_slot_qb).player_display_name
    assert_equal "QB · Grant Feltz (BUF)", lineup_slots(:alice_slot_qb).display_name
  end

  test "ordered reads the lineup top to bottom" do
    assert_equal (1..14).to_a, performances(:alice_2023_w1).lineup_slots.map(&:sequence)
  end
end
