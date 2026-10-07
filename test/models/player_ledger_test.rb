require "test_helper"

class PlayerLedgerTest < ActiveSupport::TestCase
  test "totals each player's starts, bench points apart" do
    feltz = PlayerLedger.new.lines(:career).find { |line| line.name == "Grant Feltz" }

    assert_equal "qb", feltz.position
    assert_equal "BUF", feltz.nfl_team
    assert_equal 1, feltz.starts
    assert_equal 22.5, feltz.points
    assert_equal 22.5, feltz.best
    assert_equal 22.5, feltz.points_per_start
    assert_equal 0, feltz.bench_points
    assert_equal 1, feltz.owner_count
    assert_equal [ 2023, 2023 ], [ feltz.first_year, feltz.last_year ]
  end

  test "a player who only sat counts toward the bench table alone" do
    ledger = PlayerLedger.new

    assert_not_includes ledger.lines(:career).map(&:name), "Rex Calloway"
    calloway = ledger.lines(:career, sort: "bench").first
    assert_equal "Rex Calloway", calloway.name
    assert_equal 0, calloway.starts
    assert_nil calloway.points_per_start
    assert_equal 18, calloway.bench_points
  end

  test "groups by season when asked" do
    lines = PlayerLedger.new(position: "qb").lines(:season)

    assert_equal [ "Grant Feltz", "Judd Trask" ], lines.map(&:name)
    assert_equal [ 2023, 2023 ], lines.map(&:year)
  end

  test "counts the lines a sort qualifies" do
    ledger = PlayerLedger.new

    # Eighteen starters across Alice's and Bob's 2023 week-one lineups.
    assert_equal 18, ledger.count(:career)
    assert_equal 0, ledger.count(:career, sort: "ppg")
  end

  test "narrows to one owner's lineups" do
    ledger = PlayerLedger.new(owner: owners(:bob))

    assert_equal "Judd Trask", ledger.lines(:career).first.name
    assert_equal 9, ledger.game_count
  end

  test "single starts leave the reserves out" do
    starts = PlayerLedger.new.games

    assert_equal "Grant Feltz", starts.first.player_name
    assert starts.all?(&:starter?)
  end

  test "playoff lineups do not count" do
    final = performances(:alice_2024_final)
    final.lineup_slots.create!(slot: :qb, sequence: 1, points: 50, player_name: "Grant Feltz",
                               player_nfl_team: "BUF", player_positions: [ "qb" ])

    assert_equal 22.5, PlayerLedger.new.lines(:career).first.points
  end
end
