class AllowPlayersMultiplePositions < ActiveRecord::Migration[8.1]
  POSITIONS = %w[qb rb wr te k dst].freeze

  def up
    add_column :players, :positions, :string, array: true, null: false, default: []
    POSITIONS.each_with_index do |name, value|
      execute "UPDATE players SET positions = ARRAY['#{name}'] WHERE position = #{value}"
    end
    remove_index :players, column: [ :position, :name, :nfl_team ], unique: true
    remove_column :players, :position

    # A player is who they played for, not what they played: eligibility can
    # change without making them somebody else.
    add_index :players, [ :name, :nfl_team ], unique: true
  end

  def down
    add_column :players, :position, :integer, null: false, default: 0
    POSITIONS.each_with_index do |name, value|
      execute "UPDATE players SET position = #{value} WHERE positions[1] = '#{name}'"
    end
    remove_index :players, column: [ :name, :nfl_team ], unique: true
    remove_column :players, :positions
    add_index :players, [ :position, :name, :nfl_team ], unique: true
  end
end
