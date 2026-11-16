class PreserveTransferAccountConstraint < ActiveRecord::Migration[8.1]
  NAME = "recurring_rules_different_transfer_accounts"

  def up
    invalid_count = select_value(<<~SQL).to_i
      SELECT COUNT(*) FROM recurring_rules
      WHERE rule_type = 2 AND account_id = destination_account_id
    SQL
    if invalid_count.positive?
      raise ActiveRecord::MigrationError,
        "Cannot install transfer protection: #{invalid_count} recurring rules use the same source and destination. Review those records before migrating."
    end

    # Rails includes CHECK constraints in schema.rb; schema loading omits SQL triggers.
    add_check_constraint :recurring_rules,
      "rule_type != 2 OR account_id != destination_account_id", name: NAME
    %w[insert update].each do |operation|
      execute "DROP TRIGGER IF EXISTS enforce_different_transfer_accounts_#{operation}"
    end
  end

  def down
    remove_check_constraint :recurring_rules, name: NAME
    %w[insert update].each do |operation|
      execute <<~SQL
        CREATE TRIGGER enforce_different_transfer_accounts_#{operation}
        BEFORE #{operation.upcase} ON recurring_rules
        WHEN NEW.rule_type = 2 AND NEW.account_id = NEW.destination_account_id
        BEGIN
          SELECT RAISE(ABORT, 'Transfer source and destination accounts must be different');
        END
      SQL
    end
  end
end
