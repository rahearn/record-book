class Almanac
  # Next season's tier assignments: the bottom of Premier swaps places with
  # the top of Challenger, based on the latest season's final standings.
  class Ladder
    Entry = Data.define(:owner, :movement)

    attr_reader :year, :premier, :challenger

    def initialize(year:, premier_owners:, challenger_owners:, promotion_count:, relegation_count:)
      relegated = premier_owners.last(relegation_count)
      promoted = challenger_owners.first(promotion_count)
      @year = year
      @premier = entries(premier_owners - relegated, :held) + entries(promoted, :promoted)
      @challenger = entries(relegated, :relegated) + entries(challenger_owners - promoted, :held)
    end

    def tier_for(owner)
      if premier.any? { |entry| entry.owner == owner }
        :premier
      elsif challenger.any? { |entry| entry.owner == owner }
        :challenger
      end
    end

    private

    def entries(owners, movement)
      owners.map { |owner| Entry.new(owner: owner, movement: movement) }
    end
  end
end
