class CreateRosterFormats < ActiveRecord::Migration[8.1]
  def change
    create_table :roster_formats do |t|
      t.references :season, null: false, foreign_key: true, index: { unique: true }
      t.string :slots, array: true, null: false, default: []

      t.timestamps
    end
  end
end
