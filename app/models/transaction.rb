class Transaction < ApplicationRecord
  enum :status, { estimated: 0, actual: 1 }

  belongs_to :account
  belongs_to :recurring_rule, optional: true
  belongs_to :linked_transaction, class_name: "Transaction", optional: true
  belongs_to :category, optional: true

  validates :description, presence: true
  validates :amount, presence: true, numericality: true
  validates :date, presence: true
  validates :status, presence: true
  validates :account, presence: true
  validate :different_linked_account, if: :transfer?

  attr_accessor :destination_account_id

  scope :upcoming, -> { where("date >= ?", Date.current).order(:date) }
  scope :in_attention_window, -> { where(date: Date.current..(Date.current + 30.days), status: :estimated) }
  scope :for_account, ->(account_id) { where(account_id: account_id) if account_id.present? }
  scope :not_user_modified, -> { where(user_modified: false) }

  def transfer?
    linked_transaction.present? || destination_account_id.present?
  end

  def formatted_amount
    formatted = ActiveSupport::NumberHelper.number_to_delimited(sprintf("%.2f", amount.to_f.abs), delimiter: ",")
    if amount.to_f >= 0
      "+$#{formatted}"
    else
      "-$#{formatted}"
    end
  end

  def running_balance
    # Use pre-computed value if available (set by controller for bulk operations)
    return @running_balance if defined?(@running_balance)
    # Fallback to calculation (should be avoided in bulk operations due to N+1)
    account.current_balance + account.transactions.where("date <= ?", date).where("date > ?", account.balance_date).sum(:amount)
  end

  def running_balance=(value)
    @running_balance = value
  end

  private

  def different_linked_account
    # Check against linked transaction if it exists
    if linked_transaction && account_id == linked_transaction.account_id
      errors.add(:destination_account_id, "cannot be the same as the source account")
    end

    # Check against destination_account_id if provided (creation/update context)
    if destination_account_id.present? && account_id == destination_account_id.to_i
      errors.add(:destination_account_id, "cannot be the same as the source account")
    end
  end
end
