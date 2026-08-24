class Almanac
  # Next season's tier assignments. Relegation takes the bottom of the
  # Premier standings; promotion takes the Challenger points leader plus the
  # top playoff finishers (see Almanac#promoted_owners).
  class Ladder
    Entry = Data.define(:owner, :movement)

    attr_reader :year, :premier, :challenger

    def initialize(year:, premier_owners:, challenger_owners:, promoted:, relegated:)
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
