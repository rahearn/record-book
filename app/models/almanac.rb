# Aggregates every recorded game into the derived views the record book
# presents: per-season standings, all-time career records, single-game
# extremes, and the promotion/relegation ladder for the upcoming season.
#
# All statistics cover regular-season games only, and "luck" is the average
# number of points an opponent scored below (+) or above (−) their own
# season average. The exception is titles, which count playoff
# championships won in the unified league or the Premier tier.
class Almanac
  PROMOTION_COUNT = 4
  RELEGATION_COUNT = 4

  HeadToHead = Data.define(:opponent, :wins, :losses, :ties)

  # Every single-game record keeps the game it was set in, so the record
  # book can date it and link back to the matchup.
  module SetInGame
    def year
      game.season.year
    end

    def week
      game.week
    end
  end

  ScoreRecord = Data.define(:points, :owner, :game) { include SetInGame }
  BlowoutRecord = Data.define(:margin, :winner, :loser, :game) { include SetInGame }
  ShootoutRecord = Data.define(:total, :owners, :game) { include SetInGame }
  GameRecords = Data.define(:highest_score, :lowest_score, :biggest_blowout, :highest_combined)

  attr_reader :promotion_count, :relegation_count

  def initialize(games: Game.includes(:season, performances: { owner: { teams: :season } }).to_a,
                 promotion_count: PROMOTION_COUNT, relegation_count: RELEGATION_COUNT)
    playable = games.select { |game| game.performances.size == 2 }
    @games = playable.select(&:regular_season?)
    @playoff_games = playable.select(&:playoff?)
    @promotion_count = promotion_count
    @relegation_count = relegation_count
  end

  def empty?
    @games.empty?
  end

  def game_count
    @games.size
  end

  def years
    @years ||= @games.map { |game| game.season.year }.uniq.sort
  end

  def season_count
    years.size
  end

  def first_year
    years.first
  end

  def latest_year
    years.last
  end

  def weeks_per_season
    @games.map(&:week).max
  end

  def owner_count
    all_owners.size
  end

  # Owners who played in both the first and the most recent season.
  def founders_remaining
    return 0 if empty?

    (owners_in_year(first_year) & owners_in_year(latest_year)).size
  end

  # The first year the league split into promotion/relegation tiers, or nil.
  def tiered_since
    @games.reject(&:unified?).map { |game| game.season.year }.min
  end

  # Regular-season standings: wins, then points for. This is the order
  # relegation and the zone shading are judged on.
  def standings_for(year, tier)
    season_records.values
      .select { |record| record.year == year && record.tier == tier.to_s }
      .sort_by(&:rank)
  end

  # The season as it finished: the playoff finishers take the top spots,
  # everyone else follows in regular-season order.
  def final_standings_for(year, tier)
    standings_for(year, tier).sort_by(&:final_rank)
  end

  # Whether the given season was played in Premier/Challenger tiers.
  def split_season?(year)
    tiers = tiers_in(year)
    tiers.include?("premier") && tiers.include?("challenger")
  end

  # Bottom of Premier: drops to Challenger next season.
  def relegation_zone?(record)
    record.tier == "premier" && split_season?(record.year) &&
      record.rank > standings_for(record.year, :premier).size - relegation_count
  end

  # Top of Challenger: rises to Premier next season.
  def promotion_zone?(record)
    record.tier == "challenger" && split_season?(record.year) &&
      record.rank <= promotion_count
  end

  def week_matrix(year, tier)
    WeekMatrix.new(records: standings_for(year, tier))
  end

  def all_time_standings
    @all_time_standings ||= season_records.values.group_by(&:owner).map do |owner, records|
      CareerRecord.new(owner: owner, season_records: records, next_tier: ladder&.tier_for(owner),
                       titles: championship_counts[owner] || 0)
    end.sort_by { |career| [ -career.win_percentage, -career.points_for ] }
      .each_with_index { |career, index| career.rank = index + 1 }
  end

  def career_for(owner)
    all_time_standings.find { |career| career.owner == owner }
  end

  # All-time standings restricted to owners who fielded a team in the most
  # recent season: the league page's "Current" scope, and the pool the
  # owner and head-to-head pages default into.
  def current_standings
    all_time_standings.select { |career| career.owner.current_in?(latest_year) }
  end

  # League position by career points for per game (1 = highest scoring).
  def points_for_rank(career)
    all_time_standings.sort_by { |other| -other.points_for_per_game }.index(career) + 1
  end

  # League position by career points against per game (1 = stingiest schedule).
  def points_against_rank(career)
    all_time_standings.sort_by(&:points_against_per_game).index(career) + 1
  end

  # All-time record against every opponent faced, best series first.
  def head_to_head_for(owner)
    totals = Hash.new { |hash, opponent| hash[opponent] = { wins: 0, losses: 0, ties: 0 } }
    each_matchup do |_game, side_a, side_b|
      mine, theirs = if side_a.owner == owner
        [ side_a, side_b ]
      elsif side_b.owner == owner
        [ side_b, side_a ]
      end
      next unless mine

      tally = totals[theirs.owner]
      if mine.points > theirs.points
        tally[:wins] += 1
      elsif mine.points < theirs.points
        tally[:losses] += 1
      else
        tally[:ties] += 1
      end
    end
    totals.map { |opponent, tally| HeadToHead.new(opponent: opponent, **tally) }
      .sort_by { |series| [ -(series.wins - series.losses), series.opponent.name ] }
  end

  def series_between(owner_a, owner_b)
    meetings = []
    if owner_a != owner_b
      each_matchup do |game, side_a, side_b|
        sides = { side_a.owner => side_a, side_b.owner => side_b }
        mine = sides[owner_a]
        theirs = sides[owner_b]
        next unless mine && theirs

        meetings << Series::Meeting.new(game: game, points_a: mine.points, points_b: theirs.points)
      end
    end
    Series.new(owner_a: owner_a, owner_b: owner_b, meetings: meetings)
  end

  # One game with both owners' seasons attached. When first_owner is given
  # and played in the game, that owner takes the left-hand side.
  def matchup_for(game, first_owner: nil)
    sides = game.performances.map { |performance| matchup_side(game, performance) }
    sides.reverse! if first_owner && sides.last.owner == first_owner
    Matchup.new(game: game, side_a: sides.first, side_b: sides.last)
  end

  # Every matchup of one week, playoffs included — the scoreboard is a
  # record of what was played, not a regular-season statistic.
  def scoreboard_for(year, week, tier)
    games = games_in(year, tier).select { |game| game.week == week }
    Scoreboard.new(year: year, week: week, tier: tier.to_s,
                   matchups: games.map { |game| matchup_for(game) })
  end

  # The weeks a season and tier have games on record for, in order.
  def weeks_in(year, tier)
    games_in(year, tier).map(&:week).uniq.sort
  end

  def playoff_history_for(owner)
    (@playoff_histories ||= {})[owner] ||= build_playoff_history(owner)
  end

  def game_records
    return if empty?

    @game_records ||= build_game_records
  end

  def ladder
    @ladder ||= build_ladder
  end

  private

  def games_in(year, tier)
    (@games + @playoff_games).select do |game|
      game.season.year == year && game.tier == tier.to_s
    end
  end

  def matchup_side(game, performance)
    Matchup::Side.new(performance: performance,
                      season_record: season_records[[ game.season.year, performance.owner ]])
  end

  def season_records
    @season_records ||= build_season_records
  end

  def build_season_records
    records = {}
    each_matchup do |game, side_a, side_b|
      record_for(records, game, side_a.owner).record_result(
        game: game, points: side_a.points,
        opponent: side_b.owner, opponent_points: side_b.points)
      record_for(records, game, side_b.owner).record_result(
        game: game, points: side_b.points,
        opponent: side_a.owner, opponent_points: side_a.points)
    end
    each_matchup do |game, side_a, side_b|
      year = game.season.year
      records[[ year, side_a.owner ]].add_luck(records[[ year, side_b.owner ]].average_points - side_b.points)
      records[[ year, side_b.owner ]].add_luck(records[[ year, side_a.owner ]].average_points - side_a.points)
    end
    rank_by_season(records.values)
    assign_final_ranks(records.values)
    records
  end

  def record_for(records, game, owner)
    records[[ game.season.year, owner ]] ||=
      SeasonRecord.new(owner: owner, year: game.season.year, tier: game.tier)
  end

  def rank_by_season(records)
    records.group_by { |record| [ record.year, record.tier ] }.each_value do |group|
      group.sort_by { |record| [ -record.wins, -record.points_for ] }
        .each_with_index { |record, index| record.rank = index + 1 }
    end
  end

  def assign_final_ranks(records)
    records.group_by { |record| [ record.year, record.tier ] }.each do |(year, tier), group|
      by_owner = group.index_by(&:owner)
      playoff_top = playoff_finishers(year, tier).filter_map { |owner| by_owner[owner] }
      rest = group.sort_by(&:rank) - playoff_top
      (playoff_top + rest).each_with_index { |record, index| record.final_rank = index + 1 }
    end
  end

  def each_matchup
    @games.each do |game|
      side_a, side_b = game.performances.to_a
      yield game, side_a, side_b
    end
  end

  def build_game_records
    highest = lowest = blowout = shootout = nil
    each_matchup do |game, side_a, side_b|
      [ side_a, side_b ].each do |side|
        if highest.nil? || side.points > highest.points
          highest = ScoreRecord.new(points: side.points, owner: side.owner, game:)
        end
        if lowest.nil? || side.points < lowest.points
          lowest = ScoreRecord.new(points: side.points, owner: side.owner, game:)
        end
      end
      margin = (side_a.points - side_b.points).abs
      if blowout.nil? || margin > blowout.margin
        winner, loser = side_a.points >= side_b.points ? [ side_a, side_b ] : [ side_b, side_a ]
        blowout = BlowoutRecord.new(margin:, winner: winner.owner, loser: loser.owner, game:)
      end
      total = side_a.points + side_b.points
      if shootout.nil? || total > shootout.total
        shootout = ShootoutRecord.new(total:, owners: [ side_a.owner, side_b.owner ], game:)
      end
    end
    GameRecords.new(highest_score: highest, lowest_score: lowest,
                    biggest_blowout: blowout, highest_combined: shootout)
  end

  def build_ladder
    return if empty?

    premier = standings_for(latest_year, :premier).map(&:owner)
    challenger = standings_for(latest_year, :challenger)
    return if premier.empty? || challenger.empty?

    Ladder.new(year: latest_year + 1,
               premier_owners: premier, challenger_owners: challenger.map(&:owner),
               promoted: promoted_owners(challenger), relegated: premier.last(relegation_count))
  end

  # Titles per owner: playoff championships won in the unified league or the
  # Premier tier. A season/tier with anything other than exactly one
  # Championship-round game, or a tied final, crowns no one.
  def championship_counts
    @championship_counts ||= @playoff_games.reject(&:challenger?)
      .select(&:championship?)
      .group_by { |game| [ game.season.year, game.tier ] }
      .filter_map { |_season_tier, finals| decisive_winner(finals) }
      .tally
  end

  def decisive_winner(finals)
    return unless finals.size == 1

    winner, runner_up = finals.first.performances.sort_by { |performance| -performance.points }
    winner.owner unless winner.points == runner_up.points
  end

  # Playoff finishing order for a season/tier: championship winner and
  # loser, then third-place game winner and loser. Rounds that are absent
  # or ambiguous contribute nothing.
  def playoff_finishers(year, tier)
    games = @playoff_games.select { |game| game.season.year == year && game.tier == tier.to_s }
    [ games.select(&:championship?), games.select(&:third_place?) ].flat_map do |round|
      next [] unless round.size == 1

      round.first.performances.sort_by { |performance| -performance.points }.map(&:owner)
    end
  end

  # Promotion: the challenger regular-season points leader, then the top
  # playoff finishers, with standings order filling any gap left by
  # missing playoff data.
  def promoted_owners(challenger_records)
    leader = challenger_records.max_by(&:points_for).owner
    candidates = [ leader ] +
      (playoff_finishers(latest_year, :challenger) - [ leader ]) +
      (challenger_records.map(&:owner) - [ leader ])
    candidates.uniq.first(promotion_count)
  end

  def build_playoff_history(owner)
    results = @playoff_games.reject(&:challenger?).filter_map do |game|
      mine = game.performances.detect { |performance| performance.owner == owner }
      next unless mine

      theirs = (game.performances - [ mine ]).first
      PlayoffHistory::Result.new(year: game.season.year, round_name: game.round_name,
                                 won: mine.points > theirs.points,
                                 tied: mine.points == theirs.points)
    end
    appearance_years = results.map(&:year).uniq
    season_flags = (career_for(owner)&.season_records || []).map do |record|
      record.tier != "challenger" && appearance_years.include?(record.year)
    end
    PlayoffHistory.new(season_flags: season_flags, results: results)
  end

  def all_owners
    @all_owners ||= @games.flat_map { |game| game.performances.map(&:owner) }.uniq
  end

  def owners_in_year(year)
    @games.select { |game| game.season.year == year }
      .flat_map { |game| game.performances.map(&:owner) }.uniq
  end

  def tiers_in(year)
    @games.select { |game| game.season.year == year }.map(&:tier).uniq
  end
end
