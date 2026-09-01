class Almanac
  # A single game seen from both sides at once: the two scores, the season
  # each owner was having at the time, and the starting lineups paired slot
  # by slot the way the matchup page reads them.
  class Matchup
    # One owner's side of the matchup. The season record is absent when the
    # owner has no regular-season games on record for that year, and the
    # weekly score with it — playoff games are not part of a season record,
    # so they carry no all-play line.
    Side = Data.define(:performance, :season_record, :weekly_score) do
      def owner
        performance.owner
      end

      def points
        performance.points
      end

      def starters
        performance.starters
      end

      def reserves
        performance.reserves
      end

      def lineup?
        performance.lineup?
      end

      def points_left_on_bench
        performance.points_left_on_bench
      end

      def average_points
        season_record&.average_points
      end

      # How far above (+) or below (−) the owner's own season average this
      # score was, or nil without a season on record.
      def points_vs_average
        points - season_record.average_points if season_record
      end

      # The score's record against every other score in the same week, or
      # nil for a game that is not part of the regular season.
      def all_play
        weekly_score&.all_play
      end
    end

    # The same slot on both sides, so the two players can be compared directly.
    # Either entry is absent when the lineups are shaped differently.
    SlotRow = Data.define(:entry_a, :entry_b) do
      def slot
        (entry_a || entry_b).slot
      end

      def a_leads?
        entry_a && (entry_b.nil? || entry_a.points >= entry_b.points)
      end

      def b_leads?
        entry_b && (entry_a.nil? || entry_b.points > entry_a.points)
      end
    end

    attr_reader :game, :side_a, :side_b

    def initialize(game:, side_a:, side_b:)
      @game = game
      @side_a = side_a
      @side_b = side_b
    end

    def year
      game.season.year
    end

    def week
      game.week
    end

    def tier
      game.tier
    end

    def round_name
      game.round_name
    end

    def playoff?
      game.playoff?
    end

    def sides
      [ side_a, side_b ]
    end

    def margin
      (side_a.points - side_b.points).abs
    end

    def tied?
      side_a.points == side_b.points
    end

    def winner
      return if tied?

      side_a.points > side_b.points ? side_a.owner : side_b.owner
    end

    def lineups?
      sides.all?(&:lineup?)
    end

    def slot_rows
      starters_a = side_a.starters
      starters_b = side_b.starters
      Array.new([ starters_a.size, starters_b.size ].max) do |index|
        SlotRow.new(entry_a: starters_a[index], entry_b: starters_b[index])
      end
    end

    # Scale for the comparison bars: the best starting score in the game.
    def best_starter_points
      sides.flat_map(&:starters).map(&:points).max || 0
    end
  end
end
