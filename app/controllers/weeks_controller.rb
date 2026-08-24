class WeeksController < ApplicationController
  def show
    @almanac = Almanac.new
    @year = params[:year].to_i
    unless @almanac.years.include?(@year)
      raise ActiveRecord::RecordNotFound, "No #{@year} season on record"
    end

    @split = @almanac.split_season?(@year)
    @tier = @split ? requested_tier : :unified
    @week = params[:week].to_i
    @weeks = @almanac.weeks_in(@year, @tier)
    @scoreboard = @almanac.scoreboard_for(@year, @week, @tier)
    if @scoreboard.empty?
      raise ActiveRecord::RecordNotFound, "No week #{@week} games on record for #{@year}"
    end
  end

  private

  def requested_tier
    params[:tier] == "challenger" ? :challenger : :premier
  end
end
