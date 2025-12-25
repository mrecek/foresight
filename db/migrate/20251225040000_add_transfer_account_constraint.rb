class AddTransferAccountConstraint < ActiveRecord::Migration[8.1]
  def up
    # First, clean up any corrupt data that would violate the constraint
    # rule_type 2 = transfer
    corrupt_rules = RecurringRule.where(rule_type: 2)
                                 .where("account_id = destination_account_id")

    if corrupt_rules.any?
      Rails.logger.warn "Destroying #{corrupt_rules.count} corrupt transfer rules with same source/destination"
      corrupt_rules.destroy_all
    end

    # SQLite doesn't support adding CHECK constraints via ALTER TABLE.
    # Use a trigger to enforce the constraint at the database level.
    execute <<-SQL
      CREATE TRIGGER enforce_different_transfer_accounts_insert
      BEFORE INSERT ON recurring_rules
      WHEN NEW.rule_type = 2 AND NEW.account_id = NEW.destination_account_id
      BEGIN
        SELECT RAISE(ABORT, 'Transfer source and destination accounts must be different');
      END
    SQL

    execute <<-SQL
      CREATE TRIGGER enforce_different_transfer_accounts_update
      BEFORE UPDATE ON recurring_rules
      WHEN NEW.rule_type = 2 AND NEW.account_id = NEW.destination_account_id
      BEGIN
        SELECT RAISE(ABORT, 'Transfer source and destination accounts must be different');
      END
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS enforce_different_transfer_accounts_insert"
    execute "DROP TRIGGER IF EXISTS enforce_different_transfer_accounts_update"
  end
end
