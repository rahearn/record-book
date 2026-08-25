ActiveAdmin.register Season do
  menu parent: "League", priority: 2

  permit_params :year

  config.sort_order = "year_desc"

  filter :year

  index do
    selectable_column
    id_column
    column :year
    column("Teams") { |season| season.teams.size }
    column("Games") { |season| season.games.size }
    column("Roster") { |season| season.roster_format&.slots&.size }
    column("Playoff tiers") { |season| season.playoff_formats.map { |format| format.tier.titleize }.to_sentence }
    actions
  end

  show do
    attributes_table do
      row :year
      row("Roster format") do |season|
        if season.roster_format
          link_to season.roster_format.slots.join(", "), admin_roster_format_path(season.roster_format)
        end
      end
    end

    panel "Playoff formats" do
      table_for season.playoff_formats do
        column("Tier") { |format| link_to format.tier.titleize, admin_playoff_format_path(format) }
        column :team_count
        column :start_week
      end
    end

    panel "Teams" do
      table_for season.teams.includes(:owner).order(:name) do
        column("Owner") { |team| link_to team.owner.name, admin_owner_path(team.owner) }
        column("Name") { |team| link_to team.name, admin_team_path(team) }
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :year
    end
    f.actions
  end
end
