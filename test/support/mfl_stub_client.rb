require "json"

# Answers the importer out of payloads MyFantasyLeague really sent for the
# 2025 season, so everything downstream of the network is exercised against
# the shapes it will actually meet — a lone playoff round arriving as an
# object where a pair arrives as a list, a bench player with no score at all.
#
# The payloads are parsed once and handed out as they are, so a test that
# wants to move a score can reach into `payload` and do so before importing.
class MflStubClient
  ROOT = "test/fixtures/files/mfl".freeze

  attr_reader :weeks_asked_for

  def initialize
    @payloads = {}
    @weeks_asked_for = []
  end

  def payload(name)
    @payloads[name] ||= JSON.parse(Rails.root.join(ROOT, "#{name}.json").read)
  end

  def league
    payload("league")["league"]
  end

  def schedule
    Array.wrap(payload("schedule")["schedule"]["weeklySchedule"])
  end

  def playoff_brackets
    Array.wrap(payload("playoff_brackets")["playoffBrackets"]["playoffBracket"])
  end

  def playoff_bracket(bracket_id)
    Array.wrap(payload("bracket_#{bracket_id}")["playoffBracket"]["playoffRound"])
  end

  # Only week one is on file, which is also what a season part-way through
  # its lineups looks like: every other week has scores but no lineup.
  def weekly_results(week: nil)
    @weeks_asked_for << week
    [ payload("weekly_results_1")["weeklyResults"] ].select do |results|
      week.nil? || results["week"].to_i == week
    end
  end

  def players(ids)
    payload("players")["players"]["player"].select { |player| ids.include?(player["id"]) }
  end

  # The matchup a week was played over, for a test that wants to adjust it.
  def scheduled_matchup(week, franchise_id)
    weekly = schedule.find { |scheduled| scheduled["week"].to_i == week }
    weekly["matchup"].find do |matchup|
      matchup["franchise"].any? { |franchise| franchise["id"] == franchise_id }
    end
  end
end
