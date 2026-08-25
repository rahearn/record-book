ActiveAdmin.register RosterFormat do
  menu parent: "Formats", priority: 2

  permit_params :season_id, :slots

  config.sort_order = "id_desc"

  filter :season, collection: -> { Season.chronological.reverse }

  index do
    selectable_column
    id_column
    column :season, sortable: "seasons.year"
    column("Slots") { |format| format.slots.join(", ") }
    column("Starters") { |format| format.starting_slots.size }
    column("Bench", &:bench_count)
    column("IR", &:injured_reserve?)
    actions
  end

  show do
    attributes_table do
      row :season
      row("Starting slots") { |format| format.starting_slots.join(", ") }
      row("Reserve slots") { |format| format.reserve_slots.join(", ") }
      row("Size", &:size)
    end
  end

  form do |f|
    f.inputs do
      f.input :season, collection: Season.chronological.reverse
      f.input :slots, as: :string, input_html: { value: f.object.slots.join(", ") },
        hint: "Comma-separated, starters in reading order and reserves behind them. " \
              "Repeats are meaningful. Known slots: #{LineupSlot.slots.keys.join(', ')}"
    end
    f.actions
  end

  controller do
    include ListColumnParams

    private
      def resource_params
        super.each { |attributes| split_list_column(attributes, :slots) }
      end
  end
end
