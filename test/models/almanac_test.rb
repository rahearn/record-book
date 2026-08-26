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
                 round_name: "Championship"),
      build_game(year: 2031, week: 2, scores: { owner_b => 85.0, owner_a => 70.0 },
                 round_name: "Championship")
    ]
    book = Almanac.new(games: [ regular ] + two_finals)
    assert book.all_time_standings.all? { |career| career.titles.zero? }
  end

  test "a third-place game in the final week does not affect the title" do
    owner_a, owner_b, owner_c, owner_d = %w[A B C D].map { |n| Owner.new(name: "Owner #{n}") }
    games = [
      build_game(year: 2030, week: 1, scores: { owner_a => 100.0, owner_b => 90.0 }),
      build_game(year: 2030, week: 1, scores: { owner_c => 80.0, owner_d => 70.0 }),
      build_game(year: 2030, week: 2, scores: { owner_b => 95.0, owner_a => 80.0 },
                 round_name: "Championship"),
      build_game(year: 2030, week: 2, scores: { owner_c => 70.0, owner_d => 60.0 },
                 round_name: "Third Place")
    ]

    book = Almanac.new(games: games)
    assert_equal 1, book.career_for(owner_b).titles
    assert_equal 0, book.career_for(owner_c).titles
  end

  test "promotion takes the points leader, championship participants, and third-place winner" do
    premier = %w[P1 P2].map { |n| Owner.new(name: n) }
    c1, c2, c3, c4, c5, c6 = challenger = %w[C1 C2 C3 C4 C5 C6].map { |n| Owner.new(name: n) }

    games = [
      build_game(year: 2030, week: 1, tier: :premier, scores: { premier[0] => 100.0, premier[1] => 90.0 }),
      # Challenger: C5 racks up the most points while losing every game.
      build_game(year: 2030, week: 1, tier: :challenger, scores: { c1 => 160.0, c5 => 150.0 }),
      build_game(year: 2030, week: 1, tier: :challenger, scores: { c2 => 95.0, c6 => 50.0 }),
      build_game(year: 2030, week: 1, tier: :challenger, scores: { c3 => 90.0, c4 => 80.0 }),
      build_game(year: 2030, week: 2, tier: :challenger, scores: { c2 => 158.0, c5 => 155.0 }),
      build_game(year: 2030, week: 2, tier: :challenger, scores: { c3 => 92.0, c6 => 55.0 }),
      build_game(year: 2030, week: 2, tier: :challenger, scores: { c4 => 92.0, c1 => 85.0 }),
      # Challenger playoffs: C2 beats C1 for the championship, C4 wins third place.
      build_game(year: 2030, week: 3, tier: :challenger, scores: { c2 => 100.0, c4 => 90.0 },
                 round_name: "Semifinal"),
      build_game(year: 2030, week: 3, tier: :challenger, scores: { c1 => 99.0, c3 => 95.0 },
                 round_name: "Semifinal"),
      build_game(year: 2030, week: 4, tier: :challenger, scores: { c2 => 105.0, c1 => 101.0 },
                 round_name: "Championship"),
      build_game(year: 2030, week: 4, tier: :challenger, scores: { c4 => 92.0, c3 => 88.0 },
                 round_name: "Third Place")
    ]

    book = Almanac.new(games: games, promotion_count: 4, relegation_count: 1)
    ladder = book.ladder
    promoted = ladder.premier.select { |entry| entry.movement == :promoted }.map(&:owner)
    assert_equal [ c5, c2, c1, c4 ], promoted
    assert_equal [ premier[1] ], ladder.challenger.select { |e| e.movement == :relegated }.map(&:owner)
    assert_equal [ c3, c6 ], ladder.challenger.select { |e| e.movement == :held }.map(&:owner)
  end

  test "promotion falls back to standings order without playoff results" do
    premier = %w[P1 P2].map { |n| Owner.new(name: n) }
    c1, c2, c3 = challenger = %w[C1 C2 C3].map { |n| Owner.new(name: n) }

    games = [
      build_game(year: 2030, week: 1, tier: :premier, scores: { premier[0] => 100.0, premier[1] => 90.0 }),
      build_game(year: 2030, week: 1, tier: :challenger, scores: { c1 => 100.0, c2 => 90.0 }),
      build_game(year: 2030, week: 2, tier: :challenger, scores: { c1 => 95.0, c3 => 85.0 }),
      build_game(year: 2030, week: 2, tier: :challenger, scores: { c2 => 88.0, c3 => 70.0 })
    ]

    book = Almanac.new(games: games, promotion_count: 2, relegation_count: 1)
    promoted = book.ladder.premier.select { |entry| entry.movement == :promoted }.map(&:owner)
    # C1 leads on points (195) and standings order fills the second spot.
    assert_equal [ c1, c2 ], promoted
  end

  test "playoff history from fixture data" do
    alice = @book.playoff_history_for(owners(:alice))
    assert_equal 1, alice.appearances
    assert_equal 1, alice.playoff_wins
    assert_equal 0, alice.runner_up_finishes
    assert_equal 2024, alice.last_playoff_win_year
    assert_equal 2024, alice.last_final_year
    assert_equal 2024, alice.last_appearance_year
    assert_nil alice.last_semifinal_year
    assert_equal 1, alice.longest_playoff_streak   # missed 2023, made 2024
    assert_equal 1, alice.active_playoff_streak
    assert_equal 1, alice.longest_playoff_drought
    assert_equal 0, alice.active_playoff_drought

    bob = @book.playoff_history_for(owners(:bob))
    assert_equal 1, bob.appearances
    assert_equal 0, bob.playoff_wins
    assert_equal 1, bob.runner_up_finishes
    assert_nil bob.last_playoff_win_year
    assert_equal 1, bob.active_playoff_streak
  end

  test "challenger playoff runs count for nothing in playoff history" do
    carol = @book.playoff_history_for(owners(:carol))
    assert_equal 0, carol.appearances
    assert_equal 0, carol.playoff_wins
    assert_nil carol.last_appearance_year
    # Both her seasons — 2023 unified without a berth, 2024 in Challenger —
    # count as missed playoffs.
    assert_equal 2, carol.longest_playoff_drought
    assert_equal 2, carol.active_playoff_drought
    assert_equal 0, carol.longest_playoff_streak
  end

  test "playoff history streaks and last-year stats across a career" do
    owner_a = Owner.new(name: "Streak A")
    owner_b = Owner.new(name: "Streak B")
    pair = ->(a, b) { { owner_a => a, owner_b => b } }
    games = [
      # 2030 unified: semifinal win, championship loss (runner-up).
      build_game(year: 2030, week: 1, scores: pair.(100.0, 90.0)),
      build_game(year: 2030, week: 2, scores: pair.(95.0, 90.0), round_name: "Semifinal"),
      build_game(year: 2030, week: 3, scores: pair.(80.0, 92.0), round_name: "Championship"),
      # 2031 unified: championship win.
      build_game(year: 2031, week: 1, scores: pair.(100.0, 90.0)),
      build_game(year: 2031, week: 2, scores: pair.(99.0, 90.0), round_name: "Championship"),
      # 2032 premier: third-place win.
      build_game(year: 2032, week: 1, tier: :premier, scores: pair.(100.0, 90.0)),
      build_game(year: 2032, week: 2, tier: :premier, scores: pair.(88.0, 70.0), round_name: "Third Place"),
      # 2033 challenger: even a championship win counts as missed playoffs.
      build_game(year: 2033, week: 1, tier: :challenger, scores: pair.(100.0, 90.0)),
      build_game(year: 2033, week: 2, tier: :challenger, scores: pair.(99.0, 90.0), round_name: "Championship"),
      # 2034 unified: no playoff berth.
      build_game(year: 2034, week: 1, scores: pair.(100.0, 90.0))
    ]

    history = Almanac.new(games: games).playoff_history_for(owner_a)
    assert_equal 3, history.appearances
    assert_equal 3, history.playoff_wins          # 2030 SF, 2031 final, 2032 third place
    assert_equal 1, history.runner_up_finishes    # 2030
    assert_equal 2032, history.last_playoff_win_year
    assert_equal 2030, history.last_semifinal_year
    assert_equal 2031, history.last_final_year
    assert_equal 2032, history.last_appearance_year
    assert_equal 3, history.longest_playoff_streak
    assert_equal 0, history.active_playoff_streak
    assert_equal 2, history.longest_playoff_drought
    assert_equal 2, history.active_playoff_drought
  end

  test "final rank places playoff finishers first, then regular-season order" do
    a, b, c, d, e, f = %w[A B C D E F].map { |n| Owner.new(name: "Final #{n}") }
    games = [
      # Regular season standings: A(1st, 100), C(2nd, 95), E(3rd, 85),
      # then the losers by points: B(4th, 90), D(5th, 80), F(6th, 70).
      build_game(year: 2030, week: 1, scores: { a => 100.0, b => 90.0 }),
      build_game(year: 2030, week: 1, scores: { c => 95.0, d => 80.0 }),
      build_game(year: 2030, week: 1, scores: { e => 85.0, f => 70.0 }),
      # Playoffs: E upsets its way to the title; C takes third.
      build_game(year: 2030, week: 2, scores: { a => 100.0, b => 90.0 }, round_name: "Semifinal"),
      build_game(year: 2030, week: 2, scores: { e => 99.0, c => 80.0 }, round_name: "Semifinal"),
      build_game(year: 2030, week: 3, scores: { e => 105.0, a => 100.0 }, round_name: "Championship"),
      build_game(year: 2030, week: 3, scores: { c => 88.0, b => 77.0 }, round_name: "Third Place")
    ]

    book = Almanac.new(games: games)
    rows = book.standings_for(2030, :unified)
    assert_equal [ a, c, e, b, d, f ], rows.map(&:owner) # regular-season order intact
    final = rows.index_by(&:owner)
    assert_equal [ 1, 2, 3, 4, 5, 6 ],
      [ e, a, c, b, d, f ].map { |owner| final[owner].final_rank }
    assert_equal 1, book.career_for(e).best_finish
  end

  test "final standings order the season by finish, playoff finishers first" do
    a, b, c, d, e, f = %w[A B C D E F].map { |n| Owner.new(name: "Order #{n}") }
    games = [
      build_game(year: 2031, week: 1, scores: { a => 100.0, b => 90.0 }),
      build_game(year: 2031, week: 1, scores: { c => 95.0, d => 80.0 }),
      build_game(year: 2031, week: 1, scores: { e => 85.0, f => 70.0 }),
      build_game(year: 2031, week: 2, scores: { e => 105.0, a => 100.0 }, round_name: "Championship"),
      build_game(year: 2031, week: 2, scores: { c => 88.0, b => 77.0 }, round_name: "Third Place")
    ]

    book = Almanac.new(games: games)
    rows = book.final_standings_for(2031, :unified)
    assert_equal [ e, a, c, b, d, f ], rows.map(&:owner)
    assert_equal [ 1, 2, 3, 4, 5, 6 ], rows.map(&:final_rank)
    # The regular-season view is untouched.
    assert_equal [ a, c, e, b, d, f ], book.standings_for(2031, :unified).map(&:owner)
  end

  test "final rank matches regular-season rank when playoff data is absent" do
    rows = @book.standings_for(2023, :unified)
    assert_equal rows.map(&:rank), rows.map(&:final_rank)
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

  test "matchup_for pairs both sides with the season each owner was having" do
    matchup = @book.matchup_for(games(:g2023_w1_ab), first_owner: owners(:alice))

    assert_equal 2023, matchup.year
    assert_equal 1, matchup.week
    assert_equal "unified", matchup.tier
    assert_not matchup.playoff?
    assert_equal [ owners(:alice), owners(:bob) ], matchup.sides.map(&:owner)
    assert_equal owners(:alice), matchup.winner
    assert_in_delta 10.0, matchup.margin
    assert_not matchup.tied?

    alice = matchup.side_a
    assert_in_delta 105.0, alice.average_points # 100.0 and 110.0 that season
    assert_in_delta(-5.0, alice.points_vs_average)
    assert_in_delta 9.0, alice.points_left_on_bench
  end

  test "matchup_for puts the owner arrived from on the left" do
    game = games(:g2023_w1_ab)
    assert_equal [ owners(:bob), owners(:alice) ],
      @book.matchup_for(game, first_owner: owners(:bob)).sides.map(&:owner)
    assert_equal [ owners(:alice), owners(:bob) ],
      @book.matchup_for(game, first_owner: owners(:alice)).sides.map(&:owner)

    # An owner who did not play leaves the recorded order alone.
    recorded = @book.matchup_for(game).sides.map(&:owner)
    assert_equal recorded, @book.matchup_for(game, first_owner: owners(:carol)).sides.map(&:owner)
  end

  test "matchup_for reads playoff games too" do
    matchup = @book.matchup_for(games(:g2024_final_premier))

    assert matchup.playoff?
    assert_equal "Championship", matchup.round_name
    assert_equal owners(:alice), matchup.winner
  end

  test "matchup slot rows pair the two lineups and mark the leader" do
    matchup = @book.matchup_for(games(:g2023_w1_ab), first_owner: owners(:alice))

    assert matchup.lineups?
    assert_in_delta 22.5, matchup.best_starter_points
    rows = matchup.slot_rows
    assert_equal 9, rows.size
    assert_equal %w[qb wr wr rb rb te wr_rb_te k dst], rows.map(&:slot)

    quarterbacks = rows.first
    assert quarterbacks.a_leads? # 22.5 to 20.0
    assert_not quarterbacks.b_leads?
    assert_equal lineup_slots(:alice_slot_qb), quarterbacks.entry_a
    assert_equal lineup_slots(:bob_slot_qb), quarterbacks.entry_b

    second_receiver = rows[2] # 9.0 to 11.0
    assert_not second_receiver.a_leads?
    assert second_receiver.b_leads?
  end

  test "matchups without lineups on record still report the score" do
    matchup = @book.matchup_for(games(:g2023_w1_cd))

    assert_not matchup.lineups?
    assert_empty matchup.slot_rows
    assert_equal 0, matchup.best_starter_points
    assert_equal owners(:carol), matchup.winner
  end

  test "scoreboard_for collects one week of a season and tier" do
    board = @book.scoreboard_for(2023, 1, :unified)

    assert_not board.empty?
    assert_equal 2023, board.year
    assert_equal 1, board.week
    assert_equal "unified", board.tier
    assert_equal 2, board.matchups.size
    assert_equal [ owners(:alice), owners(:bob), owners(:carol), owners(:dan) ].to_set,
      board.sides.map(&:owner).to_set
  end

  test "scoreboard marks the week's high and low scores" do
    board = @book.scoreboard_for(2023, 1, :unified)
    by_owner = board.sides.index_by(&:owner)

    assert_in_delta 100.0, board.highest_score
    assert_in_delta 70.5, board.lowest_score
    assert_in_delta 85.125, board.average_score

    assert board.highest?(by_owner[owners(:alice)])
    assert board.lowest?(by_owner[owners(:dan)])
    assert_not board.highest?(by_owner[owners(:bob)])
    assert_not board.lowest?(by_owner[owners(:bob)])
  end

  test "scoreboards keep the tiers of a split season apart" do
    premier = @book.scoreboard_for(2024, 1, :premier)
    challenger = @book.scoreboard_for(2024, 1, :challenger)

    assert_equal [ owners(:alice), owners(:bob) ].to_set, premier.sides.map(&:owner).to_set
    assert_equal [ owners(:carol), owners(:dan) ].to_set, challenger.sides.map(&:owner).to_set
    assert_in_delta 120.0, premier.highest_score
    assert_in_delta 90.0, challenger.highest_score
  end

  test "scoreboards cover playoff weeks too" do
    board = @book.scoreboard_for(2024, 2, :premier)

    assert_equal 1, board.matchups.size
    assert board.matchups.first.playoff?
    assert_equal "Championship", board.matchups.first.round_name
  end

  test "scoreboard_for is empty for a week nobody played" do
    assert @book.scoreboard_for(2023, 9, :unified).empty?
    assert @book.scoreboard_for(2023, 1, :premier).empty?
  end

  test "weeks_in lists the weeks on record, playoffs included" do
    assert_equal [ 1, 2 ], @book.weeks_in(2023, :unified)
    assert_equal [ 1, 2 ], @book.weeks_in(2024, :premier)
    assert_equal [ 1, 3 ], @book.weeks_in(2024, :challenger)
    assert_empty @book.weeks_in(2023, :premier)
  end

  test "matchup sides fall back gracefully without a season on record" do
    owner_a = Owner.new(name: "Solo A")
    owner_b = Owner.new(name: "Solo B")
    final = build_game(year: 2030, week: 2, scores: { owner_a => 100.0, owner_b => 100.0 },
                       round_name: Game::CHAMPIONSHIP)

    matchup = Almanac.new(games: [ final ]).matchup_for(final)
    assert matchup.tied?
    assert_nil matchup.winner
    assert_nil matchup.side_a.season_record
    assert_nil matchup.side_a.average_points
    assert_nil matchup.side_a.points_vs_average
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
