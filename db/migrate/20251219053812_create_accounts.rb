class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.integer :account_type, null: false, default: 0
      t.decimal :current_balance, precision: 12, scale: 2, null: false, default: 0
      t.date :balance_date, null: false

      t.timestamps
    end
  end
end
