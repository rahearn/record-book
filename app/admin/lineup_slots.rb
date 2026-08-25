# Lineups are normally entered whole from the performance they belong to, since
# Performance holds them to the season's roster format. This resource is for
# looking one up and correcting it in place.
ActiveAdmin.register LineupSlot do
  menu parent: "Matchups", priority: 3

  permit_params :performance_id, :slot, :points, :sequence,
    :player_name, :player_nfl_team, :player_positions

  config.sort_order = "id_desc"

  filter :player_name
  filter :player_nfl_team
  filter :player_positions_cont, as: :select, label: "Position",
    collection: -> { LineupSlot::ANY_POSITION.map { |position| [ position.upcase, position ] } }
  filter :slot, as: :select, collection: -> { LineupSlot.slots.keys.map { |slot| [ slot.upcase.tr("_", "/"), slot ] } }
  filter :points
  filter :performance_owner_id_eq, as: :select, label: "Owner",
    collection: -> { Owner.order(:name).pluck(:name, :id) }
  filter :performance_game_season_year_eq, as: :number, label: "Season year"

  index do
    selectable_column
    id_column
    column :performance
    column("Slot", &:slot_label)
    column("Player", &:player_display_name)
    column("Positions") { |entry| entry.player_positions.map(&:upcase).join("/") }
    column :points
    column :sequence
    actions
  end

  show do
    attributes_table do
      row :performance
      row("Slot", &:slot_label)
      row :player_name
      row :player_nfl_team
      row("Positions") { |entry| entry.player_positions.map(&:upcase).join("/") }
      row :points
      row :sequence
      row("Counts toward the score", &:starter?)
      row("Could have been started", &:startable?)
    end
  end

  form do |f|
    f.inputs "Slot" do
      f.input :performance,
        collection: Performance.includes(:owner, game: :season).order(id: :desc)
          .map { |performance| [ performance.display_name, performance.id ] }
      f.input :slot, as: :select, include_blank: false,
        collection: LineupSlot.slots.keys.map { |slot| [ slot.upcase.tr("_", "/"), slot ] }
      f.input :points, hint: "Bench players carry what they would have scored — that is what makes a bad start measurable."
      f.input :sequence, hint: "The slot's place in the lineup, counting from 1."
    end

    f.inputs "Player" do
      f.input :player_name
      f.input :player_nfl_team, hint: "The NFL team they played for that week."
      f.input :player_positions, as: :string, input_html: { value: f.object.player_positions.join(", ") },
        hint: "Comma-separated, most-played first: #{LineupSlot::ANY_POSITION.join(', ')}"
    end

    f.actions
  end

  controller do
    include ListColumnParams

    private
      def resource_params
        super.each { |attributes| split_list_column(attributes, :player_positions) }
      end
  end
end
