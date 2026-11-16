class AccountReconciliation
  Result = Data.define(:account, :deleted_count)

  def self.call(account:, attributes:, include_today:, audit_context:)
    unless [ true, false ].include?(include_today)
      FinancialInput.invalid!(account, :base, "include_today must be a boolean")
    end
    values = attributes.to_h.stringify_keys
    balance = FinancialInput.money!(account, values["current_balance"], field: :current_balance)
    date = FinancialInput.date!(account, values["balance_date"], field: :balance_date)

    Account.transaction do
      account.update!(current_balance: balance, balance_date: date)
      scope = account.transactions.where(include_today ? "date <= ?" : "date < ?", date)
      ids = scope.ids
      ids.each do |id|
        transaction = Transaction.find_by(id: id)
        TransferCommand.destroy(transaction, pair: false) if transaction
      end
      AuditLog.log_update(account, audit_context)
      Result.new(account: account, deleted_count: ids.length)
    end
  end
end
