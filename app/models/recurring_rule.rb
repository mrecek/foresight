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

  scope :active, -> { where(active: true) }

  private

  def different_accounts
    if account_id == destination_account_id
      errors.add(:destination_account_id, "must be different from the source account")
    end
  end
end
