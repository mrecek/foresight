class FixUniqueIndexForTransfers < ActiveRecord::Migration[8.1]
  def up
    # Remove the old index that only uses (recurring_rule_id, date)
    remove_index :transactions, name: "index_transactions_on_recurring_rule_and_date_unique"

    # Add new unique index that includes account_id
    # This allows transfers to have two transactions from the same rule on the same date
    # (one for source account, one for destination account)
    add_index :transactions, [ :recurring_rule_id, :account_id, :date ],
              unique: true,
              where: "recurring_rule_id IS NOT NULL",
              name: "index_transactions_on_rule_account_date_unique"
  end

  def down
    remove_index :transactions, name: "index_transactions_on_rule_account_date_unique"

    add_index :transactions, [ :recurring_rule_id, :date ],
              unique: true,
              where: "recurring_rule_id IS NOT NULL",
              name: "index_transactions_on_recurring_rule_and_date_unique"
  end
end
