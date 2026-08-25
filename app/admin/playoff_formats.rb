ActiveAdmin.register PlayoffFormat do
  menu parent: "Formats", priority: 1

  permit_params :season_id, :tier, :team_count, :start_week

  config.sort_order = "id_desc"

  filter :season, collection: -> { Season.chronological.reverse }
  filter :tier, as: :select, collection: -> { PlayoffFormat.tiers.keys.map { |tier| [ tier.titleize, tier ] } }
  filter :team_count
  filter :start_week

  index do
    selectable_column
    id_column
    column :season, sortable: "seasons.year"
    column("Tier") { |format| status_tag format.tier.titleize }
    column :team_count
    column :start_week
    actions
  end

  show do
    attributes_table do
      row :season
      row("Tier") { |format| format.tier.titleize }
      row :team_count
      row :start_week
    end
  end

  form do |f|
    f.inputs do
      f.input :season, collection: Season.chronological.reverse
      f.input :tier, as: :select, include_blank: false,
        collection: PlayoffFormat.tiers.keys.map { |tier| [ tier.titleize, tier ] }
      f.input :team_count
      f.input :start_week,
        hint: "Games from this week on must carry a round name, and earlier games must not."
    end
    f.actions
  end
end
