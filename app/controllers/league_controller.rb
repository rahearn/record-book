class LeagueController < ApplicationController
  def show
    @almanac = Almanac.new
  end
end
