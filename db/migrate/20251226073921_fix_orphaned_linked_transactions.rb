class FixOrphanedLinkedTransactions < ActiveRecord::Migration[8.1]
  def up
    say_with_time "Fixing orphaned linked transaction references" do
      orphaned_count = execute(<<-SQL).to_a.first["count"]
        SELECT COUNT(*) as count
        FROM transactions t1
        WHERE t1.linked_transaction_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM transactions t2
            WHERE t2.id = t1.linked_transaction_id
          )
      SQL

      if orphaned_count.to_i > 0
        execute <<-SQL
          UPDATE transactions
          SET linked_transaction_id = NULL
          WHERE linked_transaction_id IS NOT NULL
            AND NOT EXISTS (
              SELECT 1 FROM transactions t2
              WHERE t2.id = transactions.linked_transaction_id
            )
        SQL
        say "Fixed #{orphaned_count} orphaned reference(s)"
      else
        say "No orphaned references found"
      end

      orphaned_count
    end
  end

  def down
    say "Cannot reverse orphaned reference cleanup"
  end
end
