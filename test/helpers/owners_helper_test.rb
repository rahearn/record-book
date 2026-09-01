require "test_helper"

class OwnersHelperTest < ActionView::TestCase
  include LeagueHelper

  FakeScore = Struct.new(:result)

  test "owner_select_options groups current owners ahead of former ones, alphabetical within each group" do
    eve = Owner.create!(name: "Eve Ellis")
    frank = Owner.create!(name: "Frank Ford")
    past_season = Season.create!(year: 2010)
    Team.create!(owner: eve, season: past_season, name: "Ellis Eagles")
    Team.create!(owner: frank, season: past_season, name: "Ford Falcons")
    game = Game.create!(season: past_season, week: 1)
    Performance.create!(game: game, owner: eve, points: 50)
    Performance.create!(game: game, owner: frank, points: 40)

    groups = owner_select_options(Almanac.new)
    current_label, current_options = groups[0]
    former_label, former_options = groups[1]

    assert_equal "Current", current_label
    assert_equal [ "Alice Anders — Anders Aces", "Bob Barker — Barker Bandits",
      "Carol Chen — Chen Chargers", "Dan Diaz — Diaz Dynamo" ], current_options.map(&:first)

    assert_equal "Former", former_label
    assert_equal [ "Eve Ellis — Ellis Eagles", "Frank Ford — Ford Falcons" ], former_options.map(&:first)
  end

  test "owner_select_options omits a group with no owners in it" do
    groups = owner_select_options(Almanac.new)
    assert_equal [ "Current" ], groups.map(&:first)
  end

  test "finish_display stars first place" do
    assert_equal "1st ★", finish_display(1)
    assert_equal "2nd", finish_display(2)
    assert_equal "4th", finish_display(4)
  end

  test "owner_blurb summarizes tenure and next tier" do
    almanac = Almanac.new(promotion_count: 1, relegation_count: 1)
    assert_equal "2 seasons · joined 2023 · Premier in 2025",
      owner_blurb(almanac, almanac.career_for(owners(:alice)))
    assert_equal "2 seasons · joined 2023 · Challenger in 2025",
      owner_blurb(almanac, almanac.career_for(owners(:bob)))
  end

  test "owner_blurb omits the tier without a ladder" do
    owner_a = Owner.new(name: "Solo A")
    owner_b = Owner.new(name: "Solo B")
    game = Game.new(season: Season.new(year: 2030), week: 1)
    game.performances.build(owner: owner_a, points: 100)
    game.performances.build(owner: owner_b, points: 90)

    almanac = Almanac.new(games: [ game ])
    assert_equal "1 season · joined 2030", owner_blurb(almanac, almanac.career_for(owner_a))
  end

  test "league_rank_note and best_finish_note" do
    assert_equal "League rank 2 of 20", league_rank_note(2, 20)

    almanac = Almanac.new
    assert_equal "Best finish: 1st", best_finish_note(almanac.career_for(owners(:alice)))
    assert_equal "Best finish: 2nd", best_finish_note(almanac.career_for(owners(:dan)))
  end

  test "luck_note reads the record against the schedule that earned it" do
    career = Almanac.new.career_for(owners(:alice))
    assert_equal "3–0 against a 3.00-win schedule", luck_note(career)
  end

  test "week_luck_note counts the results that turned on the opponent" do
    record = Almanac.new.standings_for(2023, :unified).find { |row| row.owner == owners(:carol) }
    assert_equal "1–1 against a 0.67-win schedule · 1 win needed an opponent scoring below " \
      "their own season average, 0 losses came against one who beat theirs. " \
      "Outlined weeks went against the all-play field.", week_luck_note(record)
  end

  test "year_or_dash shows the year or an em dash" do
    assert_equal "2024", year_or_dash(2024)
    assert_equal "—", year_or_dash(nil)
  end

  test "bar_percent scales against the maximum" do
    assert_equal "50.0%", bar_percent(60, 120)
    assert_equal "83.3%", bar_percent(100, 120)
  end

  test "week result labels and tags" do
    assert_equal "W", week_result_label(FakeScore.new(:win))
    assert_equal "L", week_result_label(FakeScore.new(:loss))
    assert_equal "T", week_result_label(FakeScore.new(:tie))
    assert_equal "tag-accent", week_result_tag_class(FakeScore.new(:win))
    assert_equal "tag-neutral", week_result_tag_class(FakeScore.new(:loss))
    assert_equal "tag-outline", week_result_tag_class(FakeScore.new(:tie))
  end
end
