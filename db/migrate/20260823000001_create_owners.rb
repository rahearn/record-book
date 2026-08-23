class CreateOwners < ActiveRecord::Migration[8.1]
  def change
    create_table :owners do |t|
      t.string :name, null: false
      t.string :team_name, null: false

      t.timestamps
    end
    add_index :owners, :name, unique: true
  end
end
