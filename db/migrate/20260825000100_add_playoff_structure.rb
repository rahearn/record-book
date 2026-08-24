class AddPlayoffStructure < ActiveRecord::Migration[8.1]
  def change
    # Playoff games carry a round name (e.g. "Semifinal"); regular-season
    # games do not.
    add_column :games, :round_name, :string

    # How many teams make the playoffs and which week they start — configured
    # per season and tier, since Premier and Challenger differ and both have
    # changed over the league's history.
    create_table :playoff_formats do |t|
      t.references :season, null: false, foreign_key: true
      t.integer :tier, null: false, default: 0
      t.integer :team_count, null: false
      t.integer :start_week, null: false

      t.timestamps
    end
    add_index :playoff_formats, [ :season_id, :tier ], unique: true
  end
end
