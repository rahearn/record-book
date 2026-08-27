require "test_helper"

class MyFantasyLeague::ConfigurationTest < ActiveSupport::TestCase
  setup do
    @config = MyFantasyLeague::Configuration
      .load(path: Rails.root.join("test/fixtures/files/mfl/config.yml"))
  end

  test "a season names its league, its roster and its tiers" do
    season = @config.season(2025)

    assert_equal "70967", season.league_id
    assert_equal 12, season.roster.size
    assert_equal %w[premier challenger], season.tiers.keys
    assert_equal "00", season.tier("premier").division
    assert_equal "2", season.tier("premier").playoffs.third_place
  end

  test "a division points back at the tier that played it" do
    season = @config.season(2025)

    assert_equal "challenger", season.tier_for_division("01").name
    assert_nil season.tier_for_division("07")
  end

  test "a franchise says who was behind it" do
    assert_equal "Owner 0002", @config.season(2025).owner_name("0002")
  end

  test "the file the app really ships is one the record book can read" do
    shipped = MyFantasyLeague::Configuration.load

    assert_includes shipped.years, 2025
    assert shipped.user_agent.present?
  end

  test "a franchise nobody has been put behind yet is left unnamed, not refused" do
    season = build(franchises: { "0001" => "Someone", "0002" => nil }).season(2025)

    assert_equal "Someone", season.owner_name("0001")
    assert_nil season.owner_name("0002")
  end

  test "a slot the record book has never played is a mistake worth stopping for" do
    error = assert_raises(MyFantasyLeague::Configuration::Error) do
      build(roster: %w[qb punter]).season(2025)
    end
    assert_match(/punter/, error.message)
  end

  test "a tier the record book has never run is a mistake worth stopping for" do
    error = assert_raises(MyFantasyLeague::Configuration::Error) do
      build(tiers: { "reserve" => { "division" => "02" } }).season(2025)
    end
    assert_match(/reserve/, error.message)
  end

  test "a season the file says nothing about names the ones it does" do
    error = assert_raises(MyFantasyLeague::Configuration::Error) { @config.season(1999) }
    assert_match(/2025/, error.message)
  end

  test "an unnamed client is refused, because MFL throttles those hardest" do
    assert_raises(MyFantasyLeague::Configuration::Error) do
      MyFantasyLeague::Configuration.new({}).user_agent
    end
  end

  private

  # The test season with one piece of it replaced. YAML reads a bare year as
  # a number, which is why the season is reached for by value rather than by
  # key here and looked up either way in the configuration itself.
  def build(overrides)
    document = YAML.load_file(Rails.root.join("test/fixtures/files/mfl/config.yml"))
    document["seasons"].each_value { |season| season.merge!(overrides.transform_keys(&:to_s)) }
    MyFantasyLeague::Configuration.new(document)
  end
end
