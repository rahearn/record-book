require "test_helper"

class MatchupsHelperTest < ActionView::TestCase
  include LeagueHelper
  include OwnersHelper

  setup { @book = Almanac.new }

  test "position and slot labels" do
    assert_equal "QB", position_label("qb")
    assert_equal "D/ST", position_label(:dst)
    assert_equal "W/R/T", slot_label("wr_rb_te")
    assert_equal "W/R", slot_label("wr_rb")
    assert_equal "IR", slot_label(:ir)
    assert_equal "BN", slot_label("bench")
    assert_equal "RB", slot_label(:rb)
  end

  test "player_positions_label lists every position, primary first" do
    assert_equal "QB", player_positions_label(players(:alice_qb))
    assert_equal "RB/WR", player_positions_label(players(:alice_rb4))
    assert_equal "D/ST", player_positions_label(players(:alice_dst))
  end

  test "player_with_team mutes the NFL team after the name" do
    assert_equal %(Grant Feltz <span class="text-ink/55">BUF</span>),
      player_with_team(players(:alice_qb))
    assert_equal %(Ravens D/ST <span class="text-ink/55">BAL</span>),
      player_with_team(players(:alice_dst))
  end

  test "matchup_title names the week and adds the playoff round" do
    assert_equal "Week 1 · 2023", matchup_title(@book.matchup_for(games(:g2023_w1_ab)))
    assert_equal "Week 2 · 2024 · Championship",
      matchup_title(@book.matchup_for(games(:g2024_final_premier)))
  end

  test "matchup_result_note names the winner or the tie" do
    assert_equal "Alice Anders wins by 10.0.",
      matchup_result_note(@book.matchup_for(games(:g2023_w1_ab)))
    assert_equal "Tied at 100.0.", matchup_result_note(tied_matchup)
  end

  test "season context reads the owner's year, or says there is none" do
    matchup = @book.matchup_for(games(:g2023_w1_ab), first_owner: owners(:alice))
    assert_equal "2–0 that year · season avg 105.0 (-5.0 this week)",
      season_context_note(matchup.side_a)
    assert_equal "-5.0", vs_season_average_display(matchup.side_a)

    assert_equal "No season on record", season_context_note(tied_matchup.side_a)
    assert_equal "—", vs_season_average_display(tied_matchup.side_a)
  end

  test "bench_note reports what a better lineup was worth" do
    matchup = @book.matchup_for(games(:g2023_w1_ab), first_owner: owners(:alice))
    assert_equal "9.0 left on the bench", bench_note(matchup.side_a)
    assert_equal "0.0 left on the bench", bench_note(matchup.side_b)
  end

  test "bars fill toward the leader and survive a scoreless game" do
    assert_equal "bg-accent", lineup_bar_class(true)
    assert_equal "bg-neutral-400", lineup_bar_class(false)

    assert_equal "50.0%", lineup_bar_percent(11.25, 22.5)
    assert_equal "0.0%", lineup_bar_percent(0, 0)
  end

  private

  # A game standing on its own: no season around it, and no winner.
  def tied_matchup
    final = Game.new(season: Season.new(year: 2030), week: 2, round_name: Game::CHAMPIONSHIP)
    final.performances.build(owner: Owner.new(name: "Solo A"), points: 100)
    final.performances.build(owner: Owner.new(name: "Solo B"), points: 100)
    Almanac.new(games: [ final ]).matchup_for(final)
  end
end
