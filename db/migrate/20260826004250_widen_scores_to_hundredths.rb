# The league has always scored to a hundredth of a point — a tenth was only
# ever enough for the demo data. Rounding real scores on the way in left a
# lineup's starters summing to within a few tenths of the score they were
# recorded against, instead of exactly.
class WidenScoresToHundredths < ActiveRecord::Migration[8.1]
  def up
    change_column :performances, :points, :decimal, precision: 6, scale: 2, null: false
    change_column :lineup_slots, :points, :decimal, precision: 6, scale: 2, null: false
  end

  # Going back rounds every score to a tenth, which is the precision the
  # column can hold; what it cannot do is put back what that discards.
  def down
    change_column :performances, :points, :decimal, precision: 6, scale: 1, null: false
    change_column :lineup_slots, :points, :decimal, precision: 6, scale: 1, null: false
  end
end
