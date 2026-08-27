module MyFantasyLeague
  # What `config/mfl.yml` says about the seasons the league has played on
  # MyFantasyLeague: the league each year was played in, the divisions its
  # tiers were run as, the brackets its playoffs were played over, and who
  # sat behind each franchise.
  #
  # The shape of a season is checked when it is read rather than when it is
  # used, so a season half added to the file says so before the importer has
  # written a thing. Who sits behind each franchise is the exception: that is
  # what `mfl:preview` is for working out, and it has to run to be useful.
  class Configuration
    Error = Class.new(StandardError)

    PATH = "config/mfl.yml".freeze

    Playoffs = Data.define(:bracket, :third_place)
    Tier = Data.define(:name, :division, :playoffs)

    Season = Data.define(:year, :league_id, :roster, :tiers, :franchises) do
      def tier(name)
        tiers.fetch(name.to_s) do
          raise Error, "#{year} has no #{name} tier in #{PATH} (it has #{tiers.keys.to_sentence})"
        end
      end

      # The tier a franchise played in, worked out from the division MFL has
      # it in. A franchise in some other division — a stray test team, say —
      # belongs to no tier and is left out of the import.
      def tier_for_division(division)
        tiers.values.find { |tier| tier.division == division }
      end

      # Nil for a franchise the file has not named yet, which is what
      # `mfl:preview` exists to help fill in.
      def owner_name(franchise_id)
        franchises[franchise_id]
      end
    end

    def self.load(path: Rails.root.join(PATH))
      new(YAML.load_file(path, aliases: true) || {})
    rescue Errno::ENOENT
      raise Error, "#{PATH} is missing — it is what says which MFL league a season was played in"
    end

    def initialize(document)
      @document = document
    end

    def user_agent
      ENV["MFL_USER_AGENT"].presence || @document["user_agent"].presence ||
        raise(Error, "#{PATH} needs a user_agent; MFL throttles clients that will not name themselves")
    end

    def years
      seasons.keys.map(&:to_i).sort
    end

    def season(year)
      body = seasons[year.to_s] || seasons[year] or
        raise Error, "#{PATH} has nothing for #{year} (it has #{years.join(", ")})"

      Season.new(year: year.to_i, league_id: league_id(year, body), roster: roster(year, body),
                 tiers: tiers(year, body), franchises: franchises(year, body))
    end

    private

    def seasons
      @document["seasons"] || {}
    end

    def league_id(year, body)
      body["league_id"].presence or
        raise Error, "#{year} has no league_id in #{PATH}"
    end

    def roster(year, body)
      slots = Array(body["roster"]).map(&:to_s)
      raise Error, "#{year} has no roster in #{PATH}" if slots.empty?

      unknown = slots.uniq - LineupSlot.slots.keys
      raise Error, "#{year}'s roster in #{PATH} has #{unknown.to_sentence}, which is not a slot" if unknown.any?

      slots
    end

    def tiers(year, body)
      configured = body["tiers"] || {}
      raise Error, "#{year} has no tiers in #{PATH}" if configured.empty?

      configured.to_h do |name, tier|
        raise Error, "#{year}'s #{name} tier is not one the record book knows" unless Game.tiers.key?(name.to_s)

        [ name.to_s, Tier.new(name: name.to_s, division: division(year, name, tier),
                              playoffs: playoffs(tier["playoffs"])) ]
      end
    end

    def division(year, name, tier)
      tier["division"].presence&.to_s or
        raise Error, "#{year}'s #{name} tier has no division in #{PATH}"
    end

    # A season still being played has no brackets yet, so playoffs are
    # allowed to be missing; a bracket without a third-place game is normal.
    def playoffs(configured)
      return if configured.blank?

      Playoffs.new(bracket: configured["bracket"]&.to_s,
                   third_place: configured["third_place"]&.to_s)
    end

    # A franchise left blank is dropped rather than refused, so that
    # `mfl:preview` can be run against a season whose franchises have yet to
    # be matched up with owners. The importer is what insists on all of them.
    def franchises(_year, body)
      (body["franchises"] || {}).filter_map do |id, owner|
        [ id.to_s, owner.to_s.strip ] if owner.present?
      end.to_h
    end
  end
end
