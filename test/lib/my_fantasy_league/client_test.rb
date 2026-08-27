require "test_helper"

# The client's own job is unwrapping what MFL sends and telling an answer
# from an excuse, so the tests stand in for the network and leave the
# HTTP plumbing to Net::HTTP.
class MyFantasyLeague::ClientTest < ActiveSupport::TestCase
  # Answers a canned payload per request type, and records what was asked.
  class Stub < MyFantasyLeague::Client
    attr_reader :asked

    def initialize(payloads)
      super(year: 2025, league_id: "70967", user_agent: "test", throttle: 0)
      @payloads = payloads
      @asked = []
    end

    private

    def fetch(uri)
      @asked << URI.decode_www_form(uri.query).to_h.merge("host" => uri.host)
      @payloads.fetch(@asked.last["TYPE"])
    end
  end

  test "a payload comes back unwrapped from the key it arrived under" do
    client = Stub.new("league" => { "league" => { "name" => "ATΩ Delta 25" } })

    assert_equal "ATΩ Delta 25", client.league["name"]
    assert_equal({ "TYPE" => "league", "JSON" => "1", "L" => "70967",
                   "host" => MyFantasyLeague::Client::API_HOST }, client.asked.sole)
  end

  test "the league says which host the rest of its requests belong on" do
    client = Stub.new("league" => { "league" => { "baseURL" => "https://www47.myfantasyleague.com" } },
                      "schedule" => { "schedule" => { "weeklySchedule" => [] } })
    client.league
    client.schedule

    assert_equal "www47.myfantasyleague.com", client.asked.last["host"]
  end

  test "one round arrives as an object where a pair arrives as a list" do
    client = Stub.new("playoffBracket" => { "playoffBracket" => { "playoffRound" => { "week" => "17" } } })

    assert_equal [ { "week" => "17" } ], client.playoff_bracket("2")
  end

  test "a single week and the whole year unwrap to the same list of weeks" do
    year = { "allWeeklyResults" => { "weeklyResults" => [ { "week" => "1" }, { "week" => "2" } ] } }
    assert_equal %w[1 2], Stub.new("weeklyResults" => year).weekly_results.map { |week| week["week"] }

    week = { "weeklyResults" => { "week" => "3" } }
    assert_equal %w[3], Stub.new("weeklyResults" => week).weekly_results(week: 3).map { |w| w["week"] }
  end

  test "the player lookup goes to the API host rather than the league's" do
    client = Stub.new("league" => { "league" => { "baseURL" => "https://www47.myfantasyleague.com" } },
                      "players" => { "players" => { "player" => [ { "id" => "0680" } ] } })
    client.league

    assert_equal [ { "id" => "0680" } ], client.players(%w[0680 0680])
    assert_equal MyFantasyLeague::Client::API_HOST, client.asked.last["host"]
    assert_equal "0680", client.asked.last["PLAYERS"]
    assert_not client.asked.last.key?("L")
  end

  test "an error MFL dresses up as a payload is still an error" do
    client = Stub.new("league" => { "error" => { "$t" => "Missing League ID" } })

    error = assert_raises(MyFantasyLeague::Client::Error) { client.league }
    assert_match(/Missing League ID/, error.message)
  end

  test "a payload without the thing that was asked for is an error too" do
    client = Stub.new("schedule" => { "version" => "1.0" })

    assert_raises(MyFantasyLeague::Client::Error) { client.schedule }
  end
end
