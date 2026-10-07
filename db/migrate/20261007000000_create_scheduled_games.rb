class CreateScheduledGames < ActiveRecord::Migration[8.1]
  def change
    # The regular-season matchups of a season still being played that have
    # not been played yet. A game only reaches the games table once it has
    # scores, so the rest of the schedule waits here; the importer clears a
    # week out of it as the week is played.
    create_table :scheduled_games do |t|
      t.references :season, null: false, foreign_key: true
      t.integer :week, null: false
      t.integer :tier, null: false, default: 0
      t.references :owner_a, null: false, foreign_key: { to_table: :owners }
      t.references :owner_b, null: false, foreign_key: { to_table: :owners }

      t.timestamps
    end
    add_index :scheduled_games, [ :season_id, :week ]
  end
end
