class CreateOccurrenceExclusions < ActiveRecord::Migration[8.1]
  def change
    create_table :occurrence_exclusions do |t|
      t.references :recurring_rule, null: false, foreign_key: true
      t.date :date, null: false
      t.timestamps
    end
    add_index :occurrence_exclusions, [ :recurring_rule_id, :date ], unique: true
  end
end
