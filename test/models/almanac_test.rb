require "test_helper"

# Fixture data, hand-computed:
#
# 2023 (unified): W1 Alice 100.0 def. Bob 90.0, Carol 80.0 def. Dan 70.5
#                 W2 Alice 110.0 def. Carol 95.0, Dan 105.0 def. Bob 85.0
#   Standings: Alice 2-0 (pf 210), Dan 1-1 (pf 175.5), Carol 1-1 (pf 175), Bob 0-2 (pf 175)
#   Luck totals: Alice -10, Bob -12.25, Carol +12.25, Dan +10
#
# 2024: Premier W1 Alice 120.0 def. Bob 95.0; Challenger W1 Carol 90.0 def. Dan 80.0
class AlmanacTest < ActiveSupport::TestCase
  setup do
    @book = Almanac.new(promotion_count: 1, relegation_count: 1)
  end

  test "league facts" do
    assert_not @book.empty?
    assert_equal 2, @book.season_count
    assert_equal 2023, @book.first_year
    assert_equal 2024, @book.latest_year
    assert_equal 6, @book.game_count
    assert_equal 2, @book.weeks_per_season
    assert_equal 4, @book.owner_count
    assert_equal 4, @book.founders_remaining
    assert_equal 2024, @book.tiered_since
  end

  test "all-time standings rank owners by winning percentage" do
    standings = @book.all_time_standings
    assert_equal [ owners(:alice), owners(:carol), owners(:dan), owners(:bob) ],
      standings.map(&:owner)
    assert_equal [ 1, 2, 3, 4 ], standings.map(&:rank)
  end

  test "career aggregates for an unbeaten owner" do
    alice = career_for(:alice)
    assert_equal 2, alice.seasons_played
    assert_equal 2023, alice.joined_year
    assert_equal 3, alice.games_played
    assert_equal 3, alice.wins
    assert_equal 0, alice.losses
    assert_in_delta 1.0, alice.win_percentage
    assert_in_delta 110.0, alice.points_for_per_game
    assert_in_delta 93.33, alice.points_against_per_game, 0.01
    assert_in_delta(-3.33, alice.luck_per_game, 0.01)
    assert_equal 2, alice.titles
  end

  test "challenger first place does not count as a title" do
    carol = career_for(:carol)
    assert_equal 2, carol.wins
    assert_equal 1, carol.losses
    assert_equal 0, carol.titles
    assert_in_delta 4.08, carol.luck_per_game, 0.01
  end

  test "luck measures opponent under- and over-performance" do
    assert_in_delta(-4.08, career_for(:bob).luck_per_game, 0.01)
    assert_in_delta 3.33, career_for(:dan).luck_per_game, 0.01
  end

  test "season standings break win ties on points for" do
    rows = @book.standings_for(2023, :unified)
    assert_equal [ owners(:alice), owners(:dan), owners(:carol), owners(:bob) ],
      rows.map(&:owner)
    assert_equal [ 1, 2, 3, 4 ], rows.map(&:rank)
    assert_equal [ 2, 1, 1, 0 ], rows.map(&:wins)
  end

  test "game records capture single-game extremes" do
    records = @book.game_records

    assert_in_delta 120.0, records.highest_score.points
    assert_equal owners(:alice), records.highest_score.owner
    assert_equal 2024, records.highest_score.year
    assert_equal 1, records.highest_score.week

    assert_in_delta 70.5, records.lowest_score.points
    assert_equal owners(:dan), records.lowest_score.owner
    assert_equal 2023, records.lowest_score.year

    assert_in_delta 25.0, records.biggest_blowout.margin
    assert_equal owners(:alice), records.biggest_blowout.winner
    assert_equal owners(:bob), records.biggest_blowout.loser

    assert_in_delta 215.0, records.highest_combined.total
    assert_equal [ owners(:alice), owners(:bob) ], records.highest_combined.owners
  end

  test "ladder swaps the bottom of premier with the top of challenger" do
    ladder = @book.ladder
    assert_equal 2025, ladder.year
    assert_equal [ [ owners(:alice), :held ], [ owners(:carol), :promoted ] ],
      ladder.premier.map { |entry| [ entry.owner, entry.movement ] }
    assert_equal [ [ owners(:bob), :relegated ], [ owners(:dan), :held ] ],
      ladder.challenger.map { |entry| [ entry.owner, entry.movement ] }
  end

  test "ladder assigns each owner's next tier" do
    assert_equal :premier, @book.ladder.tier_for(owners(:alice))
    assert_equal :premier, @book.ladder.tier_for(owners(:carol))
    assert_equal :challenger, @book.ladder.tier_for(owners(:bob))
    assert_equal :challenger, @book.ladder.tier_for(owners(:dan))
    assert_nil @book.ladder.tier_for(Owner.new(name: "Outsider", team_name: "Out"))

    assert_equal %i[premier premier challenger challenger],
      %i[alice carol bob dan].map { |name| career_for(name).next_tier }
  end

  test "an empty record book" do
    book = Almanac.new(games: [])
    assert book.empty?
    assert_equal 0, book.season_count
    assert_equal 0, book.game_count
    assert_equal 0, book.owner_count
    assert_equal 0, book.founders_remaining
    assert_nil book.first_year
    assert_nil book.weeks_per_season
    assert_nil book.tiered_since
    assert_nil book.game_records
    assert_nil book.ladder
    assert_empty book.all_time_standings
  end

  test "tied games count as half a win" do
    owner_a = Owner.new(name: "Tie A", team_name: "Team A")
    owner_b = Owner.new(name: "Tie B", team_name: "Team B")
    game = build_game(year: 2030, week: 1, scores: { owner_a => 100.0, owner_b => 100.0 })

    book = Almanac.new(games: [ game ])
    career = book.all_time_standings.first
    assert_equal 0, career.wins
    assert_equal 0, career.losses
    assert_equal 1, career.ties
    assert_in_delta 0.5, career.win_percentage
  end

  test "ladder is absent when the latest season lacks two tiers" do
    owner_a = Owner.new(name: "Solo A", team_name: "Team A")
    owner_b = Owner.new(name: "Solo B", team_name: "Team B")

    unified = build_game(year: 2030, week: 1, scores: { owner_a => 100.0, owner_b => 90.0 })
    assert_nil Almanac.new(games: [ unified ]).ladder

    premier_only = build_game(year: 2030, week: 1, tier: :premier,
                              scores: { owner_a => 100.0, owner_b => 90.0 })
    assert_nil Almanac.new(games: [ premier_only ]).ladder
  end

  test "games without exactly two performances are ignored" do
    game = Game.new(season: Season.new(year: 2030), week: 1)
    game.performances.build(owner: Owner.new(name: "Solo", team_name: "Solo FC"), points: 100)

    book = Almanac.new(games: [ game ])
    assert book.empty?
    assert_equal 0, book.game_count
  end

  private

  def career_for(fixture_name)
    @book.all_time_standings.find { |career| career.owner == owners(fixture_name) }
  end

  def build_game(year:, week:, scores:, tier: :unified)
    game = Game.new(season: Season.new(year: year), week: week, tier: tier)
    scores.each { |owner, points| game.performances.build(owner: owner, points: points) }
    game
  end
end
