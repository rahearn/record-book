# Aggregates every recorded game into the derived views the record book
# presents: per-season standings, all-time career records, single-game
# extremes, and the promotion/relegation ladder for the upcoming season.
#
# All statistics cover regular-season games only, and "luck" is the average
# number of points an opponent scored below (+) or above (−) their own
# season average.
class Almanac
  PROMOTION_COUNT = 4
  RELEGATION_COUNT = 4

  HeadToHead = Data.define(:opponent, :wins, :losses, :ties)
  ScoreRecord = Data.define(:points, :owner, :year, :week)
  BlowoutRecord = Data.define(:margin, :winner, :loser, :year, :week)
  ShootoutRecord = Data.define(:total, :owners, :year, :week)
  GameRecords = Data.define(:highest_score, :lowest_score, :biggest_blowout, :highest_combined)

  attr_reader :promotion_count, :relegation_count

  def initialize(games: Game.includes(:season, performances: :owner).to_a,
                 promotion_count: PROMOTION_COUNT, relegation_count: RELEGATION_COUNT)
    @games = games.select { |game| game.performances.size == 2 }
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

  def standings_for(year, tier)
    season_records.values
      .select { |record| record.year == year && record.tier == tier.to_s }
      .sort_by(&:rank)
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
      CareerRecord.new(owner: owner, season_records: records, next_tier: ladder&.tier_for(owner))
    end.sort_by { |career| [ -career.win_percentage, -career.points_for ] }
      .each_with_index { |career, index| career.rank = index + 1 }
  end

  def career_for(owner)
    all_time_standings.find { |career| career.owner == owner }
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

  def game_records
    return if empty?

    @game_records ||= build_game_records
  end

  def ladder
    @ladder ||= build_ladder
  end

  private

  def season_records
    @season_records ||= build_season_records
  end

  def build_season_records
    records = {}
    each_matchup do |game, side_a, side_b|
      record_for(records, game, side_a.owner).record_result(
        week: game.week, points: side_a.points,
        opponent: side_b.owner, opponent_points: side_b.points)
      record_for(records, game, side_b.owner).record_result(
        week: game.week, points: side_b.points,
        opponent: side_a.owner, opponent_points: side_a.points)
    end
    each_matchup do |game, side_a, side_b|
      year = game.season.year
      records[[ year, side_a.owner ]].add_luck(records[[ year, side_b.owner ]].average_points - side_b.points)
      records[[ year, side_b.owner ]].add_luck(records[[ year, side_a.owner ]].average_points - side_a.points)
    end
    rank_by_season(records.values)
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

  def each_matchup
    @games.each do |game|
      side_a, side_b = game.performances.to_a
      yield game, side_a, side_b
    end
  end

  def build_game_records
    highest = lowest = blowout = shootout = nil
    each_matchup do |game, side_a, side_b|
      year = game.season.year
      week = game.week
      [ side_a, side_b ].each do |side|
        if highest.nil? || side.points > highest.points
          highest = ScoreRecord.new(points: side.points, owner: side.owner, year:, week:)
        end
        if lowest.nil? || side.points < lowest.points
          lowest = ScoreRecord.new(points: side.points, owner: side.owner, year:, week:)
        end
      end
      margin = (side_a.points - side_b.points).abs
      if blowout.nil? || margin > blowout.margin
        winner, loser = side_a.points >= side_b.points ? [ side_a, side_b ] : [ side_b, side_a ]
        blowout = BlowoutRecord.new(margin:, winner: winner.owner, loser: loser.owner, year:, week:)
      end
      total = side_a.points + side_b.points
      if shootout.nil? || total > shootout.total
        shootout = ShootoutRecord.new(total:, owners: [ side_a.owner, side_b.owner ], year:, week:)
      end
    end
    GameRecords.new(highest_score: highest, lowest_score: lowest,
                    biggest_blowout: blowout, highest_combined: shootout)
  end

  def build_ladder
    return if empty?

    premier = standings_for(latest_year, :premier).map(&:owner)
    challenger = standings_for(latest_year, :challenger).map(&:owner)
    return if premier.empty? || challenger.empty?

    Ladder.new(year: latest_year + 1, premier_owners: premier, challenger_owners: challenger,
               promotion_count:, relegation_count:)
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
