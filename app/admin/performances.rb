ActiveAdmin.register Performance do
  menu parent: "Matchups", priority: 2

  permit_params :game_id, :owner_id, :points

  config.sort_order = "id_desc"

  filter :owner, collection: -> { Owner.order(:name) }
  filter :points
  filter :game_season_year_eq, as: :number, label: "Season year"
  filter :game_week_eq, as: :number, label: "Week"

  index do
    selectable_column
    id_column
    column :game
    column :owner, sortable: "owners.name"
    column :points
    column("Lineup slots") { |performance| performance.lineup_slots.size }
    column("Left on bench") { |performance| performance.points_left_on_bench }
    actions
  end

  show do
    attributes_table do
      row :game
      row :owner
      row :points
      row("Optimal points") { |performance| performance.optimal_points if performance.lineup? }
      row("Left on bench") { |performance| performance.points_left_on_bench }
    end

    # Slots are edited one at a time: autosaving a whole lineup from here would
    # validate every persisted slot against the rest, which a reshuffle trips.
    panel "Lineup" do
      table_for performance.lineup_slots.includes(:player) do
        column("#", &:sequence)
        column("Slot") { |entry| entry.slot.upcase.tr("_", "/") }
        column("Player") { |entry| link_to entry.player.display_name, admin_player_path(entry.player) }
        column("Points") { |entry| link_to entry.points, admin_lineup_slot_path(entry) }
      end
    end

    para link_to("Add a lineup slot", new_admin_lineup_slot_path(lineup_slot: { performance_id: performance.id }))
  end

  form do |f|
    f.inputs "Performance" do
      f.input :game, collection: Game.includes(:season).order(id: :desc).map { |game| [ game.display_name, game.id ] }
      f.input :owner, collection: Owner.order(:name)
      f.input :points
    end

    f.actions
  end
end
