# Loading a season off MyFantasyLeague, which is where the league has played
# since 2025. Which league a year was played in, and who sat behind each
# franchise, is config/mfl.yml's business; this is only the door in.
namespace :mfl do
  desc "Import a season from MyFantasyLeague: mfl:import[2025], or [2025,7] for one week, or [2025,7,premier]"
  task :import, [ :year, :week, :tier ] => :environment do |_task, args|
    year = (args[:year] || ENV["YEAR"]).presence or
      abort "Which year? bin/rails \"mfl:import[2025]\""
    week = (args[:week] || ENV["WEEK"]).presence
    tiers = (args[:tier] || ENV["TIER"]).to_s.split(",").map(&:strip).compact_blank

    MyFantasyLeague::Import.new(year: Integer(year)).call(week: week && Integer(week), tiers: tiers)
  rescue MyFantasyLeague::Client::Error, MyFantasyLeague::Configuration::Error,
         MyFantasyLeague::Import::Error, MyFantasyLeague::PlayerDirectory::Error,
         MyFantasyLeague::Schedule::Error => error
    abort error.message
  end

  desc "Show what MyFantasyLeague has for a season without writing any of it down"
  task :preview, [ :year ] => :environment do |_task, args|
    year = (args[:year] || ENV["YEAR"]).presence or
      abort "Which year? bin/rails \"mfl:preview[2025]\""

    config = MyFantasyLeague::Configuration.load
    season = config.season(Integer(year))
    client = MyFantasyLeague::Client.new(year: Integer(year), league_id: season.league_id,
                                         user_agent: config.user_agent)
    schedule = MyFantasyLeague::Schedule.load(client: client, season: season)

    puts "#{year}: MFL league #{season.league_id}"
    schedule.playoff_formats.each do |format|
      puts "  #{format.tier} playoffs: #{format.team_count} teams from week #{format.start_week}"
    end
    schedule.franchise_names.sort.each do |id, name|
      tier = schedule.tier_for(id) || "no tier"
      puts "  #{id}  #{tier.ljust(11)} #{name}"
    end
    schedule.matchups.group_by { |matchup| [ matchup.week, matchup.tier ] }.each do |(week, tier), matchups|
      rounds = matchups.map(&:round_name).compact.uniq
      puts "  week #{week.to_s.rjust(2)} #{tier.ljust(11)} " \
           "#{matchups.size} #{"game".pluralize(matchups.size)}#{" · #{rounds.join(", ")}" if rounds.any?}"
    end
  rescue MyFantasyLeague::Client::Error, MyFantasyLeague::Configuration::Error,
         MyFantasyLeague::Schedule::Error => error
    abort error.message
  end
end
