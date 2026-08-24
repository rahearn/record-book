class Almanac
  # One owner's playoff record across the unified league and the Premier
  # tier. Challenger seasons count as missed playoffs, and Challenger
  # playoff runs contribute nothing.
  class PlayoffHistory
    Result = Data.define(:year, :round_name, :won, :tied)

    # season_flags: whether the owner made the (unified/Premier) playoffs in
    # each of their seasons, oldest first. results: one entry per playoff
    # game they played.
    def initialize(season_flags:, results:)
      @season_flags = season_flags
      @results = results.sort_by(&:year)
    end

    def longest_playoff_streak
      longest_run(true)
    end

    def active_playoff_streak
      active_run(true)
    end

    def longest_playoff_drought
      longest_run(false)
    end

    def active_playoff_drought
      active_run(false)
    end

    def last_playoff_win_year
      @results.select(&:won).map(&:year).max
    end

    def last_semifinal_year
      last_year_in_round(Game::SEMIFINAL)
    end

    def last_final_year
      last_year_in_round(Game::CHAMPIONSHIP)
    end

    def last_appearance_year
      @results.map(&:year).max
    end

    def appearances
      @results.map(&:year).uniq.size
    end

    def playoff_wins
      @results.count(&:won)
    end

    def runner_up_finishes
      @results.count { |result| result.round_name == Game::CHAMPIONSHIP && !result.won && !result.tied }
    end

    private

    def last_year_in_round(round_name)
      @results.select { |result| result.round_name == round_name }.map(&:year).max
    end

    def longest_run(value)
      best = current = 0
      @season_flags.each do |flag|
        current = flag == value ? current + 1 : 0
        best = [ best, current ].max
      end
      best
    end

    def active_run(value)
      @season_flags.reverse.take_while { |flag| flag == value }.size
    end
  end
end
