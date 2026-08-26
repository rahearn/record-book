# Deterministic demo league mirroring docs/initial_design.html: 20 owners
# across 15 seasons (2011–2025), 14-week regular seasons, with the league
# splitting into Premier/Challenger tiers in 2025. Real historical data will
# replace this via a future loading layer.

# The lineup the league has played, year by year: two backs and two
# receivers throughout, a flex added in 2006 that opened to tight ends in
# 2009, kickers dropped after 2009, an injured reserve spot for 2021 only,
# and a bench that fell from seven to three before settling at four.
roster_progression = {
  2005 => %w[qb wr wr rb rb te k dst] + %w[bench] * 6,
  2006..2008 => %w[qb wr wr rb rb te wr_rb k dst] + %w[bench] * 6,
  2009 => %w[qb wr wr rb rb te wr_rb_te k dst] + %w[bench] * 6,
  2010..2012 => %w[qb wr wr rb rb te wr_rb_te dst] + %w[bench] * 7,
  2013 => %w[qb wr wr rb rb te wr_rb_te dst] + %w[bench] * 6,
  2014..2017 => %w[qb wr wr rb rb te wr_rb_te dst] + %w[bench] * 5,
  2018..2020 => %w[qb wr wr rb rb te wr_rb_te dst] + %w[bench] * 3,
  2021 => %w[qb wr wr rb rb te wr_rb_te dst] + %w[bench] * 3 + %w[ir],
  2022..2024 => %w[qb wr wr rb rb te wr_rb_te dst] + %w[bench] * 3,
  2025..2026 => %w[qb wr wr rb rb te wr_rb_te dst] + %w[bench] * 4
}
roster_format_for = ->(year) { roster_progression.find { |years, _| years === year }.last }
playoff_progression = {
  2005 => { unified: { start_week: 14, team_count: 8 } },
  2006..2019 => { unified: { start_week: 14, team_count: 6 } },
  2020 => { unified: { start_week: 14, team_count: 8 } },
  2021..2024 => { unified: { start_week: 15, team_count: 8 } },
  2025..2026 => { premier: { start_week: 15, team_count: 6 }, challenger: { start_week: 15, team_count: 4 } }
}
playoff_format_for = ->(year) { playoff_progression.find { |years, _| years === year }.last }

if Rails.env.production? || ENV["USE_PROD_DATA_SEED"]
  Owner.find_or_create_by! name: "Chris Schilling"
  Owner.find_or_create_by! name: "Jason Jennings"
  Owner.find_or_create_by! name: "Ryan Ahearn"
  Owner.find_or_create_by! name: "Chris Insolera"
  Owner.find_or_create_by! name: "Matt Megas"
  Owner.find_or_create_by! name: "Ian Solla-Yates"
  Owner.find_or_create_by! name: "Matt Terry"
  Owner.find_or_create_by! name: "Andy Velarde"
  Owner.find_or_create_by! name: "Matt Peterson"
  Owner.find_or_create_by! name: "Chris Lewis"
  Owner.find_or_create_by! name: "Chris Tate"
  Owner.find_or_create_by! name: "Tim Switzer"
  Owner.find_or_create_by! name: "Ben Verley"
  Owner.find_or_create_by! name: "Fuzz Otto"
  Owner.find_or_create_by! name: "Adam Goldberg"
  Owner.find_or_create_by! name: "John Wells"
  Owner.find_or_create_by! name: "Tim Schenk"
  Owner.find_or_create_by! name: "Matt Jennings"
  Owner.find_or_create_by! name: "Mike Jennings"
  Owner.find_or_create_by! name: "Kenny Merrill"
  Owner.find_or_create_by! name: "John Sweeney"
  Owner.find_or_create_by! name: "Colin Clark"
  Owner.find_or_create_by! name: "Tyler Cassidy"
  Owner.find_or_create_by! name: "Andy Johnson"
  Owner.find_or_create_by! name: "Andy Webster"
  Owner.find_or_create_by! name: "Clay Eaddy"
  Owner.find_or_create_by! name: "Bootleg 4 Live Draft"

  (2005..2024).each do |year|
    season = Season.find_or_create_by!(year:)
    RosterFormat.find_or_create_by!(season:, slots: roster_format_for.call(year))
    playoff_format_for.call(year).each do |tier, format|
      format => { start_week:, team_count: }
      PlayoffFormat.find_or_create_by!(season:, tier:, start_week:, team_count:)
    end
  end

  CSV.open(Rails.root.join("docs", "yahoo", "teams.csv")).each do |row|
    Team.find_or_create_by!(season: Season.find_by(year: row[0]), name: row[1], owner: Owner.find_by!(name: row[2]))
  end

  (2005..2024).each do |year|
    season = Season.find_by(year:)
    CSV.open(Rails.root.join("docs", "yahoo", "matchups_#{year}.csv")).each do |row|
      week = row[0].to_i
      playoff_start = year <= 2020 ? 14 : 15
      game = season.games.find_or_create_by!(week:, round_name: week >= playoff_start ? "TKTK" : nil)
      team_1 = Team.find_by(season:, name: row[1])
      team_2 = Team.find_by(season:, name: row[3])
      game.performances.find_or_create_by!(owner: team_1.owner, points: row[2])
      game.performances.find_or_create_by!(owner: team_2.owner, points: row[4])
    end
    CSV.open(Rails.root.join("docs", "yahoo", "players_#{year}.csv")).each do |row|
      week = row[0].to_i
      points = row[1]
      team_name = row[2]
      bench = row[3] != "Starter"
      player_name = row[4]
      nfl_team = row[5].upcase
      eligible_positions = row[6].split("|").reject { |p| p.match?("/") }
      owner = Owner.joins(:teams).find_by(teams: {name: team_name, season:})
      performance = owner.performances.joins(:game).find_by(games: {season:, week:})
      ## TODO build lineup slots legal according to this seasons RosterFormat
    end
  end
