class OwnersController < ApplicationController
  def show
    @almanac = Almanac.new
    return if @almanac.empty?

    @owner = params[:id] ? Owner.find(params[:id]) : @almanac.all_time_standings.first.owner
    @career = @almanac.career_for(@owner)
    unless @career
      raise ActiveRecord::RecordNotFound, "No games on record for #{@owner.name}"
    end

    @chart_record = chart_record
    @chart_max = @chart_record.weekly_scores
      .flat_map { |score| [ score.points, score.opponent_points ] }.max.to_f * 1.06
    @head_to_head = @almanac.head_to_head_for(@owner)
    @playoff_history = @almanac.playoff_history_for(@owner)
  end

  private

  # The season shown week by week: the requested year if the owner played it,
  # otherwise their most recent season.
  def chart_record
    requested = params[:season].to_i
    @career.season_records.find { |record| record.year == requested } ||
      @career.season_records.last
  end
end
