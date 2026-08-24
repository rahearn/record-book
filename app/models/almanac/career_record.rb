class Almanac
  # One owner's all-time aggregate across their season records.
  class CareerRecord
    attr_reader :owner, :season_records, :next_tier, :titles
    attr_accessor :rank

    def initialize(owner:, season_records:, next_tier: nil, titles: 0)
      @owner = owner
      @season_records = season_records.sort_by(&:year)
      @next_tier = next_tier
      @titles = titles
    end

    def seasons_played
      season_records.size
    end

    def joined_year
      season_records.first.year
    end

    def games_played
      season_records.sum(&:games_played)
    end

    def wins
      season_records.sum(&:wins)
    end

    def losses
      season_records.sum(&:losses)
    end

    def ties
      season_records.sum(&:ties)
    end

    def points_for
      season_records.sum(&:points_for)
    end

    def points_against
      season_records.sum(&:points_against)
    end

    def luck_total
      season_records.sum(&:luck_total)
    end

    def best_finish
      season_records.map(&:final_rank).min
    end

    def win_percentage
      (wins + ties * 0.5) / games_played
    end

    def points_for_per_game
      points_for / games_played
    end

    def points_against_per_game
      points_against / games_played
    end

    def luck_per_game
      luck_total / games_played
    end
  end
end
