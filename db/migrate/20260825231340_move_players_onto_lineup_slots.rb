# A shared Player row could only ever hold one NFL team and one set of
# eligible positions, but both move — within a season as much as between
# them. The lineup slot already records one week of one roster, so it is the
# only place either fact is actually true.
class MovePlayersOntoLineupSlots < ActiveRecord::Migration[8.1]
  def up
    add_column :lineup_slots, :player_name, :string
    add_column :lineup_slots, :player_nfl_team, :string
    add_column :lineup_slots, :player_positions, :string, array: true, null: false, default: []

    execute <<~SQL
      UPDATE lineup_slots
         SET player_name = players.name,
             player_nfl_team = players.nfl_team,
             player_positions = players.positions
        FROM players
       WHERE players.id = lineup_slots.player_id
    SQL

    change_column_null :lineup_slots, :player_name, false
    change_column_null :lineup_slots, :player_nfl_team, false

    remove_reference :lineup_slots, :player, foreign_key: true
    drop_table :players
  end

  def down
    create_table :players do |t|
      t.string :name, null: false
      t.string :nfl_team, null: false
      t.string :positions, array: true, null: false, default: []
      t.timestamps
    end
    add_index :players, [ :name, :nfl_team ], unique: true

    # Going back collapses each name and team down to one set of positions,
    # since that is all the old shape could hold.
    execute <<~SQL
      INSERT INTO players (name, nfl_team, positions, created_at, updated_at)
      SELECT DISTINCT ON (player_name, player_nfl_team)
             player_name, player_nfl_team, player_positions, NOW(), NOW()
        FROM lineup_slots
       ORDER BY player_name, player_nfl_team
    SQL

    add_reference :lineup_slots, :player, foreign_key: true
    execute <<~SQL
      UPDATE lineup_slots
         SET player_id = players.id
        FROM players
       WHERE players.name = lineup_slots.player_name
         AND players.nfl_team = lineup_slots.player_nfl_team
    SQL
    change_column_null :lineup_slots, :player_id, false

    remove_column :lineup_slots, :player_name
    remove_column :lineup_slots, :player_nfl_team
    remove_column :lineup_slots, :player_positions
  end
end
