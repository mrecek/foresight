class Account < ApplicationRecord
  enum :account_type, { checking: 0, savings: 1 }

  before_destroy :prevent_deletion_if_used_in_transfers

  has_many :transactions, dependent: :destroy
  has_many :recurring_rules, dependent: :destroy
  has_many :incoming_transfers, class_name: "RecurringRule", foreign_key: :destination_account_id, dependent: :nullify

  validates :name, presence: true
  validates :account_type, presence: true
  validates :current_balance, presence: true, numericality: true
  validates :balance_date, presence: true
  validates :warning_threshold, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :balance_date_not_in_future

  def projected_balance(as_of_date = nil)
    as_of_date ||= Setting.instance.default_view_months.months.from_now.to_date

    # Use already loaded transactions if available to avoid N+1
    if transactions.loaded?
      current_balance + transactions.select { |t| t.date >= balance_date && t.date <= as_of_date }.sum(&:amount)
    else
      current_balance + transactions.where(date: balance_date..as_of_date).sum(:amount)
    end
  end

  # Returns the lowest running balance in the projection period (forward-looking only)
  def lowest_projected_balance(end_date = nil)
    end_date ||= Setting.instance.default_view_months.months.from_now.to_date
    running = current_balance
    lowest = nil

    # Use already loaded transactions if available to avoid N+1
    txns = if transactions.loaded?
      transactions.select { |t| t.date >= balance_date && t.date <= end_date }.sort_by(&:date)
    else
      transactions.where(date: balance_date..end_date).order(:date)
    end

    txns.each do |txn|
      running += txn.amount
      if txn.date > Date.current
        lowest = running if lowest.nil? || running < lowest
      end
    end

    lowest || running
  end

  # Returns :normal, :warning, or :danger based on lowest projected balance
  def projection_status(end_date = nil)
    lowest = lowest_projected_balance(end_date)
    if lowest < 0
      :danger
    elsif lowest < warning_threshold
      :warning
    else
      :normal
    end
  end

  # Calculate running balances for a set of transactions
  def running_balances_for(txns)
    running = current_balance
    txns.map do |txn|
      running += txn.amount
      { transaction: txn, running_balance: running }
    end
  end

  private

  def balance_date_not_in_future
    if balance_date.present? && balance_date > Date.current
      errors.add(:balance_date, "cannot be in the future")
    end
  end

  def prevent_deletion_if_used_in_transfers
    # Check if this account is a source for any transfer rules
    source_transfer_count = recurring_rules.where(rule_type: :transfer).count

    # Check if this account is a destination for any transfer rules
    destination_transfer_count = RecurringRule.where(destination_account_id: id, rule_type: :transfer).count

    total_transfers = source_transfer_count + destination_transfer_count

    if total_transfers > 0
      errors.add(:base, "Cannot delete account because it is used in #{total_transfers} transfer rule#{'s' unless total_transfers == 1}. Delete or modify those rules first.")
      throw :abort
    end
  end
end
