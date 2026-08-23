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
weeks = 14
premier_size = 12

rng = Random.new(20_260_823)
noise = -> { (rng.rand + rng.rand + rng.rand - 1.5) * 2 }

ActiveRecord::Base.transaction do
  roster = demo_owners.map do |name, team_name, joined, base|
    { owner: Owner.create!(name:, team_name:), joined:, base: }
  end

  (first_year..last_year).each do |year|
    season = Season.create!(year:)
    active = roster.select { |entry| entry[:joined] <= year }
    tiers = if year >= last_year
      { premier: active.first(premier_size), challenger: active.drop(premier_size) }
    else
      { unified: active }
    end

    tiers.each do |tier, members|
      1.upto(weeks) do |week|
        members.shuffle(random: rng).each_slice(2) do |home, away|
          next unless away

          game = season.games.create!(week:, tier:)
          [ home, away ].each do |entry|
            points = (entry[:base] + noise.call * 20 + (year - first_year) * 0.4).round(1)
            game.performances.create!(owner: entry[:owner], points:)
          end
        end
      end
    end
  end
end

puts "Seeded #{Owner.count} owners, #{Season.count} seasons, #{Game.count} games."
