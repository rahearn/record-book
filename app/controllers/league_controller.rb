class LeagueController < ApplicationController
  SORTS = {
    "win_pct" => ->(career) { career.win_percentage },
    "pfg" => ->(career) { career.points_for_per_game },
    "pag" => ->(career) { career.points_against_per_game },
    "titles" => ->(career) { career.titles },
    "runner_up" => nil # needs the almanac; see sorted_standings
  }.freeze

  def show
    @almanac = Almanac.new
    @sort = SORTS.key?(params[:sort]) ? params[:sort] : "win_pct"
    @direction = params[:direction] == "asc" ? "asc" : "desc"
    @scope = params[:scope] == "all" ? "all" : "current"
    @standings = sorted_standings
  end

  private

  def sorted_standings
    value = SORTS[@sort] ||
      ->(career) { @almanac.playoff_history_for(career.owner).runner_up_finishes }
    standings = @almanac.all_time_standings
    standings = standings.select { |career| career.owner.current_in?(@almanac.latest_year) } if @scope == "current"
    standings.sort_by do |career|
      [ @direction == "asc" ? value.call(career) : -value.call(career), career.rank ]
    end
  end
end
