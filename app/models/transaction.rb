class Transaction < ApplicationRecord
  enum :status, { estimated: 0, actual: 1 }

  belongs_to :account
  belongs_to :recurring_rule, optional: true
  belongs_to :linked_transaction, class_name: "Transaction", optional: true

  validates :description, presence: true
  validates :amount, presence: true, numericality: true
  validates :date, presence: true
  validates :status, presence: true
  validates :account, presence: true

  scope :upcoming, -> { where("date >= ?", Date.current).order(:date) }
  scope :in_attention_window, -> { where(date: Date.current..(Date.current + 30.days), status: :estimated) }
  scope :for_account, ->(account_id) { where(account_id: account_id) if account_id.present? }

  def one_time?
    recurring_rule.nil?
  end

  def transfer?
    linked_transaction.present?
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
    account.current_balance + account.transactions.where("date <= ?", date).where("date > ?", account.balance_date).sum(:amount)
  end
end
