require "test_helper"
require_relative "../../support/mfl_stub_client"

class MyFantasyLeague::PlayerDirectoryTest < ActiveSupport::TestCase
  setup do
    @client = MflStubClient.new
    @directory = MyFantasyLeague::PlayerDirectory.for(@client, @client.payload("players")["players"]["player"]
      .map { |player| player["id"] })
  end

  test "names read the way they are said, surname last" do
    assert_equal "Dak Prescott", find("Prescott, Dak").name
    assert_equal "Ja'Marr Chase", find("Chase, Ja'Marr").name
  end

  test "a suffix stays on the surname it belongs to" do
    assert_equal "Kenneth Walker III", find("Walker III, Kenneth").name
  end

  test "a team defense reads as the team it is" do
    defense = find("Cardinals, Arizona")

    assert_equal "Arizona Cardinals", defense.name
    assert_equal [ "dst" ], defense.positions
  end

  test "NFL teams are written the way the rest of the record book writes them" do
    assert_equal "KC", build("team" => "KCC").nfl_team
    assert_equal "SF", build("team" => "SFO").nfl_team
    assert_equal "JAX", build("team" => "JAC").nfl_team
    assert_equal "ARI", build("team" => "ARI").nfl_team
  end

  test "a player with no team is a free agent" do
    assert_equal "FA", build("team" => nil).nfl_team
  end

  test "positions become the slots the record book knows" do
    assert_equal [ "k" ], build("position" => "PK").positions
    assert_equal [ "qb" ], build("position" => "TMQB").positions
  end

  test "a position with no slot behind it stops the import" do
    error = assert_raises(MyFantasyLeague::PlayerDirectory::Error) { build("position" => "LB") }
    assert_match(/not a position/, error.message)
  end

  test "a player nobody looked up is a mistake worth stopping for" do
    assert_raises(MyFantasyLeague::PlayerDirectory::Error) { @directory.fetch("99999") }
  end

  private

  def find(written)
    record = @client.payload("players")["players"]["player"].find { |player| player["name"] == written }
    @directory.fetch(record.fetch("id"))
  end

  def build(overrides)
    record = { "id" => "1", "name" => "Doe, John", "position" => "RB", "team" => "DAL" }.merge(overrides)
    MyFantasyLeague::PlayerDirectory.new([ record ]).fetch("1")
  end
end
