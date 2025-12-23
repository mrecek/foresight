class Account < ApplicationRecord
  enum :account_type, { checking: 0, savings: 1 }

  has_many :transactions, dependent: :destroy
  has_many :recurring_rules, dependent: :destroy
  has_many :incoming_transfers, class_name: "RecurringRule", foreign_key: :destination_account_id, dependent: :nullify

  validates :name, presence: true
  validates :account_type, presence: true
  validates :current_balance, presence: true, numericality: true
  validates :balance_date, presence: true
  validates :warning_threshold, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def projected_balance(as_of_date = nil)
    as_of_date ||= Setting.instance.default_view_months.months.from_now.to_date

    # Use already loaded transactions if available to avoid N+1
    if transactions.loaded?
      current_balance + transactions.select { |t| t.date >= balance_date && t.date <= as_of_date }.sum(&:amount)
    else
      current_balance + transactions.where(date: balance_date..as_of_date).sum(:amount)
    end
  end

  def transactions_in_range(start_date, end_date)
    transactions.where(date: start_date..end_date).order(:date)
  end

  # Returns the lowest running balance in the projection period
  def lowest_projected_balance(end_date = nil)
    end_date ||= Setting.instance.default_view_months.months.from_now.to_date
    running = current_balance
    lowest = current_balance

    # Use already loaded transactions if available to avoid N+1
    txns = if transactions.loaded?
      transactions.select { |t| t.date >= balance_date && t.date <= end_date }.sort_by(&:date)
    else
      transactions.where(date: balance_date..end_date).order(:date)
    end

    txns.each do |txn|
      running += txn.amount
      lowest = running if running < lowest
    end

    lowest
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
end
