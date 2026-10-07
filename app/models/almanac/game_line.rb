class Almanac
  # One owner's score in one regular-season game, read from their side:
  # the opponent's score beside it, the week's field behind it, and the
  # season the owner was having around it.
  GameLine = Data.define(:season_record, :score) do
    delegate :owner, :year, :tier, to: :season_record
    delegate :game, :week, :points, :opponent, :opponent_points, :all_play, :result, to: :score

    # Positive in a win, negative in a loss.
    def margin
      points - opponent_points
    end

    def combined
      points + opponent_points
    end

    # How far the score sat above or below the owner's own season average.
    def versus_average
      points - season_record.average_points
    end
  end
end
