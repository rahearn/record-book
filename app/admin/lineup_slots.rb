# Lineups are normally entered whole from the performance they belong to, since
# Performance holds them to the season's roster format. This resource is for
# looking one up and correcting it in place.
ActiveAdmin.register LineupSlot do
  menu parent: "Lineups", priority: 2

  permit_params :performance_id, :player_id, :slot, :points, :sequence

  config.sort_order = "id_desc"

  filter :player, collection: -> { Player.order(:name).map { |player| [ player.display_name, player.id ] } }
  filter :slot, as: :select, collection: -> { LineupSlot.slots.keys.map { |slot| [ slot.upcase.tr("_", "/"), slot ] } }
  filter :points
  filter :performance_owner_id_eq, as: :select, label: "Owner",
    collection: -> { Owner.order(:name).pluck(:name, :id) }
  filter :performance_game_season_year_eq, as: :number, label: "Season year"

  index do
    selectable_column
    id_column
    column :performance
    column("Slot") { |entry| entry.slot.upcase.tr("_", "/") }
    column :player
    column :points
    column :sequence
    actions
  end

  show do
    attributes_table do
      row :performance
      row("Slot") { |entry| entry.slot.upcase.tr("_", "/") }
      row :player
      row :points
      row :sequence
      row("Counts toward the score") { |entry| entry.starter? }
      row("Could have been started") { |entry| entry.startable? }
    end
  end

  form do |f|
    f.inputs do
      f.input :performance,
        collection: Performance.includes(:owner, game: :season).order(id: :desc)
          .map { |performance| [ performance.display_name, performance.id ] }
      f.input :slot, as: :select, include_blank: false,
        collection: LineupSlot.slots.keys.map { |slot| [ slot.upcase.tr("_", "/"), slot ] }
      f.input :player, collection: Player.order(:name).map { |player| [ player.display_name, player.id ] }
      f.input :points, hint: "Bench players carry what they would have scored — that is what makes a bad start measurable."
      f.input :sequence, hint: "The slot's place in the lineup, counting from 1."
    end
    f.actions
  end
end
