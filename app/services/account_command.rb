class AccountCommand
  def self.destroy(account, &audit)
    Account.transaction do
      transfer_count = account.recurring_rules.where(rule_type: :transfer).count +
        RecurringRule.where(destination_account_id: account.id, rule_type: :transfer).count
      if transfer_count.positive?
        account.errors.add(:base, "Cannot delete account because it is used in #{transfer_count} transfer rule#{'s' unless transfer_count == 1}. Delete or modify those rules first.")
        return false
      end

      account.transactions.ids.each do |transaction_id|
        transaction = Transaction.find_by(id: transaction_id)
        TransferCommand.destroy(transaction, pair: false) if transaction
      end
      account.recurring_rules.ids.each do |rule_id|
        rule = RecurringRule.find_by(id: rule_id)
        RecurringRuleCommand.destroy(rule) if rule
      end
      audit&.call(account)
      account.destroy!
      true
    end
  end
end
