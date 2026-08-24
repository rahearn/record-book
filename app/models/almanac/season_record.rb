class Almanac
  # One owner's accumulated results within a single season (and tier).
  class SeasonRecord
    WeeklyScore = Data.define(:week, :points)

    attr_reader :owner, :year, :tier, :games_played, :wins, :losses, :ties,
      :points_for, :points_against, :luck_total
    attr_accessor :rank

    def initialize(owner:, year:, tier:)
      @owner = owner
      @year = year
      @tier = tier
      @games_played = 0
      @wins = 0
      @losses = 0
      @ties = 0
      @points_for = 0
      @points_against = 0
      @luck_total = 0
      @weekly_scores = []
    end

    def record_result(week:, points:, opponent_points:)
      @games_played += 1
      @points_for += points
      @points_against += opponent_points
      @weekly_scores << WeeklyScore.new(week: week, points: points)
      if points > opponent_points
        @wins += 1
      elsif points < opponent_points
        @losses += 1
      else
        @ties += 1
      end
    end

    def add_luck(amount)
      @luck_total += amount
    end

    def weekly_scores
      @weekly_scores.sort_by(&:week)
    end

    def score_in(week)
      @weekly_scores.find { |score| score.week == week }&.points
    end

    def highest_score
      @weekly_scores.map(&:points).max
    end

    def lowest_score
      @weekly_scores.map(&:points).min
    end

    def average_points
      points_for / games_played
    end

    def average_points_against
      points_against / games_played
    end

    def luck_per_game
      luck_total / games_played
    end

    def win_percentage
      (wins + ties * 0.5) / games_played
    end

    # Challenger-tier first places don't count as league titles.
    def champion?
      rank == 1 && tier != "challenger"
    end
  end
end
