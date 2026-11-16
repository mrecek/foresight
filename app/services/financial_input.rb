# Exact boundary parsing for persisted financial amounts and calendar dates.
module FinancialInput
  def self.money!(record, value, field: :amount)
    text = value.is_a?(BigDecimal) ? value.to_s("F") : value.to_s
    # decimal(12,2): ten whole digits and at most two fractional digits.
    invalid!(record, field, "must be a finite decimal with at most two decimal places") unless
      text.match?(/\A[+-]?\d{1,10}(?:\.\d{1,2})?\z/)
    BigDecimal(text)
  end

  def self.date!(record, value, field: :date)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    invalid!(record, field, "must be a valid ISO date")
  end

  def self.invalid!(record, field, message)
    record.errors.add(field, message)
    raise ActiveRecord::RecordInvalid, record
  end
end
