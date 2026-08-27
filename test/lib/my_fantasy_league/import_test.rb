require "test_helper"
require_relative "../../support/mfl_stub_client"

class MyFantasyLeague::ImportTest < ActiveSupport::TestCase
  setup do
    @config = MyFantasyLeague::Configuration
      .load(path: Rails.root.join("test/fixtures/files/mfl/config.yml"))
    (1..20).each { |number| Owner.create!(name: format("Owner %04d", number)) }
    @client = MflStubClient.new
    @reported = []
  end

  test "a season arrives with its shape, its teams and its games" do
    import

    season = Season.find_by!(year: 2025)
    assert_equal %w[qb wr wr rb rb te wr_rb_te dst bench bench bench bench], season.roster_format.slots
    assert_equal 20, season.teams.count
    assert_equal "Dart Hard", season.teams.find_by(owner: owner("0002")).name

    assert_equal 15, season.playoff_format_for(:premier).start_week
    assert_equal 6, season.playoff_format_for(:premier).team_count
    assert_equal 4, season.playoff_format_for(:challenger).team_count

    assert_equal 150, season.games.count
    assert_equal 140, season.games.regular_season.count
    assert_equal 300, Performance.joins(:game).where(games: { season: season }).count
  end

  test "a matchup is written with both sides and the score each was given" do
    import(week: 1, tiers: [ "premier" ])

    game = games_for(1, "premier").find { |played| played.owners.include?(owner("0002")) }
    assert_equal({ "Owner 0002" => 85.92, "Owner 0013" => 104.74 },
                 game.performances.to_h { |side| [ side.owner.name, side.points.to_f ] })
    assert_nil game.round_name
  end

  test "the playoffs are named round by round" do
    import

    assert_equal [ "Quarterfinal" ], round_names(15, "premier")
    assert_equal [ Game::SEMIFINAL ], round_names(16, "premier")
    assert_equal [ Game::CHAMPIONSHIP, Game::THIRD_PLACE ], round_names(17, "premier")
    assert_equal [ Game::SEMIFINAL ], round_names(15, "challenger")
    assert_equal [ Game::CHAMPIONSHIP, Game::THIRD_PLACE ], round_names(16, "challenger")
  end

  test "a lineup is seated into the slots the season was played with" do
    import(week: 1, tiers: [ "premier" ])

    lineup = performance(1, "0002").lineup_slots.ordered
    assert_equal %w[qb wr wr rb rb te wr_rb_te dst bench bench bench bench], lineup.map(&:slot)
    assert_equal (1..12).to_a, lineup.map(&:sequence)

    assert_equal "Dak Prescott", lineup.find(&:qb?).player_name
    assert_equal "Arizona Cardinals", lineup.find(&:dst?).player_name
    # Three backs and two receivers, so the flex takes the spare back —
    # which of them lands there is the seating's business, not the record's.
    assert_equal [ "rb" ], lineup.find(&:wr_rb_te?).player_positions
    assert_equal [ "Bucky Irving", "Chase Brown", "Kenneth Walker III" ],
                 lineup.select { |slot| slot.rb? || slot.wr_rb_te? }.map(&:player_name).sort
    assert_equal "TB", lineup.find { |slot| slot.player_name == "Bucky Irving" }.player_nfl_team
  end

  test "a lineup adds back up to the score it was given" do
    import(week: 1)

    performances = Performance.joins(game: :season).where(seasons: { year: 2025 }, games: { week: 1 })
    assert_equal 20, performances.count
    performances.each do |recorded|
      assert_equal recorded.points, recorded.starters.sum(&:points), recorded.display_name
    end
  end

  test "a bench player MFL never scored is written down as nothing rather than left out" do
    import(week: 1, tiers: [ "premier" ])

    assert_equal 12, performance(1, "0002").lineup_slots.count
  end

  test "weeks with no lineup on record still get their scores" do
    import

    assert performance(2, "0002").points.positive?
    assert_empty performance(2, "0002").lineup_slots
  end

  test "re-importing a week leaves the same games in place" do
    import(week: 1, tiers: [ "premier" ])
    before = games_for(1, "premier").map(&:id).sort

    import(week: 1, tiers: [ "premier" ])

    assert_equal before, games_for(1, "premier").map(&:id).sort
    assert_equal 12, performance(1, "0002").lineup_slots.count
  end

  test "a scoring adjustment moves the score the record book holds" do
    import(week: 1, tiers: [ "premier" ])
    assert_equal 85.92, performance(1, "0002").points.to_f

    adjust(week: 1, franchise_id: "0002", points: "95.92")
    import(week: 1, tiers: [ "premier" ])

    assert_equal 95.92, performance(1, "0002").points.to_f
    assert_equal 6, games_for(1, "premier").size
  end

  test "an adjustment to a player moves the lineup it was scored in" do
    import(week: 1, tiers: [ "premier" ])

    starter = @client.payload("weekly_results_1")["weeklyResults"]["matchup"]
      .flat_map { |matchup| matchup["franchise"] }.find { |franchise| franchise["id"] == "0002" }
      .then { |franchise| franchise["player"].first }
    starter["score"] = "30.00"
    import(week: 1, tiers: [ "premier" ])

    assert_equal 30.00, performance(1, "0002").lineup_slots.ordered.first.points.to_f
    assert_equal 12, performance(1, "0002").lineup_slots.count
  end

  test "a game MFL no longer has is dropped rather than left behind" do
    import(week: 1, tiers: [ "premier" ])
    assert_equal 6, games_for(1, "premier").size

    weekly = @client.schedule.find { |scheduled| scheduled["week"] == "1" }
    weekly["matchup"] = weekly["matchup"].reject do |matchup|
      matchup["franchise"].any? { |franchise| franchise["id"] == "0002" }
    end
    import(week: 1, tiers: [ "premier" ])

    assert_equal 5, games_for(1, "premier").size
    assert_empty games_for(1, "premier").select { |game| game.owners.include?(owner("0002")) }
  end

  test "one tier can be imported without touching the other" do
    import(week: 1, tiers: [ "premier" ])

    assert_equal 6, games_for(1, "premier").size
    assert_empty games_for(1, "challenger")
  end

  test "the whole season is asked for in one request, a single week in one of its own" do
    import
    import(week: 3)

    assert_equal [ nil, 3 ], @client.weeks_asked_for
  end

  test "a franchise nobody has been put behind stops the import" do
    season = @config.season(2025)
    unnamed = season.with(franchises: season.franchises.except("0002"))

    error = assert_raises(MyFantasyLeague::Import::Error) { import(week: 1, season: unnamed) }
    assert_match(/does not name the owner behind 0002/, error.message)
    assert_nil Season.find_by(year: 2025)
  end

  test "an owner the record book has never heard of stops the import" do
    Owner.find_by!(name: "Owner 0002").destroy!

    error = assert_raises(MyFantasyLeague::Import::Error) { import(week: 1) }
    assert_match(/no owner named Owner 0002/, error.message)
    assert_nil Season.find_by(year: 2025)
  end

  test "a roster too small for the lineups MFL sends stops the import" do
    error = assert_raises(MyFantasyLeague::Import::Error) do
      import(week: 1, season: @config.season(2025).with(roster: %w[qb rb wr te dst bench]))
    end

    assert_match(/room for 6/, error.message)
    assert_nil Season.find_by(year: 2025)
  end

  test "a tier the season never had is a mistake worth stopping for" do
    assert_raises(MyFantasyLeague::Import::Error) { import(tiers: [ "unified" ]) }
  end

  test "each week reports what it wrote" do
    import(week: 1)

    assert_equal [ "2025 week 1 challenger: 4 games", "2025 week 1 premier: 6 games" ], @reported.sort
  end

  private

  def import(week: nil, tiers: nil, season: nil)
    config = season ? StubConfiguration.new(@config, season) : @config
    MyFantasyLeague::Import.new(year: 2025, config: config, client: @client,
                                report: ->(line) { @reported << line })
      .call(week: week, tiers: tiers)
  end

  # Swaps in a season the file does not describe, for the cases that are
  # about the importer meeting a league it was configured wrongly for.
  StubConfiguration = Struct.new(:config, :replacement) do
    def user_agent = config.user_agent
    def season(_year) = replacement
  end

  def owner(franchise_id)
    Owner.find_by!(name: @config.season(2025).owner_name(franchise_id))
  end

  def games_for(week, tier)
    Season.find_by!(year: 2025).games.includes(:owners).where(week: week, tier: tier).to_a
  end

  def round_names(week, tier)
    games_for(week, tier).map(&:round_name).uniq.sort
  end

  def performance(week, franchise_id)
    Performance.joins(game: :season)
      .find_by!(seasons: { year: 2025 }, games: { week: week }, owner: owner(franchise_id))
  end

  def adjust(week:, franchise_id:, points:)
    @client.scheduled_matchup(week, franchise_id)["franchise"]
      .find { |franchise| franchise["id"] == franchise_id }["score"] = points
  end
end
