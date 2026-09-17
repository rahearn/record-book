class SeasonsController < ApplicationController
  SORTS = {
    "rank" => ->(record) { record.final_rank },
    "win_pct" => ->(record) { record.win_percentage },
    "pf" => ->(record) { record.points_for },
    "pa" => ->(record) { record.points_against },
    "pfg" => ->(record) { record.average_points },
    "pag" => ->(record) { record.average_points_against },
    "xw" => ->(record) { record.expected_wins },
    "luck" => ->(record) { record.all_play_luck },
    "opp" => ->(record) { record.opponent_shortfall_per_game },
    "high" => ->(record) { record.highest_score },
    "low" => ->(record) { record.lowest_score }
  }.freeze

  def show
    @almanac = Almanac.new
    return if @almanac.empty?

    @year = (params[:year] || @almanac.latest_year).to_i
    unless @almanac.years.include?(@year)
      raise ActiveRecord::RecordNotFound, "No #{@year} season on record"
    end

    @split = @almanac.split_season?(@year)
    @tier = @split ? requested_tier : :unified
    @sort = SORTS.key?(params[:sort]) ? params[:sort] : "rank"
    @direction = params[:direction].presence_in(%w[asc desc]) || (@sort == "rank" ? "asc" : "desc")
    @standings = sorted_standings
    @matrix = @almanac.week_matrix(@year, @tier)

    season = Season.find_by(year: @year)
    @playoff_format = season&.playoff_format_for(@tier)
    @playoff_rounds = playoff_rounds(season)
  end

  private

  # Final standings reordered by the chosen column, finish breaking ties.
  def sorted_standings
    value = SORTS.fetch(@sort)
    @almanac.final_standings_for(@year, @tier).sort_by do |record|
      [ @direction == "asc" ? value.call(record) : -value.call(record), record.final_rank ]
    end
  end

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
