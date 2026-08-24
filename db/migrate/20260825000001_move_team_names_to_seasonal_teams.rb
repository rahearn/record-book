class MoveTeamNamesToSeasonalTeams < ActiveRecord::Migration[8.1]
  def up
    create_table :teams do |t|
      t.references :owner, null: false, foreign_key: true
      t.references :season, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end
    add_index :teams, [ :owner_id, :season_id ], unique: true

    # Carry each owner's single team name into every season they played.
    execute <<~SQL
      INSERT INTO teams (owner_id, season_id, name, created_at, updated_at)
      SELECT DISTINCT p.owner_id, g.season_id, o.team_name, NOW(), NOW()
      FROM performances p
      JOIN games g ON g.id = p.game_id
      JOIN owners o ON o.id = p.owner_id
    SQL

    remove_column :owners, :team_name
  end

  def down
    add_column :owners, :team_name, :string
    execute <<~SQL
      UPDATE owners SET team_name = COALESCE((
        SELECT t.name FROM teams t
        JOIN seasons s ON s.id = t.season_id
        WHERE t.owner_id = owners.id
        ORDER BY s.year DESC LIMIT 1
      ), '')
    SQL
    change_column_null :owners, :team_name, false

    drop_table :teams
  end
end
