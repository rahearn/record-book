class AddMatchupLineups < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :players, [ :position, :name ], unique: true

    create_table :lineup_slots do |t|
      t.references :performance, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.integer :slot, null: false, default: 0
      t.integer :sequence, null: false
      t.decimal :points, precision: 6, scale: 1, null: false

      t.timestamps
    end
    add_index :lineup_slots, [ :performance_id, :sequence ], unique: true
  end
end
