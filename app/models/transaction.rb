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

  attr_accessor :destination_account_id, :skip_transfer_callback

  scope :upcoming, -> { where("date >= ?", Date.current).order(:date) }
  scope :in_attention_window, -> { where(date: Date.current..(Date.current + 30.days), status: :estimated) }
  scope :for_account, ->(account_id) { where(account_id: account_id) if account_id.present? }

  after_save :manage_transfer, unless: :skip_transfer_callback

  def one_time?
    recurring_rule.nil?
  end

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

  before_destroy :unlink_transaction

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

  def unlink_transaction
    if linked_transaction
      linked_transaction.update_column(:linked_transaction_id, nil)
    end
  end

  def manage_transfer
    # Case 1: Explicit removal request (e.g. switched to Expense)
    # We use instance_variable_defined? to ensure we only act if the attribute was actually set on the object
    if instance_variable_defined?(:@destination_account_id) && @destination_account_id.blank?
      if linked_transaction
        linked_transaction.destroy!
        update_column(:linked_transaction_id, nil)
      end
      return
    end

    # Case 2: Determine if we need to process a transfer
    # We process if we have an explicit new destination OR an existing link to maintain
    target_account_id = if instance_variable_defined?(:@destination_account_id) && @destination_account_id.present?
                          @destination_account_id
    elsif linked_transaction
                          linked_transaction.account_id
    else
                          nil
    end

    return unless target_account_id

    # Case 3: Create or Update Linked Transaction
    linked = linked_transaction || Transaction.new(linked_transaction_id: id)

    linked.assign_attributes(
      account_id: target_account_id,
      amount: -amount,
      description: description,
      date: date,
      status: status,
      category_id: category_id
    )

    # Use skip_transfer_callback to prevent infinite recursion if we were to trigger saves on the other side
    # (Though currently the other side doesn't accidentally trigger a loop because it points back to this one?)
    # Ideally, we should set skip_transfer_callback on the LINKED transaction before saving it.
    linked.skip_transfer_callback = true

    if linked.save
      update_column(:linked_transaction_id, linked.id) if linked_transaction_id.nil?
    else
      errors.add(:base, "Linked transaction error: #{linked.errors.full_messages.join(', ')}")
      raise ActiveRecord::Rollback
    end
  end
end
