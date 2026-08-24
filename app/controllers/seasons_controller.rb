class SeasonsController < ApplicationController
  def show
    @almanac = Almanac.new
    return if @almanac.empty?

    @year = (params[:year] || @almanac.latest_year).to_i
    unless @almanac.years.include?(@year)
      raise ActiveRecord::RecordNotFound, "No #{@year} season on record"
    end

    @split = @almanac.split_season?(@year)
    @tier = @split ? requested_tier : :unified
    @standings = @almanac.standings_for(@year, @tier)
    @matrix = @almanac.week_matrix(@year, @tier)
  end

  private

  def requested_tier
    params[:tier] == "challenger" ? :challenger : :premier
  end
end
