class Almanac
  # Every meeting between two owners, viewed from owner A's side.
  class Series
    Meeting = Data.define(:game, :points_a, :points_b) do
      def year
        game.season.year
      end

      def week
        game.week
      end

      def tier
        game.tier
      end

      def margin
        (points_a - points_b).abs
      end

      def tied?
        points_a == points_b
      end
    end

    attr_reader :owner_a, :owner_b, :meetings

    def initialize(owner_a:, owner_b:, meetings:)
      @owner_a = owner_a
      @owner_b = owner_b
      @meetings = meetings.sort_by { |meeting| [ -meeting.year, -meeting.week ] }
    end

    def games_played
      meetings.size
    end

    def wins_a
      meetings.count { |meeting| meeting.points_a > meeting.points_b }
    end

    def wins_b
      meetings.count { |meeting| meeting.points_b > meeting.points_a }
    end

    def ties
      meetings.count(&:tied?)
    end

    def first_year
      meetings.map(&:year).min
    end

    def average_points_a
      games_played.zero? ? 0 : meetings.sum(&:points_a) / games_played
    end

    def average_points_b
      games_played.zero? ? 0 : meetings.sum(&:points_b) / games_played
    end

    def winner_of(meeting)
      return if meeting.tied?

      meeting.points_a > meeting.points_b ? owner_a : owner_b
    end
  end
end
