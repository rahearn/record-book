class CreatePerformances < ActiveRecord::Migration[8.1]
  def change
    create_table :performances do |t|
      t.references :game, null: false, foreign_key: true
      t.references :owner, null: false, foreign_key: true
      t.decimal :points, precision: 6, scale: 1, null: false

      t.timestamps
    end
    add_index :performances, [ :game_id, :owner_id ], unique: true
  end
end
