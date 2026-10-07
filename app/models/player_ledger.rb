# Every player who has filled an owner's lineup, totalled across the
# lineups on record. There is deliberately no Player model (see
# LineupSlot), so a player here is a name at a primary position: the NFL
# team moves too often to be part of who someone is, and two same-named
# players at one position are counted as one.
#
# Like the rest of the record book's statistics, only regular-season games
# count. Lineups run to tens of thousands of slots, so the totals are
# worked out in the database rather than in memory the way Almanac's are.
class PlayerLedger
  Line = Data.define(:name, :position, :nfl_team, :year, :starts, :points, :best,
                     :bench_points, :owner_count, :first_year, :last_year) do
    def points_per_start
      points / starts if starts.positive?
    end
  end

  SCOPES = %i[career season].freeze

  # The column each sort orders by, as the totals query names it.
  SORTS = {
    "points" => "points", "starts" => "starts", "ppg" => "points_per_start",
    "best" => "best", "bench" => "bench_points", "owners" => "owner_count"
  }.freeze

  # A points-per-start leader has to have started often enough to mean it.
  QUALIFYING_STARTS = { career: 10, season: 4 }.freeze

  STARTED = "lineup_slots.slot NOT IN " \
    "(#{LineupSlot.slots.values_at(*LineupSlot::RESERVE_SLOTS).join(', ')})".freeze
  BENCHED = "lineup_slots.slot = #{LineupSlot.slots.fetch('bench')}".freeze
  # The position a player mostly plays is the first one listed.
  POSITION = "lineup_slots.player_positions[1]".freeze

  def initialize(owner: nil, position: nil)
    @owner = owner
    @position = position
  end

  # One line per player over every season (:career), or per player and
  # season (:season), ordered by one of SORTS.
  def lines(scope, sort: "points", direction: "desc", limit: nil)
    totals(scope, sort)
      .order(Arel.sql("#{SORTS.fetch(sort)} #{direction == 'asc' ? 'ASC' : 'DESC'} NULLS LAST, name, year DESC"))
      .limit(limit)
      .map { |row| Line.new(**Line.members.index_with { |member| row[member] }) }
  end

  # How many lines a scope holds under a sort, before any limit.
  def count(scope, sort: "points")
    LineupSlot.from(totals(scope, sort), :players).count
  end

  # Single starts, best (or worst) first, with the game they were made in.
  def games(direction: "desc", limit: nil)
    starts.preload(performance: [ :owner, { game: :season } ])
      .order(Arel.sql("lineup_slots.points #{direction == 'asc' ? 'ASC' : 'DESC'}, " \
                      "seasons.year DESC, games.week DESC, lineup_slots.player_name"))
      .limit(limit)
  end

  def game_count
    starts.count
  end

  # The first season with a lineup on record.
  def first_year
    slots.minimum("seasons.year")
  end

  def empty?
    !starts.exists?
  end

  private

  def slots
    scope = LineupSlot.joins(performance: { game: :season }).merge(Game.regular_season)
    scope = scope.where(performances: { owner_id: @owner.id }) if @owner
    scope = scope.where("#{POSITION} = ?", @position) if @position
    scope
  end

  def starts
    slots.where(STARTED)
  end

  def totals(scope, sort)
    raise ArgumentError, "unknown scope #{scope}" unless SCOPES.include?(scope)

    by_season = scope == :season
    groups = [ "lineup_slots.player_name", POSITION ]
    groups << "seasons.year" if by_season
    started_points = "COALESCE(SUM(lineup_slots.points) FILTER (WHERE #{STARTED}), 0)"
    start_count = "COUNT(*) FILTER (WHERE #{STARTED})"
    slots.group(*groups)
      .having("#{start_count} >= ?", minimum_starts(scope, sort))
      .select(
        "lineup_slots.player_name AS name",
        "#{POSITION} AS position",
        "#{by_season ? 'seasons.year' : 'NULL::integer'} AS year",
        # The team a player is listed with is the one they last played for.
        "(ARRAY_AGG(lineup_slots.player_nfl_team ORDER BY seasons.year DESC, games.week DESC))[1] AS nfl_team",
        "#{start_count} AS starts",
        "#{started_points} AS points",
        "#{started_points} / NULLIF(#{start_count}, 0) AS points_per_start",
        "MAX(lineup_slots.points) FILTER (WHERE #{STARTED}) AS best",
        "COALESCE(SUM(lineup_slots.points) FILTER (WHERE #{BENCHED}), 0) AS bench_points",
        "COUNT(DISTINCT performances.owner_id) FILTER (WHERE #{STARTED}) AS owner_count",
        "MIN(seasons.year) AS first_year",
        "MAX(seasons.year) AS last_year")
  end

  # Every player who started at least once, except that a points-per-start
  # table counts only qualified starters, and a bench table takes in the
  # players who never got off it.
  def minimum_starts(scope, sort)
    case sort
    when "ppg" then QUALIFYING_STARTS.fetch(scope)
    when "bench" then 0
    else 1
    end
  end
end
