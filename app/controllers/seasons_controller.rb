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

    season = Season.find_by(year: @year)
    @playoff_format = season&.playoff_format_for(@tier)
    @playoff_rounds = playoff_rounds(season)
  end

  private

  def requested_tier
    params[:tier] == "challenger" ? :challenger : :premier
  end

  # Playoff games for the displayed tier, grouped into rounds in week
  # order, with the Championship after its week's other games.
  def playoff_rounds(season)
    return {} unless season

    season.games.playoff.where(tier: @tier)
      .includes(performances: :owner)
      .order(:week, :id)
      .group_by { |game| [ game.week, game.round_name ] }
      .sort_by { |(week, round_name), _games| [ week, round_name == Game::CHAMPIONSHIP ? 1 : 0 ] }
  end
end
