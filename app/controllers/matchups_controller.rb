class MatchupsController < ApplicationController
  def show
    @game = Game.includes(:season,
                          performances: [ { owner: { teams: :season } }, { lineup_slots: :player } ])
      .find(params[:id])
    unless @game.performances.size == 2
      raise ActiveRecord::RecordNotFound, "Game #{@game.id} has no opposing sides on record"
    end

    @almanac = Almanac.new
    @matchup = @almanac.matchup_for(@game, first_owner: first_owner)
  end

  private

  # The owner the visitor arrived from, shown on the left-hand side.
  def first_owner
    Owner.find_by(id: params[:owner]) if params[:owner]
  end
end
