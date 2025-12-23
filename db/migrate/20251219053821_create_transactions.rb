class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :recurring_rule, foreign_key: true
      t.integer :linked_transaction_id
      t.string :description, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date :date, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :transactions, :date
    add_foreign_key :transactions, :transactions, column: :linked_transaction_id
  end
end
