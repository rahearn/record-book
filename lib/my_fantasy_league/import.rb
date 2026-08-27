module MyFantasyLeague
  # One season on MyFantasyLeague, written into the record book.
  #
  # An import is safe to run again over a week it has already loaded: MFL's
  # scores move for days after a week is played, and sometimes long after,
  # when a stat correction lands. So a week is reconciled rather than
  # appended. A game is recognised by the two owners who played it, which is
  # the one thing about a matchup that cannot be adjusted, and its scores and
  # lineups are brought back into line with what MFL now says. A game the
  # record book has for a week that MFL no longer does is dropped.
  #
  # Lineups are rewritten whole rather than slot by slot. A player moving
  # from the bench into the flex would otherwise collide with the sequence
  # they are moving out of, and there is nothing in a lineup worth preserving
  # across a re-import anyway.
  class Import
    Error = Class.new(StandardError)

    # MFL records that a player started, not the slot they filled.
    STARTER = "starter".freeze

    def initialize(year:, config: Configuration.load, client: nil, report: nil)
      @year = year
      @config = config
      @season = config.season(year)
      @client = client || Client.new(year: year, league_id: @season.league_id,
                                     user_agent: config.user_agent)
      @report = report || ->(line) { puts line }
    end

    # Imports one week, or every week on record when none is named, for one
    # tier or for all of them.
    def call(week: nil, tiers: nil)
      wanted = Array(tiers.presence || @season.tiers.keys).map(&:to_s)
      unknown = wanted - @season.tiers.keys
      raise Error, "#{@year} has no #{unknown.to_sentence} tier" if unknown.any?

      ActiveRecord::Base.transaction do
        prepare_season
        lineups = load_lineups(week)
        selected(week, wanted).each do |(tier, number), matchups|
          store(tier, number, matchups, lineups.fetch(number, {}))
        end
      end
    end

    private

    def schedule
      @schedule ||= Schedule.load(client: @client, season: @season)
    end

    def selected(week, tiers)
      schedule.matchups
        .select { |matchup| tiers.include?(matchup.tier) && (week.nil? || matchup.week == week) }
        .group_by { |matchup| [ matchup.tier, matchup.week ] }
        .sort_by { |(tier, number), _| [ number, tier ] }
    end

    # The season's shape has to be on record before its games are, because a
    # game from a playoff week is only valid once the record book knows the
    # playoffs started.
    def prepare_season
      @record = Season.find_or_create_by!(year: @year)
      RosterFormat.find_or_initialize_by(season: @record).update!(slots: @season.roster)
      schedule.playoff_formats.each do |format|
        ::PlayoffFormat.find_or_initialize_by(season: @record, tier: format.tier)
          .update!(start_week: format.start_week, team_count: format.team_count)
      end
      @record.reload
      record_teams
    end

    # The team each owner fielded this year, kept in step with MFL: owners
    # rename their teams mid-season as readily as between them.
    def record_teams
      schedule.franchise_names.each do |franchise_id, name|
        next unless schedule.tier_for(franchise_id)

        Team.find_or_initialize_by(owner: owner_for(franchise_id), season: @record).update!(name: name)
      end
    end

    # Every franchise that played in a tier the record book imports, matched
    # to the owner behind it. Nothing is invented here: a franchise nobody has
    # been put behind, or a name the record book does not already hold, stops
    # the import rather than quietly forking someone's history in two.
    def owners
      @owners ||= begin
        wanted = schedule.franchise_names.keys.select { |id| schedule.tier_for(id) }
          .index_with { |id| @season.owner_name(id) }
        unnamed = wanted.select { |_id, name| name.nil? }.keys
        raise Error, "#{Configuration::PATH} does not name the owner behind " \
                     "#{unnamed.to_sentence} in #{@year}" if unnamed.any?

        found = Owner.where(name: wanted.values.uniq).index_by(&:name)
        missing = wanted.values.uniq - found.keys
        raise Error, "the record book has no owner named #{missing.to_sentence}" if missing.any?

        wanted.transform_values { |name| found.fetch(name) }
      end
    end

    def owner_for(franchise_id)
      owners.fetch(franchise_id) do
        raise Error, "franchise #{franchise_id} played in no tier the record book imports"
      end
    end

    # A week's lineups, keyed by week and then franchise. Asking for the
    # whole season at once is a single request where asking week by week
    # would be seventeen.
    def load_lineups(week)
      weeks = @client.weekly_results(week: week)
      entries = weeks.to_h do |result|
        [ result.fetch("week").to_i, franchise_entries(result) ]
      end
      @players = PlayerDirectory.for(@client, entries.values.flat_map(&:values).flatten.map { |e| e["id"] })
      entries
    end

    def franchise_entries(result)
      Array.wrap(result["matchup"]).flat_map { |matchup| Array.wrap(matchup["franchise"]) }
        .to_h { |franchise| [ franchise["id"], Array.wrap(franchise["player"]) ] }
    end

    # Reconciles one week of one tier against what MFL now says it was.
    def store(tier, week, matchups, lineups)
      existing = @record.games.includes(performances: :owner).where(tier: tier, week: week).index_by do |game|
        game.performances.map(&:owner_id).sort
      end

      kept = matchups.map do |matchup|
        sides = matchup.sides.map { |side| [ owner_for(side.franchise_id), side ] }
        game = existing.delete(sides.map { |owner, _| owner.id }.sort)
        game ? revise(game, matchup, sides) : write(matchup, sides)
      end
      existing.each_value(&:destroy!)

      kept.each { |game| game.performances.each { |performance| record_lineup(performance, lineups) } }
      @report.call("#{@year} week #{week} #{tier}: #{kept.size} #{"game".pluralize(kept.size)}" \
                   "#{", #{existing.size} dropped" if existing.any?}")
    end

    def write(matchup, sides)
      @record.games.create!(week: matchup.week, tier: matchup.tier, round_name: matchup.round_name,
                            performances_attributes: sides.map do |owner, side|
                              { owner: owner, points: side.points }
                            end)
    end

    def revise(game, matchup, sides)
      by_owner = sides.to_h { |owner, side| [ owner.id, side ] }
      game.update!(round_name: matchup.round_name)
      game.performances.each do |performance|
        performance.update!(points: by_owner.fetch(performance.owner_id).points)
      end
      game
    end

    # Rewrites one owner's lineup for the week. Performances MFL has no
    # lineup for — a franchise that sat the week out — keep whatever is on
    # record rather than being emptied.
    def record_lineup(performance, lineups)
      entries = lineups[franchise_ids[performance.owner_id]]
      return if entries.blank?

      rows = lineup_rows(performance, entries)
      performance.lineup_slots.delete_all
      LineupSlot.insert_all!(rows) if rows.any?
    end

    def franchise_ids
      @franchise_ids ||= owners.to_h { |franchise_id, owner| [ owner.id, franchise_id ] }
    end

    # The week's roster laid out in the order the season's format reads: the
    # starting slots, then the bench. A starting slot nobody could fill is
    # skipped rather than left empty-handed, which is what frees its place up
    # for the deeper bench the record book allows in that case.
    def lineup_rows(performance, entries)
      format = @record.roster_format
      starters, reserves = entries.partition { |entry| entry["status"] == STARTER }
      guard_roster_size(performance, entries, format)

      seated = format.seat_starters(starters.map { |entry| @players.fetch(entry["id"]).positions })
      raise Error, "#{performance.display_name} started a lineup the #{@year} roster has no room for" if seated.nil?

      lineup = format.starting_slots.each_with_index.filter_map do |slot, index|
        [ slot, starters[seated[index]] ] if seated[index]
      end
      lineup += reserves.map { |entry| [ "bench", entry ] }
      lineup.each_with_index.map { |(slot, entry), spot| row(performance, slot, spot, entry) }
    end

    # A lineup deeper than the season was played with means the roster in
    # config/mfl.yml has fallen behind the league — an injured-reserve spot
    # added, say — and the record book would rather say so than write a
    # lineup it will not stand behind.
    def guard_roster_size(performance, entries, format)
      room = format.size - format.slot_counts.fetch("ir", 0)
      return if entries.size <= room

      raise Error, "MFL has #{entries.size} players on #{performance.display_name}, and the " \
                   "#{@year} roster in #{Configuration::PATH} has room for #{room}"
    end

    def row(performance, slot, spot, entry)
      player = @players.fetch(entry["id"])
      { performance_id: performance.id, slot: LineupSlot.slots.fetch(slot), sequence: spot + 1,
        points: entry["score"].presence || 0, player_name: player.name,
        player_nfl_team: player.nfl_team, player_positions: player.positions }
    end
  end
end
