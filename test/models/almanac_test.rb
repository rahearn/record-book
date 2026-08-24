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
    assert_equal 1, alice.titles
  end

  test "titles count playoff championships, not standings finishes" do
    # Alice topped the 2023 standings, but 2023 has no playoff games on
    # record — her one title is the 2024 Premier championship win.
    assert_equal 1, career_for(:alice).titles
    assert_equal 0, career_for(:bob).titles
    assert_equal 0, career_for(:dan).titles
  end

  test "challenger championships do not count as titles" do
    carol = career_for(:carol)
    assert_equal 2, carol.wins
    assert_equal 1, carol.losses
    assert_equal 0, carol.titles # won the 2024 Challenger final
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

  test "season records track weekly scores and extremes" do
    alice = @book.standings_for(2023, :unified).first
    assert_equal [ [ 1, 100.0 ], [ 2, 110.0 ] ],
      alice.weekly_scores.map { |score| [ score.week, score.points.to_f ] }
    assert_in_delta 110.0, alice.highest_score
    assert_in_delta 100.0, alice.lowest_score
    assert_in_delta 100.0, alice.score_in(1)
    assert_nil alice.score_in(3)

    dan = @book.standings_for(2023, :unified).second
    assert_in_delta 70.5, dan.lowest_score
  end

  test "split_season? detects tiered years" do
    assert_not @book.split_season?(2023)
    assert @book.split_season?(2024)
  end

  test "promotion and relegation zones follow rank within split seasons" do
    premier = @book.standings_for(2024, :premier)
    assert_not @book.relegation_zone?(premier.first)
    assert @book.relegation_zone?(premier.second)

    challenger = @book.standings_for(2024, :challenger)
    assert @book.promotion_zone?(challenger.first)
    assert_not @book.promotion_zone?(challenger.second)

    unified = @book.standings_for(2023, :unified)
    assert unified.none? { |record| @book.relegation_zone?(record) }
    assert unified.none? { |record| @book.promotion_zone?(record) }
  end

  test "week matrix flags each week's high and low" do
    matrix = @book.week_matrix(2023, :unified)
    assert_equal [ 1, 2 ], matrix.weeks
    assert_equal [ owners(:alice), owners(:dan), owners(:carol), owners(:bob) ],
      matrix.rows.map { |row| row.record.owner }

    alice_row = matrix.rows.first
    assert alice_row.cells.all?(&:highest)
    assert alice_row.cells.none?(&:lowest)

    dan_cells = matrix.rows.second.cells
    assert dan_cells.first.lowest   # 70.5, week 1's low
    assert_not dan_cells.second.lowest

    bob_cells = matrix.rows.fourth.cells
    assert bob_cells.second.lowest  # 85.0, week 2's low
  end

  test "career_for finds an owner's career" do
    assert_equal owners(:alice), @book.career_for(owners(:alice)).owner
    assert_nil @book.career_for(Owner.new(name: "Outsider"))
  end

  test "best_finish is the owner's highest placement" do
    assert_equal 1, career_for(:alice).best_finish
    assert_equal 2, career_for(:bob).best_finish   # 4th in 2023, 2nd in 2024 premier
    assert_equal 2, career_for(:dan).best_finish
  end

  test "league ranks by points per game" do
    # PF/g: Alice 110.0, Bob 90.0, Carol 88.3, Dan 85.2
    assert_equal 1, @book.points_for_rank(career_for(:alice))
    assert_equal 2, @book.points_for_rank(career_for(:bob))
    assert_equal 4, @book.points_for_rank(career_for(:dan))

    # PA/g ascending: Dan 85.0, Carol 86.8, Alice 93.3, Bob 108.3
    assert_equal 1, @book.points_against_rank(career_for(:dan))
    assert_equal 3, @book.points_against_rank(career_for(:alice))
    assert_equal 4, @book.points_against_rank(career_for(:bob))
  end

  test "weekly scores carry the opponent and result" do
    alice = @book.standings_for(2023, :unified).first
    week_one = alice.weekly_scores.first
    assert_equal owners(:bob), week_one.opponent
    assert_in_delta 90.0, week_one.opponent_points
    assert_equal :win, week_one.result

    bob = @book.standings_for(2023, :unified).fourth
    assert_equal %i[loss loss], bob.weekly_scores.map(&:result)
  end

  test "head_to_head_for aggregates series records, best first" do
    alice = @book.head_to_head_for(owners(:alice))
    assert_equal [ [ owners(:bob), 2, 0 ], [ owners(:carol), 1, 0 ] ],
      alice.map { |series| [ series.opponent, series.wins, series.losses ] }

    dan = @book.head_to_head_for(owners(:dan))
    assert_equal [ [ owners(:bob), 1, 0 ], [ owners(:carol), 0, 2 ] ],
      dan.map { |series| [ series.opponent, series.wins, series.losses ] }

    assert_empty @book.head_to_head_for(Owner.new(name: "Outsider"))
  end

  test "series_between logs every meeting, newest first" do
    series = @book.series_between(owners(:alice), owners(:bob))
    assert_equal 2, series.games_played
    assert_equal 2, series.wins_a
    assert_equal 0, series.wins_b
    assert_equal 2023, series.first_year
    assert_in_delta 110.0, series.average_points_a
    assert_in_delta 92.5, series.average_points_b

    newest = series.meetings.first
    assert_equal [ 2024, 1, "premier" ], [ newest.year, newest.week, newest.tier ]
    assert_in_delta 25.0, newest.margin
    assert_equal owners(:alice), series.winner_of(newest)
  end

  test "series_between is directional" do
    series = @book.series_between(owners(:dan), owners(:carol))
    assert_equal 0, series.wins_a
    assert_equal 2, series.wins_b
    assert_equal owners(:carol), series.winner_of(series.meetings.first)
  end

  test "series_between owners who never met is empty" do
    series = @book.series_between(owners(:alice), owners(:dan))
    assert_equal 0, series.games_played
    assert_nil series.first_year
    assert_equal 0, series.average_points_a
  end

  test "series_between the same owner is empty" do
    assert_equal 0, @book.series_between(owners(:alice), owners(:alice)).games_played
  end

  test "playoff games are excluded from every statistic" do
    # The fixtures include 2024 Championship games — Alice 130.0 over Bob,
    # Carol 99.0 over Dan — none of which may leak into regular-season stats.
    assert_equal 6, @book.game_count
    assert_equal 3, career_for(:alice).games_played
    assert_equal 2, @book.weeks_per_season
    assert_in_delta 120.0, @book.game_records.highest_score.points
    assert_equal 2, @book.series_between(owners(:alice), owners(:bob)).games_played
    assert_equal [ 1 ], @book.week_matrix(2024, :premier).weeks
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
    assert_nil @book.ladder.tier_for(Owner.new(name: "Outsider"))

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
    owner_a = Owner.new(name: "Tie A")
    owner_b = Owner.new(name: "Tie B")
    game = build_game(year: 2030, week: 1, scores: { owner_a => 100.0, owner_b => 100.0 })

    book = Almanac.new(games: [ game ])
    career = book.all_time_standings.first
    assert_equal 0, career.wins
    assert_equal 0, career.losses
    assert_equal 1, career.ties
    assert_in_delta 0.5, career.win_percentage
    assert_equal 1, book.head_to_head_for(owner_a).first.ties

    series = book.series_between(owner_a, owner_b)
    assert_equal 1, series.ties
    assert_nil series.winner_of(series.meetings.first)
  end

  test "a unified season's championship winner earns a title" do
    owner_a = Owner.new(name: "Solo A")
    owner_b = Owner.new(name: "Solo B")
    games = [
      build_game(year: 2030, week: 1, scores: { owner_a => 100.0, owner_b => 90.0 }),
      build_game(year: 2030, week: 2, scores: { owner_a => 80.0, owner_b => 95.0 },
                 round_name: "Championship")
    ]

    book = Almanac.new(games: games)
    assert_equal 1, book.career_for(owner_b).titles
    assert_equal 0, book.career_for(owner_a).titles
  end

  test "tied or ambiguous finals crown no champion" do
    owner_a = Owner.new(name: "Solo A")
    owner_b = Owner.new(name: "Solo B")
    regular = build_game(year: 2030, week: 1, scores: { owner_a => 100.0, owner_b => 90.0 })

    tied_final = build_game(year: 2030, week: 2, scores: { owner_a => 95.0, owner_b => 95.0 },
                            round_name: "Championship")
    book = Almanac.new(games: [ regular, tied_final ])
    assert book.all_time_standings.all? { |career| career.titles.zero? }

    two_finals = [
      build_game(year: 2031, week: 2, scores: { owner_a => 90.0, owner_b => 80.0 },
                 round_name: "Semifinal"),
      build_game(year: 2031, week: 2, scores: { owner_b => 85.0, owner_a => 70.0 },
                 round_name: "Semifinal")
    ]
    book = Almanac.new(games: [ regular ] + two_finals)
    assert book.all_time_standings.all? { |career| career.titles.zero? }
  end

  test "ladder is absent when the latest season lacks two tiers" do
    owner_a = Owner.new(name: "Solo A")
    owner_b = Owner.new(name: "Solo B")

    unified = build_game(year: 2030, week: 1, scores: { owner_a => 100.0, owner_b => 90.0 })
    assert_nil Almanac.new(games: [ unified ]).ladder

    premier_only = build_game(year: 2030, week: 1, tier: :premier,
                              scores: { owner_a => 100.0, owner_b => 90.0 })
    assert_nil Almanac.new(games: [ premier_only ]).ladder
  end

  test "games without exactly two performances are ignored" do
    game = Game.new(season: Season.new(year: 2030), week: 1)
    game.performances.build(owner: Owner.new(name: "Solo"), points: 100)

    book = Almanac.new(games: [ game ])
    assert book.empty?
    assert_equal 0, book.game_count
  end

  private

  def career_for(fixture_name)
    @book.all_time_standings.find { |career| career.owner == owners(fixture_name) }
  end

  def build_game(year:, week:, scores:, tier: :unified, round_name: nil)
    game = Game.new(season: Season.new(year: year), week: week, tier: tier, round_name: round_name)
    scores.each { |owner, points| game.performances.build(owner: owner, points: points) }
    game
  end
end
