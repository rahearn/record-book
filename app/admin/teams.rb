ActiveAdmin.register Team do
  menu parent: "League", priority: 3

  permit_params :owner_id, :season_id, :name

  config.sort_order = "id_desc"

  filter :season, collection: -> { Season.chronological.reverse }
  filter :owner, collection: -> { Owner.order(:name) }
  filter :name

  index do
    selectable_column
    id_column
    column :season, sortable: "seasons.year"
    column :owner, sortable: "owners.name"
    column :name
    actions
  end

  show do
    attributes_table do
      row :season
      row :owner
      row :name
    end
  end

  form do |f|
    f.inputs do
      f.input :season, collection: Season.chronological.reverse
      f.input :owner, collection: Owner.order(:name)
      f.input :name, hint: "The name this owner fielded that season; owners rename often."
    end
    f.actions
  end
end
