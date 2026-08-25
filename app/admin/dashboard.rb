# What the record book currently holds, and the way back into the public site.
ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    div class: "grid gap-4 lg:grid-cols-2" do
      div do
        panel "The record book" do
          table_for [
            [ "Seasons", Season.count, admin_seasons_path ],
            [ "Owners", Owner.count, admin_owners_path ],
            [ "Games", Game.count, admin_games_path ],
            [ "Performances", Performance.count, admin_performances_path ],
            [ "Players", Player.count, admin_players_path ],
            [ "Lineup slots", LineupSlot.count, admin_lineup_slots_path ]
          ] do
            column("Records") { |(label, _count, _path)| label }
            column("On record") { |(label, count, path)| link_to count, path, title: label }
          end
        end
      end

      div do
        panel "Latest seasons" do
          table_for Season.order(year: :desc).limit(10) do
            column("Year") { |season| link_to season.year, admin_season_path(season) }
            column("Teams") { |season| season.teams.size }
            column("Games") { |season| season.games.size }
            column("Roster") { |season| season.roster_format ? "#{season.roster_format.size} slots" : "—" }
          end
        end

        para link_to("Back to the record book", root_path)
      end
    end
  end
end
