ActiveAdmin.register Player do
  menu parent: "Lineups", priority: 1

  permit_params :name, :nfl_team, :positions

  config.sort_order = "name_asc"

  filter :name
  filter :nfl_team
  filter :positions_cont, as: :select, label: "Position",
    collection: -> { Player::POSITIONS.map { |position| [ position.upcase, position ] } }

  index do
    selectable_column
    id_column
    column :name
    column :nfl_team
    column("Positions") { |player| player.positions.map(&:upcase).join("/") }
    column("Lineup slots") { |player| player.lineup_slots.size }
    actions
  end

  show do
    attributes_table do
      row :name
      row :nfl_team
      row("Positions") { |player| player.positions.map(&:upcase).join("/") }
    end
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :nfl_team, hint: "The NFL team abbreviation, which is what tells two same-named players apart."
      f.input :positions, as: :string, input_html: { value: f.object.positions.join(", ") },
        hint: "Comma-separated, most-played first: #{Player::POSITIONS.join(', ')}"
    end
    f.actions
  end

  controller do
    include ListColumnParams

    private
      def resource_params
        super.each { |attributes| split_list_column(attributes, :positions) }
      end
  end
end
