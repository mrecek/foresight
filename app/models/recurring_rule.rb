class RecurringRule < ApplicationRecord
  enum :rule_type, { income: 0, expense: 1, transfer: 2 }
  enum :frequency, { daily: 5, weekly: 0, biweekly: 1, semimonthly: 2, monthly: 3, monthly_last: 8, quarterly: 6, biyearly: 4, yearly: 7 }

  belongs_to :account
  belongs_to :destination_account, class_name: "Account", optional: true
  has_many :transactions, dependent: :destroy

  validates :description, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :rule_type, presence: true
  validates :frequency, presence: true
  validates :anchor_date, presence: true
  validates :destination_account, presence: true, if: :transfer?
  validates :day_of_month, inclusion: { in: 1..31, allow_nil: true }
  validates :day_of_week, inclusion: { in: 0..6, allow_nil: true }

  after_create :generate_initial_transactions
  after_update :regenerate_transactions, if: :schedule_changed?

  scope :active, -> { where(active: true) }

  # Class method to extend projections for multiple rules
  def self.extend_all_projections_to(end_date, account: nil)
    scope = account ? where(account: account) : all
    scope.find_each do |rule|
      rule.extend_projections_to(end_date)
    end
  end

  # Extend projections to a new end date (idempotent - only generates missing transactions)
  def extend_projections_to(end_date)
    latest_existing = transactions.maximum(:date)

    # Already have transactions up to or past this date
    return if latest_existing && latest_existing >= end_date

    # Calculate new dates starting after the latest existing
    start_from = if latest_existing
      latest_existing + 1.day
    else
      [ anchor_date, Date.current ].max
    end

    dates = RecurrenceCalculator.new(self).dates_between(start_from, end_date)
    dates.each { |date| create_transaction_for_date(date) }
  end

  def generate_transactions(end_date = nil)
    end_date ||= Setting.instance.default_view_months.months.from_now.to_date
    dates = RecurrenceCalculator.new(self).dates_until(end_date)

    dates.each do |date|
      create_transaction_for_date(date)
    end
  end

  def regenerate_transactions
    future_transactions = transactions.where("date >= ?", Date.current)

    # If is_estimated changed, update status of all future transactions
    if saved_change_to_is_estimated?
      new_status = is_estimated? ? :estimated : :actual
      future_transactions.update_all(status: new_status)
    end

    # Regenerate future estimated transactions (schedule/amount changes)
    future_transactions.where(status: :estimated).destroy_all
    generate_transactions
  end

  private

  def generate_initial_transactions
    generate_transactions
  end

  def schedule_changed?
    saved_change_to_frequency? || saved_change_to_anchor_date? ||
      saved_change_to_day_of_month? || saved_change_to_day_of_week? ||
      saved_change_to_amount? || saved_change_to_rule_type? ||
      saved_change_to_account_id? || saved_change_to_destination_account_id? ||
      saved_change_to_is_estimated?
  end

  def create_transaction_for_date(date)
    signed_amount = case rule_type
    when "income" then amount
    when "expense" then -amount
    when "transfer" then -amount
    end

    ActiveRecord::Base.transaction do
      txn = transactions.create!(
        account: account,
        description: description,
        amount: signed_amount,
        date: date,
        status: is_estimated? ? :estimated : :actual
      )

      if transfer? && destination_account
        linked_txn = transactions.create!(
          account: destination_account,
          description: description,
          amount: amount,
          date: date,
          status: is_estimated? ? :estimated : :actual,
          linked_transaction_id: txn.id
        )
        txn.update!(linked_transaction_id: linked_txn.id)
      end
    end
  rescue ActiveRecord::RecordNotUnique
    # Transaction already exists for this date (race condition handled by unique index)
    nil
  end
end
