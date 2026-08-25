require "test_helper"

class RosterFormatTest < ActiveSupport::TestCase
  test "fixture formats are valid" do
    assert roster_formats(:y2023).valid?
    assert_equal 14, roster_formats(:y2023).size
  end

  test "splits its slots into starters and reserves" do
    format = roster_formats(:y2023)

    assert_equal %w[qb wr wr rb rb te wr_rb_te k dst], format.starting_slots
    assert_equal %w[bench bench bench bench ir], format.reserve_slots
    assert_equal 4, format.bench_count
    assert format.injured_reserve?

    assert_not roster_formats(:y2024).injured_reserve?
    assert_equal 3, roster_formats(:y2024).bench_count
    assert_empty roster_formats(:y2024).starting_slots.grep("k")
  end

  test "slot_counts is the shape a lineup is held to" do
    assert_equal({ "qb" => 1, "wr" => 2, "rb" => 2, "te" => 1, "wr_rb_te" => 1,
                   "k" => 1, "dst" => 1, "bench" => 4, "ir" => 1 },
                 roster_formats(:y2023).slot_counts)
  end

  test "a season carries at most one format" do
    duplicate = RosterFormat.new(season: seasons(:y2023), slots: %w[qb bench])
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:season_id], "has already been taken"
  end

  test "slots must be present and known" do
    format = RosterFormat.new(season: Season.new(year: 2030))
    assert_not format.valid?
    assert_includes format.errors[:slots], "can't be blank"

    format.slots = %w[qb punter bench]
    assert_not format.valid?
    assert_includes format.errors[:slots], "punter is not a slot"
  end

  test "both flex spots the league has run are valid slots" do
    format = RosterFormat.new(season: Season.new(year: 2030),
                              slots: %w[qb wr wr rb rb te wr_rb k dst bench])
    assert format.valid?
    assert_equal %w[wr_rb], format.starting_slots.grep("wr_rb")
  end
end
