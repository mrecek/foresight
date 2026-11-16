# Financial edits share the paired-row transaction and audit boundary.
class TransactionChange
  EDITABLE_FIELDS = %w[account_id description amount date status category_id destination_account_id].freeze

  class << self
    def update(transaction, attributes:, audit_context:)
      values = attributes.to_h.stringify_keys.slice(*EDITABLE_FIELDS)
      normalize!(transaction, values)
      if transaction.linked_transaction.present? && transaction.amount.positive?
        invalid!(transaction, :base, "Review this transfer from its sending account before saving.")
      end

      if transaction.recurring_rule_id.present?
        original = transaction.original_date || transaction.date
        destination_changed = values.key?("destination_account_id") &&
          values["destination_account_id"] != transaction.linked_transaction&.account_id
        transaction.assign_attributes(values.except("destination_account_id"))
        if transaction.changed? || destination_changed
          values["user_modified"] = true
          if transaction.date_changed?
            values["original_date"] = transaction.date == original ? nil : original
          end
        end
      end

      TransferCommand.update(transaction, values) { |record| AuditLog.log_update(record, audit_context) }
    end

    def confirm_actual(transaction, amount:, audit_context:)
      entered = parse_amount!(transaction, amount).abs
      invalid!(transaction, :amount, "must be greater than zero") unless entered.positive?
      signed = transaction.amount.negative? ? -entered : entered
      TransferCommand.update(transaction, status: :actual, amount: signed, user_modified: true) do |record|
        AuditLog.log_update(record, audit_context)
      end
    end

    private

    def normalize!(transaction, values)
      values["amount"] = parse_amount!(transaction, values["amount"]) if values.key?("amount")
      values["date"] = FinancialInput.date!(transaction, values["date"]) if values.key?("date")
      if values.key?("status") && !Transaction.statuses.key?(values["status"].to_s)
        invalid!(transaction, :status, "is invalid")
      end
      { "account_id" => Account, "destination_account_id" => Account, "category_id" => Category }.each do |field, model|
        next unless values.key?(field)
        value = values[field]
        if value.blank? && field != "account_id"
          values[field] = nil
          next
        end
        begin
          id = Integer(value.to_s, 10)
        rescue ArgumentError
          invalid!(transaction, field, "is invalid")
        end
        invalid!(transaction, field, "is invalid") unless model.exists?(id)
        values[field] = id
      end
    end

    def parse_amount!(transaction, value)
      FinancialInput.money!(transaction, value)
    end

    def invalid!(transaction, field, message)
      transaction.errors.add(field, message)
      raise ActiveRecord::RecordInvalid, transaction
    end
  end
end
