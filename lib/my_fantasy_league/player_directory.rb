module MyFantasyLeague
  # Who the player ids in a week's results belong to.
  #
  # A week's results name players by id and nothing else, so the record book's
  # side of a lineup slot — the name, the NFL team, the positions they were
  # eligible at — is looked up here, once per import and for every id the
  # season touched.
  #
  # MFL writes both names and teams its own way, and the record book already
  # holds twenty seasons written Yahoo's way, so both are translated on the
  # way in rather than left to read differently either side of 2025.
  class PlayerDirectory
    Error = Class.new(StandardError)

    Player = Data.define(:name, :nfl_team, :positions)

    # MFL's positions, including the team-level ones leagues that start a
    # whole NFL offense use. Kickers left the league after 2009, but the
    # slot is still one the record book knows.
    POSITIONS = {
      "QB" => "qb", "RB" => "rb", "WR" => "wr", "TE" => "te", "PK" => "k", "Def" => "dst",
      "TMQB" => "qb", "TMRB" => "rb", "TMWR" => "wr", "TMTE" => "te", "TMPK" => "k"
    }.freeze

    # The eight teams MFL abbreviates differently to the Yahoo exports the
    # rest of the record book was loaded from. Everything else already
    # matches once case is set aside.
    NFL_TEAMS = {
      "GBP" => "GB", "JAC" => "JAX", "KCC" => "KC", "LVR" => "LV",
      "NEP" => "NE", "NOS" => "NO", "SFO" => "SF", "TBB" => "TB"
    }.freeze

    # A player with no NFL team is a free agent, and the record book insists
    # on something being written in the column.
    FREE_AGENT = "FA".freeze

    def self.for(client, ids)
      new(client.players(ids))
    end

    def initialize(records)
      @players = records.to_h { |record| [ record["id"].to_s, build(record) ] }
    end

    def fetch(id)
      @players.fetch(id.to_s) { raise Error, "MFL has no player #{id}" }
    end

    private

    def build(record)
      Player.new(name: name(record["name"]),
                 nfl_team: NFL_TEAMS.fetch(record["team"], record["team"]).presence || FREE_AGENT,
                 positions: [ position(record) ])
    end

    # MFL files everyone surname first — "Kamara, Alvin", and team defenses
    # as "Bills, Buffalo" — so the two halves swap back. Splitting on the
    # first comma only keeps a suffix where it belongs: "Harrison Jr.,
    # Marvin" reads back as "Marvin Harrison Jr.".
    def name(written)
      surname, given = written.to_s.split(",", 2).map(&:strip)
      given.present? ? "#{given} #{surname}" : surname.to_s
    end

    def position(record)
      POSITIONS.fetch(record["position"]) do
        raise Error, "MFL lists #{record["name"]} at #{record["position"]}, which is not a position " \
                     "the record book has a slot for"
      end
    end
  end
end
