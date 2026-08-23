class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.references :season, null: false, foreign_key: true
      t.integer :week, null: false
      t.integer :tier, null: false, default: 0

      t.timestamps
    end
    add_index :games, [ :season_id, :week ]
  end
end
