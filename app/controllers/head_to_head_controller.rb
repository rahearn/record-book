class HeadToHeadController < ApplicationController
  def show
    @almanac = Almanac.new
    return if @almanac.empty?

    @owner_a = find_owner(params[:a]) { @almanac.current_standings.first.owner }
    @owner_b = find_owner(params[:b]) { @almanac.current_standings.second.owner }
    @career_a = career_for!(@owner_a)
    @career_b = career_for!(@owner_b)
    @series = @almanac.series_between(@owner_a, @owner_b)
  end

  private

  def find_owner(id)
    id ? Owner.find(id) : yield
  end

  def career_for!(owner)
    @almanac.career_for(owner) ||
      raise(ActiveRecord::RecordNotFound, "No games on record for #{owner.name}")
  end
end
