# The record book's long view: every season, every score, and every player
# on record, each table sortable by its columns across all the years.
class HistoryController < ApplicationController
  VIEWS = %w[seasons games players].freeze
  PLAYER_SCOPES = %w[career season game].freeze
  # Score and player tables run to thousands of rows; they show the top of
  # whatever they are sorted by.
  LIMIT = 50

  SEASON_SORTS = {
    "year" => ->(record) { record.year },
    "finish" => ->(record) { record.final_rank },
    "win_pct" => ->(record) { record.win_percentage },
    "pf" => ->(record) { record.points_for },
    "pa" => ->(record) { record.points_against },
    "pfg" => ->(record) { record.average_points },
    "pag" => ->(record) { record.average_points_against },
    "xw" => ->(record) { record.expected_wins },
    "luck" => ->(record) { record.all_play_luck },
    "high" => ->(record) { record.highest_score },
    "low" => ->(record) { record.lowest_score }
  }.freeze

  GAME_SORTS = {
    "points" => ->(line) { line.points },
    "opp_points" => ->(line) { line.opponent_points },
    "margin" => ->(line) { line.margin },
    "combined" => ->(line) { line.combined },
    "all_play" => ->(line) { line.all_play.expected_wins },
    "vs_avg" => ->(line) { line.versus_average }
  }.freeze

  # Columns that read best smallest-first open ascending.
  ASCENDING = %w[finish].freeze

  def show
    @view = params[:view].presence_in(VIEWS) || "seasons"
    @almanac = Almanac.new
    return if @almanac.empty?

    @owner = Owner.find(params[:owner]) if params[:owner].present?
    send(:"show_#{@view}")
  end

  private

  def show_seasons
    choose_sort(SEASON_SORTS.keys, default: "pfg")
    records = @almanac.season_history
    records = records.select { |record| record.owner == @owner } if @owner
    @season_records = sorted(records, SEASON_SORTS.fetch(@sort)) { |record| [ -record.year, record.owner.name ] }
  end

  def show_games
    choose_sort(GAME_SORTS.keys, default: "points")
    lines = @almanac.game_history
    lines = lines.select { |line| line.owner == @owner } if @owner
    # A game's combined score is the same from either side, so it is listed once.
    lines = lines.group_by(&:game).map { |_game, sides| sides.max_by(&:points) } if @sort == "combined"
    @game_total = lines.size
    @game_lines = sorted(lines, GAME_SORTS.fetch(@sort)) { |line| [ -line.year, -line.week, line.owner.name ] }
      .first(LIMIT)
  end

  def show_players
    @player_scope = params[:by].presence_in(PLAYER_SCOPES) || "career"
    @position = params[:position].presence_in(LineupSlot::ANY_POSITION)
    @ledger = PlayerLedger.new(owner: @owner, position: @position)
    if @player_scope == "game"
      choose_sort(%w[points], default: "points")
      @player_starts = @ledger.games(direction: @direction, limit: LIMIT)
      @player_total = @ledger.game_count
    else
      scope = @player_scope.to_sym
      choose_sort(PlayerLedger::SORTS.keys, default: "points")
      @player_lines = @ledger.lines(scope, sort: @sort, direction: @direction, limit: LIMIT)
      @player_total = @ledger.count(scope, sort: @sort)
    end
  end

  def choose_sort(columns, default:)
    @sort = params[:sort].presence_in(columns) || default
    @direction = params[:direction].presence_in(%w[asc desc]) ||
      (ASCENDING.include?(@sort) ? "asc" : "desc")
  end

  # Rows reordered by the chosen column, the tiebreak settling the rest.
  def sorted(rows, value, &tiebreak)
    rows.sort_by do |row|
      [ @direction == "asc" ? value.call(row) : -value.call(row), *tiebreak.call(row) ]
    end
  end
end
