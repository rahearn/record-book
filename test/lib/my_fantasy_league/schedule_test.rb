require "test_helper"
require_relative "../../support/mfl_stub_client"

class MyFantasyLeague::ScheduleTest < ActiveSupport::TestCase
  setup do
    @client = MflStubClient.new
    @season = MyFantasyLeague::Configuration
      .load(path: Rails.root.join("test/fixtures/files/mfl/config.yml")).season(2025)
    @schedule = MyFantasyLeague::Schedule.load(client: @client, season: @season)
  end

  test "a franchise's division says which tier it played in" do
    assert_equal "premier", @schedule.tier_for("0002")
    assert_equal "challenger", @schedule.tier_for("0015")
    assert_nil @schedule.tier_for("9999")
  end

  test "the regular season is every week before the playoffs start" do
    weeks = regular_season.group_by(&:week)

    assert_equal (1..14).to_a, weeks.keys.sort
    assert weeks.values.all? { |matchups| matchups.size == 10 }
    assert_equal 6, weeks[1].count { |matchup| matchup.tier == "premier" }
    assert_equal 4, weeks[1].count { |matchup| matchup.tier == "challenger" }
  end

  test "scores come across as they were written down" do
    matchup = regular_season.find { |game| game.week == 1 && game.sides.map(&:franchise_id).include?("0002") }

    assert_equal "premier", matchup.tier
    assert_equal({ "0002" => "85.92", "0013" => "104.74" },
                 matchup.sides.to_h { |side| [ side.franchise_id, side.points ] })
  end

  test "the playoffs count their rounds back from the final" do
    assert_equal({ [ 15, "Quarterfinal" ] => 2, [ 16, Game::SEMIFINAL ] => 2,
                   [ 17, Game::CHAMPIONSHIP ] => 1, [ 17, Game::THIRD_PLACE ] => 1 },
                 rounds_for("premier"))
  end

  test "a shorter bracket starts at the semifinal instead" do
    assert_equal({ [ 15, Game::SEMIFINAL ] => 2, [ 16, Game::CHAMPIONSHIP ] => 1,
                   [ 16, Game::THIRD_PLACE ] => 1 },
                 rounds_for("challenger"))
  end

  test "the playoff weeks are taken from the brackets, not the schedule" do
    played = @schedule.matchups.select { |matchup| matchup.week >= 15 }

    assert_equal 10, played.size
    assert played.all? { |matchup| matchup.round_name.present? }
  end

  test "each tier's playoff format comes off its own bracket" do
    premier, challenger = @schedule.playoff_formats.sort_by(&:tier).reverse

    assert_equal [ "premier", 15, 6 ], [ premier.tier, premier.start_week, premier.team_count ]
    assert_equal [ "challenger", 15, 4 ], [ challenger.tier, challenger.start_week, challenger.team_count ]
  end

  test "a tier whose playoffs are not set up yet plays on to MFL's last regular week" do
    undecided = @season.with(tiers: @season.tiers.transform_values { |tier| tier.with(playoffs: nil) })
    schedule = MyFantasyLeague::Schedule.load(client: @client, season: undecided)

    assert_empty schedule.playoff_formats
    assert_equal (1..14).to_a, schedule.matchups.map(&:week).uniq.sort
    assert_nil schedule.matchups.map(&:round_name).compact.first
  end

  test "a bracket the league does not have is a mistake worth stopping for" do
    astray = @season.with(tiers: { "premier" => @season.tier("premier")
      .with(playoffs: MyFantasyLeague::Configuration::Playoffs.new(bracket: "9", third_place: nil)) })

    error = assert_raises(MyFantasyLeague::Schedule::Error) do
      MyFantasyLeague::Schedule.load(client: @client, season: astray).matchups
    end
    assert_match(/bracket 9/, error.message)
  end

  test "team names come from MFL" do
    assert_equal "Dart Hard", @schedule.franchise_names.fetch("0002")
    assert_equal 20, @schedule.franchise_names.size
  end

  private

  def regular_season
    @schedule.matchups.reject(&:round_name)
  end

  def rounds_for(tier)
    @schedule.matchups.select { |matchup| matchup.tier == tier && matchup.round_name }
      .group_by { |matchup| [ matchup.week, matchup.round_name ] }.transform_values(&:size)
  end
end
