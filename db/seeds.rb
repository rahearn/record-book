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

first_year = 2011
last_year = 2025
premier_size = 12

rng = Random.new(20_260_823)
noise = -> { (rng.rand + rng.rand + rng.rand - 1.5) * 2 }

ActiveRecord::Base.transaction do
  roster = demo_owners.map do |name, team_name, joined, base|
    { owner: Owner.create!(name:), team_name:, joined:, base: }
  end

  (first_year..last_year).each do |year|
    season = Season.create!(year:)
    active = roster.select { |entry| entry[:joined] <= year }
    active.each do |entry|
      Team.create!(owner: entry[:owner], season: season, name: entry[:team_name])
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
          game.performances.create!(owner: entry[:owner], points:)
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
  end
end

puts "Seeded #{Owner.count} owners, #{Season.count} seasons, #{Game.count} games " \
     "(#{Game.where.not(round_name: nil).count} playoff)."
