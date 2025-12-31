class RecurringRule < ApplicationRecord
  enum :rule_type, { income: 0, expense: 1, transfer: 2 }
  enum :frequency, { daily: 5, weekly: 0, biweekly: 1, semimonthly: 2, monthly: 3, monthly_last: 8, quarterly: 6, biyearly: 4, yearly: 7 }

  belongs_to :account
  belongs_to :destination_account, class_name: "Account", optional: true
  belongs_to :category, optional: true
  has_many :transactions, dependent: :destroy

  validates :description, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :rule_type, presence: true
  validates :frequency, presence: true
  validates :anchor_date, presence: true
  validates :destination_account, presence: true, if: :transfer?
  validate :different_accounts, if: :transfer?
  validates :day_of_month, inclusion: { in: 1..31, allow_nil: true }
  validates :day_of_week, inclusion: { in: 0..6, allow_nil: true }

  after_create :generate_initial_transactions
  after_update :regenerate_transactions, if: :schedule_changed?
  after_update :update_future_transactions_category, if: :saved_change_to_category_id?

  scope :active, -> { where(active: true) }

  # Class method to extend projections for multiple rules
  def self.extend_all_projections_to(end_date, account: nil)
    scope = if account
      # Include rules where account is the source OR the destination (for transfers)
      where(account: account).or(where(destination_account: account))
    else
      all
    end

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

    # Skip dates where user has modified transactions AND original dates (where transactions were moved FROM)
    skip_dates = dates_to_skip

    dates.each do |date|
      next if skip_dates.include?(date)
      create_transaction_for_date(date)
    end
  end

  def generate_transactions(end_date = nil)
    end_date ||= Setting.instance.default_view_months.months.from_now.to_date
    dates = RecurrenceCalculator.new(self).dates_until(end_date)

    # Skip dates where user has modified transactions AND original dates (where transactions were moved FROM)
    skip_dates = dates_to_skip

    dates.each do |date|
      next if skip_dates.include?(date)
      create_transaction_for_date(date)
    end
  end

  def dates_to_skip
    existing_modified_dates = transactions.where(user_modified: true).pluck(:date).to_set
    original_dates = transactions.where.not(original_date: nil).pluck(:original_date).to_set
    existing_modified_dates | original_dates
  end

  def regenerate_transactions
    # Preserve user-modified transactions, only regenerate auto-generated ones
    transactions.not_user_modified.where("date >= ?", Date.current).destroy_all
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
    # NOTE: category_id changes are handled separately via update_future_transactions_category
  end

  def update_future_transactions_category
    # Skip if schedule also changed (transactions already regenerated)
    return if schedule_changed?
    # Only update category on future estimated transactions, don't regenerate
    transactions.where("date >= ?", Date.current).update_all(category_id: category_id)
  end

  def different_accounts
    if account_id == destination_account_id
      errors.add(:destination_account_id, "must be different from the source account")
    end
  end

  def create_transaction_for_date(date)
    # Guard: Skip if this is an invalid transfer (same source/destination)
    if transfer? && destination_account_id == account_id
      Rails.logger.warn "Skipping invalid transfer rule #{id}: source and destination are the same"
      return
    end

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
        status: is_estimated? ? :estimated : :actual,
        category: category
      )

      if transfer? && destination_account
        linked_txn = transactions.create!(
          account: destination_account,
          description: description,
          amount: amount,
          date: date,
          status: is_estimated? ? :estimated : :actual,
          linked_transaction_id: txn.id,
          category: category
        )
        txn.update!(linked_transaction_id: linked_txn.id)
      end
    end
  rescue ActiveRecord::RecordNotUnique
    # Transaction already exists for this date (race condition handled by unique index)
    nil
  end
end
