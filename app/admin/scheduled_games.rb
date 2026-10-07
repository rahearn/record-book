ActiveAdmin.register ScheduledGame do
  menu parent: "Matchups", priority: 4, label: "Schedule"

  permit_params :season_id, :week, :tier, :owner_a_id, :owner_b_id

  config.sort_order = "week_asc"

  filter :season, collection: -> { Season.chronological.reverse }
  filter :week
  filter :tier, as: :select, collection: -> { ScheduledGame.tiers.keys.map { |tier| [ tier.titleize, tier ] } }
  filter :owner_a, collection: -> { Owner.order(:name) }
  filter :owner_b, collection: -> { Owner.order(:name) }

  index do
    selectable_column
    id_column
    column :season, sortable: "seasons.year"
    column :week
    column("Tier") { |scheduled| status_tag scheduled.tier.titleize }
    column :owner_a
    column :owner_b
    actions
  end

  show do
    attributes_table do
      row :season
      row :week
      row("Tier") { |scheduled| scheduled.tier.titleize }
      row :owner_a
      row :owner_b
    end
  end

  form do |f|
    f.inputs hint: "A regular-season matchup not yet played. The importer rewrites these each run." do
      f.input :season, collection: Season.chronological.reverse
      f.input :week
      f.input :tier, as: :select, include_blank: false,
        collection: ScheduledGame.tiers.keys.map { |tier| [ tier.titleize, tier ] }
      f.input :owner_a, collection: Owner.order(:name)
      f.input :owner_b, collection: Owner.order(:name)
    end
    f.actions
  end
end
