class AddOriginalDateToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :original_date, :date
    add_index :transactions, [ :recurring_rule_id, :original_date ],
              where: "original_date IS NOT NULL",
              name: "index_transactions_on_rule_and_original_date"
  end
end
