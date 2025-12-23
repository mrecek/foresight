class AddUniqueIndexToTransactionsForRecurringRule < ActiveRecord::Migration[8.1]
  def up
    # First, unlink any linked transactions that will be deleted
    execute <<-SQL
      UPDATE transactions
      SET linked_transaction_id = NULL
      WHERE linked_transaction_id IN (
        SELECT id FROM transactions
        WHERE id NOT IN (
          SELECT MIN(id)
          FROM transactions
          WHERE recurring_rule_id IS NOT NULL
          GROUP BY recurring_rule_id, date
        )
        AND recurring_rule_id IS NOT NULL
      )
    SQL

    # Then remove duplicate transactions keeping only the oldest one
    execute <<-SQL
      DELETE FROM transactions
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM transactions
        WHERE recurring_rule_id IS NOT NULL
        GROUP BY recurring_rule_id, date
      )
      AND recurring_rule_id IS NOT NULL
    SQL

    # Then add the unique index
    add_index :transactions, [ :recurring_rule_id, :date ],
              unique: true,
              where: "recurring_rule_id IS NOT NULL",
              name: "index_transactions_on_recurring_rule_and_date_unique"
  end

  def down
    remove_index :transactions, name: "index_transactions_on_recurring_rule_and_date_unique"
  end
end
