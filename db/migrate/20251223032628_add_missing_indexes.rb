class AddMissingIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :recurring_rules, :destination_account_id
    add_index :transactions, :linked_transaction_id
    add_index :transactions, [ :account_id, :date ]
  end
end
