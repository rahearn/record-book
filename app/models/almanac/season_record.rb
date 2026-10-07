class Almanac
  # One owner's accumulated results within a single season (and tier).
  class SeasonRecord
    WeeklyScore = Data.define(:game, :points, :opponent, :opponent_points, :all_play) do
      def week
        game.week
      end

      # Whether the week's result went the way the whole field would have
      # sent it — the weeks where it didn't are where luck lives.
      def against_the_field?
        return false if all_play.wins == all_play.losses

        (points > opponent_points) != (all_play.wins > all_play.losses)
      end

      def result
        if points > opponent_points
          :win
        elsif points < opponent_points
          :loss
        else
          :tie
        end
      end
    end

    attr_reader :owner, :year, :tier, :games_played, :wins, :losses, :ties,
      :points_for, :points_against, :expected_wins, :opponent_shortfall_total,
      :swing_wins_gained, :swing_wins_lost, :remaining_games
    # rank orders the regular season (and drives relegation and zone
    # shading); final_rank folds the playoffs in — finishers take the top
    # spots, everyone else keeps their regular-season order.
    attr_accessor :rank, :final_rank

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
      @expected_wins = 0.0
      @opponent_shortfall_total = 0
      @swing_wins_gained = 0
      @swing_wins_lost = 0
      @weekly_scores = []
      @remaining_opponents = []
      @remaining_games = 0
    end

    def record_result(game:, points:, opponent:, opponent_points:, all_play:)
      @games_played += 1
      @points_for += points
      @points_against += opponent_points
      @expected_wins += all_play.expected_wins
      @weekly_scores << WeeklyScore.new(game: game, points: points, opponent: opponent,
                                        opponent_points: opponent_points, all_play: all_play)
      if points > opponent_points
        @wins += 1
      elsif points < opponent_points
        @losses += 1
      else
        @ties += 1
      end
    end

    # One game measured against the season the opponent was having: how far
    # they fell short of their own average, and whether the result would
    # have gone the other way had they played to it.
    def record_opponent_context(points:, opponent_points:, opponent_average:)
      @opponent_shortfall_total += opponent_average - opponent_points
      actual = result_value(points, opponent_points)
      expected = result_value(points, opponent_average)
      @swing_wins_gained += actual - expected if actual > expected
      @swing_wins_lost += expected - actual if expected > actual
    end

    # One game still to be played this season. The opponent's record is
    # theirs to date, and nil when they have yet to play.
    def schedule_game(opponent_record:)
      @remaining_games += 1
      @remaining_opponents << opponent_record if opponent_record
    end

    def weekly_scores
      @weekly_scores.sort_by(&:week)
    end

    def score_in(week)
      @weekly_scores.find { |score| score.week == week }&.points
    end

    def score_for(game)
      @weekly_scores.find { |score| score.game == game }
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

    # Wins above the record the weekly scores earned against the field.
    def all_play_luck
      wins + ties * 0.5 - expected_wins
    end

    def opponent_shortfall_per_game
      opponent_shortfall_total / games_played
    end

    # Results that turn on the opponent's shortfall: wins that needed one,
    # net of losses to an opponent who beat their own average.
    def swing_wins
      swing_wins_gained - swing_wins_lost
    end

    def win_percentage
      (wins + ties * 0.5) / games_played
    end

    # The share of the field the week's scores have beaten, on average: the
    # all-play record as a winning percentage.
    def all_play_percentage
      expected_wins / games_played
    end

    # How hard the games still to play look: the remaining opponents'
    # all-play percentage to date, averaged game by game, so an opponent
    # faced twice counts twice. Nil when there is nothing left to measure.
    def remaining_strength_of_schedule
      return if @remaining_opponents.empty?

      @remaining_opponents.sum(&:all_play_percentage) / @remaining_opponents.size
    end

    private

    def result_value(points, opponent_points)
      if points > opponent_points
        1.0
      elsif points < opponent_points
        0.0
      else
        0.5
      end
    end
  end
end
