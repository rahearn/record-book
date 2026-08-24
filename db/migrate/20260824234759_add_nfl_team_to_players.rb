class AddNflTeamToPlayers < ActiveRecord::Migration[8.1]
  def change
    # Demo players predate the column, so they land as free agents until the
    # next reseed — a value that stays useful for genuinely unrostered players.
    add_column :players, :nfl_team, :string, null: false, default: "FA"
    change_column_default :players, :nfl_team, from: "FA", to: nil

    # Two players can share a name and a position as long as they play for
    # different teams.
    remove_index :players, column: [ :position, :name ], unique: true
    add_index :players, [ :position, :name, :nfl_team ], unique: true
  end
end
