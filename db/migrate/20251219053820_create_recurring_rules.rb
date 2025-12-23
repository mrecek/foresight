class CreateRecurringRules < ActiveRecord::Migration[8.1]
  def change
    create_table :recurring_rules do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :destination_account_id
      t.integer :rule_type, null: false, default: 0
      t.string :description, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.integer :frequency, null: false, default: 0
      t.date :anchor_date, null: false
      t.integer :day_of_month
      t.integer :day_of_week
      t.boolean :is_estimated, null: false, default: true
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_foreign_key :recurring_rules, :accounts, column: :destination_account_id
  end
end
