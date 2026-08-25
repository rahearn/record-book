ActiveAdmin.register Game do
  menu parent: "Matchups", priority: 1

  permit_params :season_id, :week, :tier, :round_name,
    performances_attributes: [ :id, :owner_id, :points, :_destroy ]

  config.sort_order = "id_desc"

  filter :season, collection: -> { Season.chronological.reverse }
  filter :week
  filter :tier, as: :select, collection: -> { Game.tiers.keys.map { |tier| [ tier.titleize, tier ] } }
  filter :round_name
  filter :owners, collection: -> { Owner.order(:name) }

  scope :all, default: true
  scope :regular_season
  scope :playoff

  index do
    selectable_column
    id_column
    column :season, sortable: "seasons.year"
    column :week
    column("Tier") { |game| status_tag game.tier.titleize }
    column("Round") { |game| game.round_name || "Regular season" }
    column("Result") do |game|
      game.performances.map { |performance| "#{performance.owner.name} #{performance.points}" }.join(" vs ")
    end
    actions
  end

  show do
    attributes_table do
      row :season
      row :week
      row("Tier") { |game| game.tier.titleize }
      row("Round") { |game| game.round_name || "Regular season" }
    end

    panel "Performances" do
      table_for game.performances.includes(:owner) do
        column("Owner") { |performance| link_to performance.owner.name, admin_owner_path(performance.owner) }
        column("Points") { |performance| link_to performance.points, admin_performance_path(performance) }
        column("Lineup") { |performance| performance.lineup_slots.size }
      end
    end
  end

  form do |f|
    f.inputs "Game" do
      f.input :season, collection: Season.chronological.reverse
      f.input :week
      f.input :tier, as: :select, collection: Game.tiers.keys.map { |tier| [ tier.titleize, tier ] },
        include_blank: false
      f.input :round_name, hint: "Blank for a regular-season game. " \
        "#{Game::CHAMPIONSHIP}, #{Game::THIRD_PLACE} and #{Game::SEMIFINAL} carry rules; other names are free text."
    end

    f.inputs "Performances" do
      f.has_many :performances, allow_destroy: true, new_record: "Add performance" do |performance|
        performance.input :owner, collection: Owner.order(:name)
        performance.input :points
      end
    end

    f.actions
  end
end
