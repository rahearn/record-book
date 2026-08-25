# Deterministic demo league mirroring docs/initial_design.html: 20 owners
# across 15 seasons (2011–2025), 14-week regular seasons, with the league
# splitting into Premier/Challenger tiers in 2025. Real historical data will
# replace this via a future loading layer.

if Game.exists?
  puts "Games already on record — skipping demo seed data."
  return
end

demo_owners = [
  # [ name, team name, joined, base strength ]
  [ "Dave Kroll", "Ozark Mudcats", 2011, 119 ],
  [ "Tim Brossard", "Vandal Kings", 2011, 115 ],
  [ "Marcy Ostrander", "Bitter Creek FC", 2011, 117 ],
  [ "Paul Devereaux", "Nine Volt Nation", 2011, 112 ],
  [ "Gil Amaya", "Hot Route Heroes", 2011, 116 ],
  [ "Rana Pilcher", "Blue Ridge Bandits", 2011, 110 ],
  [ "Sam Deitrick", "Ironhead Collective", 2011, 114 ],
  [ "Nate Whitlow", "Quarry Dogs", 2011, 108 ],
  [ "Esther Vang", "Corner Blitz Co.", 2013, 118 ],
  [ "Marcus Held", "The Toe Drag", 2013, 111 ],
  [ "Keith Amundsen", "Pylon Society", 2016, 113 ],
  [ "Dana Rooke", "Silt Runners", 2016, 109 ],
  [ "Joel Pratt", "Meridian Mules", 2019, 107 ],
  [ "Alicia Nunn", "Cold Front", 2019, 110 ],
  [ "Bobby Sarnicola", "Third & Long", 2019, 105 ],
  [ "Wes Okafor", "Halfback Hotel", 2019, 112 ],
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

# One roster: a quarterback, four backs, four receivers, two tight ends, a
# kicker and a defense. Nine start; the rest ride the bench.
roster_template = { "qb" => 1, "rb" => 4, "wr" => 4, "te" => 2, "k" => 1, "dst" => 1 }
starting_slots = [
  [ :qb, "qb", 0, 0.175 ], [ :rb, "rb", 0, 0.130 ], [ :rb, "rb", 1, 0.105 ],
  [ :wr, "wr", 0, 0.125 ], [ :wr, "wr", 1, 0.105 ], [ :te, "te", 0, 0.085 ],
  [ :flex, "rb", 2, 0.095 ], [ :k, "k", 0, 0.060 ], [ :dst, "dst", 0, 0.070 ]
]
bench_spots = [ [ "rb", 3 ], [ "wr", 2 ], [ "wr", 3 ], [ "te", 1 ] ]

# Now and then a back, receiver or tight end is eligible somewhere else too,
# which is what makes the optimal-lineup search worth running.
flex_positions = %w[rb wr te]
dual_eligible_odds = 0.06

first_year = 2011
last_year = 2025
premier_size = 12

rng = Random.new(20_260_823)
noise = -> { (rng.rand + rng.rand + rng.rand - 1.5) * 2 }

ActiveRecord::Base.transaction do
  roster = demo_owners.map do |name, team_name, joined, base|
    { owner: Owner.create!(name:), team_name:, joined:, base: }
  end

  skater_names = player_first_names.product(player_last_names).shuffle(random: rng)
  abbreviations = nfl_teams.values
  player_ids = roster_template.to_h do |position, per_roster|
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
    [ position, Player.insert_all!(players, returning: :id).rows.flatten ]
  end

  lineup_rows = []
  flush_lineups = lambda do
    LineupSlot.insert_all!(lineup_rows) if lineup_rows.any?
    lineup_rows.clear
  end

  # Split a week's total across the nine starters, weighted by slot, then
  # give the bench some of what it might have been worth.
  build_lineup = lambda do |performance, roster_players, total|
    weights = starting_slots.map { |_, _, _, weight| [ 0.02, weight * (0.55 + rng.rand * 0.95) ].max }
    scale = weights.sum
    points = weights.map { |weight| (total * weight / scale).round(1) }
    points[0] = (points[0] + (total - points.sum)).round(1)
    starters = starting_slots.each_with_index.map do |(slot, position, index, _), spot|
      { performance_id: performance.id, player_id: roster_players[position][index],
        slot: LineupSlot.slots[slot.to_s], sequence: spot + 1, points: points[spot] }
    end
    starters + bench_spots.each_with_index.map do |(position, index), spot|
      { performance_id: performance.id, player_id: roster_players[position][index],
        slot: LineupSlot.slots["bench"], sequence: starting_slots.size + spot + 1,
        points: (total * (0.02 + rng.rand * 0.085)).round(1) }
    end
  end

  (first_year..last_year).each do |year|
    season = Season.create!(year:)
    active = roster.select { |entry| entry[:joined] <= year }
    active.each do |entry|
      Team.create!(owner: entry[:owner], season: season, name: entry[:team_name])
    end

    # One league-wide snake draft a season, so every player belongs to
    # exactly one roster for the whole year.
    available = player_ids.transform_values { |ids| ids.shuffle(random: rng) }
    rosters = active.to_h do |entry|
      [ entry[:owner].id, Hash.new { |slots, position| slots[position] = [] } ]
    end
    draft_order = active.shuffle(random: rng)
    roster_template.flat_map { |position, count| [ position ] * count }
      .each_with_index do |position, round|
        picking = round.odd? ? draft_order.reverse : draft_order
        picking.each { |entry| rosters[entry[:owner].id][position] << available[position].shift }
      end

    tiers = if year >= last_year
      { premier: active.first(premier_size), challenger: active.drop(premier_size) }
    else
      { unified: active }
    end

    # The league moved from a 13-week regular season to 14 in 2015, and from
    # 4-team playoffs to 6 in 2019. The Challenger tier keeps a 4-team field.
    regular_weeks = year <= 2014 ? 13 : 14
    playoff_start = regular_weeks + 1

    tiers.each do |tier, members|
      team_count = tier == :challenger || year < 2019 ? 4 : 6
      PlayoffFormat.create!(season:, tier:, team_count:, start_week: playoff_start)

      tally = Hash.new { |hash, owner_id| hash[owner_id] = { wins: 0, points: 0 } }
      play = lambda do |week, home, away, round_name: nil|
        game = season.games.create!(week:, tier:, round_name:)
        home_points, away_points = [ home, away ].map do |entry|
          points = (entry[:base] + noise.call * 20 + (year - first_year) * 0.4).round(1)
          performance = game.performances.create!(owner: entry[:owner], points:)
          lineup_rows.concat(build_lineup.call(performance, rosters[entry[:owner].id], points))
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

puts "Seeded #{Owner.count} owners, #{Season.count} seasons, #{Game.count} games " \
     "(#{Game.where.not(round_name: nil).count} playoff), " \
     "#{Player.count} players and #{LineupSlot.count} lineup slots."
