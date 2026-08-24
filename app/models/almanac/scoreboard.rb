class Almanac
  # Every matchup played in one week of a season and tier, with the week's
  # scoring extremes so the standout and the stinker can be marked.
  class Scoreboard
    attr_reader :year, :week, :tier, :matchups

    def initialize(year:, week:, tier:, matchups:)
      @year = year
      @week = week
      @tier = tier
      @matchups = matchups
    end

    def empty?
      matchups.empty?
    end

    def sides
      matchups.flat_map(&:sides)
    end

    def highest_score
      scores.max
    end

    def lowest_score
      scores.min
    end

    def average_score
      scores.sum / scores.size
    end

    def highest?(side)
      side.points == highest_score
    end

    def lowest?(side)
      side.points == lowest_score
    end

    private

    def scores
      @scores ||= sides.map(&:points)
    end
  end
end
