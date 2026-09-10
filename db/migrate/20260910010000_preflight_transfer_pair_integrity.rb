class PreflightTransferPairIntegrity < ActiveRecord::Migration[8.1]
  def up
    count = select_value(<<~SQL).to_i
      SELECT COUNT(*)
      FROM transactions left_side
      LEFT JOIN transactions right_side ON right_side.id = left_side.linked_transaction_id
      WHERE left_side.linked_transaction_id IS NOT NULL
        AND (
          left_side.id = left_side.linked_transaction_id OR
          right_side.id IS NULL OR
          right_side.linked_transaction_id IS NOT left_side.id OR
          left_side.account_id = right_side.account_id OR
          left_side.amount IS NOT -right_side.amount OR
          left_side.description IS NOT right_side.description OR
          left_side.date IS NOT right_side.date OR
          left_side.status IS NOT right_side.status OR
          left_side.category_id IS NOT right_side.category_id OR
          left_side.recurring_rule_id IS NOT right_side.recurring_rule_id OR
          left_side.user_modified IS NOT right_side.user_modified OR
          left_side.original_date IS NOT right_side.original_date OR
          (SELECT COUNT(*) FROM transactions incoming WHERE incoming.linked_transaction_id = right_side.id) > 1
        )
    SQL
    return if count.zero?

    raise ActiveRecord::MigrationError, "Found #{count} invalid transfer link(s). Run bin/transfers --repair, review its report, and retry migration."
  end

  def down; end
end
