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

  def all_time_standings
    @all_time_standings ||= season_records.values.group_by(&:owner).map do |owner, records|
      CareerRecord.new(owner: owner, season_records: records, next_tier: ladder&.tier_for(owner))
    end.sort_by { |career| [ -career.win_percentage, -career.points_for ] }
      .each_with_index { |career, index| career.rank = index + 1 }
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
      record_for(records, game, side_a.owner).record_result(side_a.points, side_b.points)
      record_for(records, game, side_b.owner).record_result(side_b.points, side_a.points)
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
end
