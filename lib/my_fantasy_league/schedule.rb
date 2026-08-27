module MyFantasyLeague
  # The games a season was played over, gathered from the two places MFL
  # keeps them.
  #
  # The regular season comes off the league schedule, where a matchup is
  # always between two franchises of the same division and the division is
  # what says which tier it belongs to. The playoffs come off the brackets
  # instead: the schedule lists a playoff week's games without saying which
  # bracket they were played in, and the record book wants the championship
  # bracket and the game for third place, not a consolation round.
  #
  # MFL names no round, only a week, so the rounds are counted back from the
  # final — a final, a semifinal before it, a quarterfinal before that. Where
  # the final falls is worked out from the size of the bracket rather than
  # from the rounds played so far, so a season part-way through its playoffs
  # does not mistake a semifinal for a final.
  class Schedule
    Error = Class.new(StandardError)

    Side = Data.define(:franchise_id, :points)
    Matchup = Data.define(:week, :tier, :round_name, :sides)
    PlayoffFormat = Data.define(:tier, :start_week, :team_count)

    ROUNDS_BACK_FROM_THE_FINAL = [ Game::CHAMPIONSHIP, Game::SEMIFINAL, "Quarterfinal" ].freeze

    def self.load(client:, season:)
      new(client: client, season: season)
    end

    def initialize(client:, season:)
      @client = client
      @season = season
    end

    # Every game on record, regular season and playoffs alike, in week order.
    def matchups
      @matchups ||= (regular_season + playoffs).sort_by { |matchup| [ matchup.week, matchup.tier ] }
    end

    # The playoffs each tier configured, for the record book to hold its own
    # games to. A tier whose brackets have not been set up yet has none.
    def playoff_formats
      @playoff_formats ||= @season.tiers.values.filter_map do |tier|
        bracket = championship_bracket(tier) or next

        PlayoffFormat.new(tier: tier.name, start_week: bracket.fetch("startWeek").to_i,
                          team_count: bracket.fetch("teamsInvolved").to_i)
      end
    end

    # Which tier a franchise played in, by the division MFL has it in.
    def tier_for(franchise_id)
      divisions[franchise_id]
    end

    def franchise_names
      @franchise_names ||= franchises.to_h { |franchise| [ franchise["id"], franchise["name"] ] }
    end

    private

    def league
      @league ||= @client.league
    end

    def franchises
      Array.wrap(league.dig("franchises", "franchise"))
    end

    def divisions
      @divisions ||= franchises.to_h do |franchise|
        [ franchise["id"], @season.tier_for_division(franchise["division"].to_s)&.name ]
      end
    end

    # The week each tier's playoffs begin, and so the week its regular season
    # stops. A tier with no brackets configured yet plays on until MFL's own
    # last regular-season week.
    def playoff_start_weeks
      @playoff_start_weeks ||= @season.tiers.keys.index_with do |name|
        playoff_formats.find { |format| format.tier == name }&.start_week ||
          league["lastRegularSeasonWeek"].to_i + 1
      end
    end

    def regular_season
      @client.schedule.flat_map do |week|
        number = week.fetch("week").to_i
        Array.wrap(week["matchup"]).filter_map do |matchup|
          sides = Array.wrap(matchup["franchise"]).map do |franchise|
            Side.new(franchise_id: franchise["id"], points: franchise["score"])
          end
          tier = tier_for_sides(sides)
          next unless tier && number < playoff_start_weeks.fetch(tier)

          Matchup.new(week: number, tier: tier, round_name: nil, sides: sides) if played?(sides)
        end
      end
    end

    # Both sides of a matchup belong to the same division, so either one
    # settles the tier — but a franchise in no configured division, or a
    # cross-division exhibition, belongs to no tier and is left out.
    def tier_for_sides(sides)
      tiers = sides.map { |side| tier_for(side.franchise_id) }.uniq
      tiers.first if sides.size == 2 && tiers.size == 1 && tiers.first
    end

    def played?(sides)
      sides.all? { |side| side.points.present? }
    end

    def playoffs
      @season.tiers.values.flat_map do |tier|
        championship_rounds(tier) + third_place_round(tier)
      end
    end

    def brackets
      @brackets ||= @client.playoff_brackets.index_by { |bracket| bracket["id"].to_s }
    end

    def championship_bracket(tier)
      id = tier.playoffs&.bracket or return
      brackets[id] or raise Error, "#{@season.year} #{tier.name} names bracket #{id}, which MFL does not have"
    end

    def championship_rounds(tier)
      bracket = championship_bracket(tier) or return []
      format = playoff_formats.find { |other| other.tier == tier.name }
      final = format.start_week + rounds_in(format.team_count) - 1

      @client.playoff_bracket(bracket["id"]).flat_map do |round|
        week = round.fetch("week").to_i
        games(round).map do |sides|
          Matchup.new(week: week, tier: tier.name, round_name: round_name(final - week, format), sides: sides)
        end
      end
    end

    # A game for third place is a bracket of its own, played the same week as
    # the final it follows from — one game, and never anything else.
    def third_place_round(tier)
      id = tier.playoffs&.third_place or return []
      raise Error, "#{@season.year} #{tier.name} names bracket #{id}, which MFL does not have" unless brackets[id]

      @client.playoff_bracket(id).flat_map do |round|
        games(round).map do |sides|
          Matchup.new(week: round.fetch("week").to_i, tier: tier.name,
                      round_name: Game::THIRD_PLACE, sides: sides)
        end
      end
    end

    def games(round)
      Array.wrap(round["playoffGame"]).filter_map do |game|
        sides = [ game["away"], game["home"] ].compact.map do |side|
          Side.new(franchise_id: side["franchise_id"], points: side["points"])
        end
        sides if sides.size == 2 && played?(sides)
      end
    end

    # How many rounds a bracket of this many teams takes, byes included: six
    # teams play three, four teams play two.
    def rounds_in(team_count)
      Math.log2(team_count).ceil
    end

    # A bracket that runs longer than its size suggests numbers its earlier
    # weeks rather than guess at them.
    def round_name(rounds_back, format)
      named = ROUNDS_BACK_FROM_THE_FINAL[rounds_back] if rounds_back >= 0
      named || "Round #{rounds_in(format.team_count) - rounds_back}"
    end
  end
end
