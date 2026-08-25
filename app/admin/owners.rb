ActiveAdmin.register Owner do
  menu parent: "League", priority: 1

  permit_params :name

  filter :name
  filter :teams, collection: -> { Team.order(:name).pluck(:name, :id) }

  index do
    selectable_column
    id_column
    column :name
    column("Latest team", &:team_name)
    column("Seasons") { |owner| owner.teams.size }
    column("Games") { |owner| owner.performances.size }
    actions
  end

  show do
    attributes_table do
      row :name
      row :initials
      row("Latest team", &:team_name)
    end

    panel "Teams" do
      table_for owner.teams.includes(:season).order("seasons.year desc") do
        column("Season") { |team| link_to team.season.year, admin_season_path(team.season) }
        column("Name") { |team| link_to team.name, admin_team_path(team) }
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :name
    end
    f.actions
  end
end