else
  if Game.exists?
    puts "Games already on record - skipping demo seed data"
    return
  end

  demo_owners = [
    # [ name, team name, joined, base strength ]
    [ "Dave Kroll", "Ozark Mudcats", 2005, 119 ],
    [ "Tim Brossard", "Vandal Kings", 2005, 115 ],
    [ "Marcy Ostrander", "Bitter Creek FC", 2005, 117 ],
    [ "Paul Devereaux", "Nine Volt Nation", 2005, 112 ],
    [ "Gil Amaya", "Hot Route Heroes", 2005, 116 ],
    [ "Rana Pilcher", "Blue Ridge Bandits", 2005, 110 ],
    [ "Sam Deitrick", "Ironhead Collective", 2005, 114 ],
    [ "Nate Whitlow", "Quarry Dogs", 2005, 108 ],
    [ "Esther Vang", "Corner Blitz Co.", 2008, 118 ],
    [ "Marcus Held", "The Toe Drag", 2008, 111 ],
    [ "Keith Amundsen", "Pylon Society", 2012, 113 ],
    [ "Dana Rooke", "Silt Runners", 2012, 109 ],
    [ "Joel Pratt", "Meridian Mules", 2017, 107 ],
    [ "Alicia Nunn", "Cold Front", 2017, 110 ],
    [ "Bobby Sarnicola", "Third & Long", 2017, 105 ],
    [ "Wes Okafor", "Halfback Hotel", 2017, 112 ],
    [ "Trish Landry", "Grain Belt Ghosts", 2025, 106 ],
    [ "Andre Boisvert", "Slot Machine", 2025, 104 ],
    [ "Kenny Rue", "Dust Bowl Deuce", 2025, 108 ],
    [ "Priya Raman", "Lame Duck FC", 2025, 103 ]
  ]

  # A player pool big enough to give every owner in the biggest season a full
  # 13-man roster, drafted fresh each year so nobody shares a player.
  player_first_names = %w[
    Colt Damon Ellis Rowan Judd Casey Marlon Dex Nico Sully Wyatt Rashad Tobin Elton
    Cyrus Marquis Trey Isaiah Kip Deonte Levi Omar Jamal Corey Nash Amari Tevin Silas
    Donnell Rico Malik Chase Zeke Terrance Brant Emeka Ruben Colby Gus Byron Abel Reggie
    Tanner Milo Deshawn Vance Anders Kellen Miguel Otto Lars Quentin Micah Grant Wade Rex
  ]
  player_last_names = %w[
    Reneau Fitch Vandermeer Osgood Pike Merriweather Bellinger Trask Halloran Braddock
    Kranz Ferris Ellery Mackey Alcaraz Reyes Winslow Nadel Bollinger Fontenot Sandoval
    Marsh Stipe Petrie Ibarra Dorsey Leclair Whitfield Boone Pace Santangelo Kessler
    Vidrine Ranallo Adeyemi Sheffield Kuhn Nwosu Sarto Feltz Lindahl Marlowe Vaughn Ochs
    Craven Pellegrino Kirkby Vogel Cardoso Rask Arriaga Lindqvist Pardo Whitcomb Rowen
    Calloway Kemper
  ]
  nfl_teams = {
    "Bears" => "CHI", "Ravens" => "BAL", "Broncos" => "DEN", "Jets" => "NYJ",
    "Saints" => "NO", "Bills" => "BUF", "Steelers" => "PIT", "Chargers" => "LAC",
    "Titans" => "TEN", "Packers" => "GB", "Vikings" => "MIN", "Chiefs" => "KC",
    "Eagles" => "PHI", "Cowboys" => "DAL", "Browns" => "CLE", "Texans" => "HOU",
    "Colts" => "IND", "Lions" => "DET", "Rams" => "LAR", "Dolphins" => "MIA",
    "Falcons" => "ATL", "Seahawks" => "SEA", "Giants" => "NYG", "Panthers" => "CAR",
    "Cardinals" => "ARI", "Jaguars" => "JAX", "Raiders" => "LV", "Bengals" => "CIN",
    "Commanders" => "WAS", "Patriots" => "NE", "Buccaneers" => "TB", "49ers" => "SF"
  }


  # The position drafted for each slot: flex spots take a back, and the
  # reserves are stocked with depth where depth matters.
  slot_positions = { "qb" => "qb", "wr" => "wr", "rb" => "rb", "te" => "te",
                    "k" => "k", "dst" => "dst", "wr_rb" => "rb", "wr_rb_te" => "rb" }
  bench_depth = %w[rb wr rb wr te qb wr]
  # Relative scoring weight per slot; a repeated slot gets the lesser option.
  slot_weights = { "qb" => 0.175, "wr" => 0.125, "rb" => 0.130, "te" => 0.085,
                  "k" => 0.060, "dst" => 0.070, "wr_rb" => 0.095, "wr_rb_te" => 0.095 }

  # Now and then a back, receiver or tight end is eligible somewhere else too,
  # which is what makes the optimal-lineup search worth running.
  flex_positions = %w[rb wr te]
  dual_eligible_odds = 0.06

  first_year = 2005
  last_year = 2025
  premier_size = 12


  # One roster laid out slot by slot, each paired with the position drafted
  # to fill it, so a season's draft and its lineups read off the same plan.
  roster_plan = lambda do |year|
    depth = bench_depth.cycle
    roster_format_for.call(year).map do |slot|
      position = case slot
      when "bench" then depth.next
      when "ir" then "wr"
      else slot_positions.fetch(slot)
      end
      [ slot, position ]
    end
  end

  # Deep enough for the hungriest season in range.
  roster_template = (first_year..last_year)
    .map { |year| roster_plan.call(year).map(&:last).tally }
    .reduce { |deepest, needed| deepest.merge(needed) { |_, a, b| [ a, b ].max } }

  rng = Random.new(20_260_823)
  noise = -> { (rng.rand + rng.rand + rng.rand - 1.5) * 2 }

  ActiveRecord::Base.transaction do
    roster = demo_owners.map do |name, team_name, joined, base|
      { owner: Owner.create!(name:), team_name:, joined:, base: }
    end

    skater_names = player_first_names.product(player_last_names).shuffle(random: rng)
    abbreviations = nfl_teams.values
    # The pool is plain Ruby: a player is only ever written down as part of a
    # lineup slot, so these exist to be drafted, not to be saved.
    player_pool = roster_template.to_h do |position, per_roster|
      players = if position == "dst"
        nfl_teams.to_a.shuffle(random: rng).map do |nickname, abbreviation|
          { name: "#{nickname} D/ST", nfl_team: abbreviation, positions: [ position ] }
        end
      else
        skater_names.shift(per_roster * demo_owners.size).map do |parts|
          second = flex_positions - [ position ] if flex_positions.include?(position)
          positions = [ position ]
          positions << second.sample(random: rng) if second && rng.rand < dual_eligible_odds
          { name: parts.join(" "), nfl_team: abbreviations.sample(random: rng), positions: }
        end
      end
      [ position, players ]
    end

    lineup_rows = []
    flush_lineups = lambda do
      LineupSlot.insert_all!(lineup_rows) if lineup_rows.any?
      lineup_rows.clear
    end

    # Split a week's total across the starters, weighted by slot and thinned
    # for a repeated one, then give the bench some of what it might have been
    # worth. A player on injured reserve did not play, so they scored nothing.
    build_lineup = lambda do |performance, plan, roster_players, total|
      seen = Hash.new(0)
      weights = plan.map do |slot, _|
        next 0.0 if LineupSlot::RESERVE_SLOTS.include?(slot)

        weight = slot_weights.fetch(slot) * (seen[slot].zero? ? 1.0 : 0.8)
        seen[slot] += 1
        [ 0.02, weight * (0.55 + rng.rand * 0.95) ].max
      end
      scale = weights.sum
      points = weights.map { |weight| (total * weight / scale).round(1) }
      points[0] = (points[0] + (total - points.sum)).round(1)

      plan.each_with_index.map do |(slot, _), spot|
        scored = case slot
        when "bench" then (total * (0.02 + rng.rand * 0.085)).round(1)
        when "ir" then 0.0
        else points[spot]
        end
        player = roster_players[spot]
        { performance_id: performance.id, player_name: player[:name],
          player_nfl_team: player[:nfl_team], player_positions: player[:positions],
          slot: LineupSlot.slots.fetch(slot), sequence: spot + 1, points: scored }
      end
    end

    (first_year..last_year).each do |year|
      season = Season.create!(year:)
      active = roster.select { |entry| entry[:joined] <= year }
      active.each do |entry|
        Team.create!(owner: entry[:owner], season: season, name: entry[:team_name])
      end

      plan = roster_plan.call(year)
      RosterFormat.create!(season:, slots: plan.map(&:first))

      # One league-wide snake draft a season, so every player belongs to
      # exactly one roster for the whole year. A roster comes out in plan
      # order: the player at each index fills the slot at the same index.
      available = player_pool.transform_values { |players| players.shuffle(random: rng) }
      rosters = active.to_h { |entry| [ entry[:owner].id, [] ] }
      draft_order = active.shuffle(random: rng)
      plan.each_with_index do |(_slot, position), round|
        picking = round.odd? ? draft_order.reverse : draft_order
        picking.each { |entry| rosters[entry[:owner].id] << available[position].shift }
      end

      tiers = if year >= last_year
        { premier: active.first(premier_size), challenger: active.drop(premier_size) }
      else
        { unified: active }
      end

      # The league moved from a 13-week regular season to 14 in 2021
      regular_weeks = year <= 2020 ? 13 : 14
      playoff_start = regular_weeks + 1

      tiers.each do |tier, members|
        team_count = playoff_format_for.call(year)[tier][:team_count]
        PlayoffFormat.create!(season:, tier:, team_count:, start_week: playoff_start)

        tally = Hash.new { |hash, owner_id| hash[owner_id] = { wins: 0, points: 0 } }
        play = lambda do |week, home, away, round_name: nil|
          game = season.games.create!(week:, tier:, round_name:)
          home_points, away_points = [ home, away ].map do |entry|
            points = (entry[:base] + noise.call * 20 + (year - first_year) * 0.4).round(1)
            performance = game.performances.create!(owner: entry[:owner], points:)
            lineup_rows.concat(build_lineup.call(performance, plan, rosters[entry[:owner].id], points))
            points
          end
          unless round_name
            tally[home[:owner].id][:points] += home_points
            tally[away[:owner].id][:points] += away_points
            tally[home[:owner].id][:wins] += 1 if home_points > away_points
            tally[away[:owner].id][:wins] += 1 if away_points > home_points
          end
          home_points >= away_points ? [ home, away ] : [ away, home ]
        end

        1.upto(regular_weeks) do |week|
          members.shuffle(random: rng).each_slice(2) do |home, away|
            play.call(week, home, away) if away
          end
        end

        seeds = members.sort_by { |entry| t = tally[entry[:owner].id]; [ -t[:wins], -t[:points] ] }
          .first(team_count)
        if team_count == 4
          semi_week = playoff_start
        else
          quarter_one, = play.call(playoff_start, seeds[2], seeds[5], round_name: "Quarterfinal")
          quarter_two, = play.call(playoff_start, seeds[3], seeds[4], round_name: "Quarterfinal")
          seeds = [ seeds[0], seeds[1], quarter_one, quarter_two ]
          semi_week = playoff_start + 1
        end
        semi_one_winner, semi_one_loser = play.call(semi_week, seeds[0], seeds[3], round_name: "Semifinal")
        semi_two_winner, semi_two_loser = play.call(semi_week, seeds[1], seeds[2], round_name: "Semifinal")
        play.call(semi_week + 1, semi_one_winner, semi_two_winner, round_name: Game::CHAMPIONSHIP)
        play.call(semi_week + 1, semi_one_loser, semi_two_loser, round_name: Game::THIRD_PLACE)
      end

      flush_lineups.call
    end
  end
end

puts "Seeded #{Owner.count} owners, #{Season.count} seasons, #{Game.count} games " \
     "(#{Game.where.not(round_name: nil).count} playoff), " \
     "#{LineupSlot.distinct.count(:player_name)} players and " \
     "#{LineupSlot.count} lineup slots across " \
     "#{RosterFormat.distinct.count(:slots)} roster formats."
