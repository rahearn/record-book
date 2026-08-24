class Almanac
  # The scores-by-week grid for one season (and tier): a column per played
  # week, a row per owner, with each week's high and low score flagged.
  class WeekMatrix
    Cell = Data.define(:week, :points, :highest, :lowest)
    Row = Data.define(:record, :cells)

    attr_reader :weeks, :rows

    def initialize(records:)
      @weeks = records.flat_map { |record| record.weekly_scores.map(&:week) }.uniq.sort
      highs, lows = week_extremes(records)
      @rows = records.map do |record|
        cells = @weeks.map do |week|
          points = record.score_in(week)
          Cell.new(week: week, points: points,
                   highest: !points.nil? && points == highs[week],
                   lowest: !points.nil? && points == lows[week])
        end
        Row.new(record: record, cells: cells)
      end
    end

    private

    def week_extremes(records)
      highs = {}
      lows = {}
      @weeks.each do |week|
        points = records.filter_map { |record| record.score_in(week) }
        highs[week] = points.max
        lows[week] = points.min
      end
      [ highs, lows ]
    end
  end
end
