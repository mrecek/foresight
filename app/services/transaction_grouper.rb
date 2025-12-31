# TransactionGrouper Service
#
# Transforms a flat list of transactions with balances into a mixed list of
# individual items and grouped items for consecutive transactions from the
# same recurring rule.
#
# Grouping criteria:
# - Same recurring_rule_id (must have a rule)
# - High-frequency rule (daily, weekly, biweekly, semimonthly)
# - Same status (estimated/actual)
# - Consecutive in the sorted list (no other transactions in between)
# - 3 or more transactions
#
class TransactionGrouper
  # Represents a group of consecutive transactions
  TransactionGroup = Struct.new(
    :recurring_rule,
    :transactions,
    :first_date,
    :last_date,
    :total_amount,
    :ending_balance,
    :status,
    :count,
    :category,
    keyword_init: true
  ) do
    def group?
      true
    end
  end

  # Wrapper for individual transactions to have consistent interface
  class SingleTransaction
    attr_reader :transaction, :running_balance

    def initialize(item)
      @transaction = item[:transaction]
      @running_balance = item[:running_balance]
    end

    def group?
      false
    end
  end

  def initialize(transactions_with_balances)
    @transactions = transactions_with_balances
  end

  def call
    return [] if @transactions.empty?

    result = []
    current_group = []

    @transactions.each do |item|
      txn = item[:transaction]

      if can_group?(txn) && continues_group?(current_group, txn)
        # Add to current group
        current_group << item
      else
        # Flush current group and start fresh
        flush_group(current_group, result)
        current_group = can_group?(txn) ? [ item ] : []

        # If transaction can't be grouped, add it directly
        result << SingleTransaction.new(item) unless can_group?(txn)
      end
    end

    # Flush any remaining group
    flush_group(current_group, result)

    result
  end

  private

  def can_group?(txn)
    return false unless txn.recurring_rule_id.present?
    return false unless high_frequency_rule?(txn)
    true
  end

  def high_frequency_rule?(txn)
    return true unless txn.recurring_rule # Safe default if not loaded

    # Only group high-frequency rules (more frequent than monthly)
    # Exclude: monthly, monthly_last, quarterly, biyearly, yearly
    %w[daily weekly biweekly semimonthly].include?(txn.recurring_rule.frequency)
  end

  def continues_group?(group, txn)
    return false if group.empty?
    return false if crosses_today_boundary?(group, txn)

    first_txn = group.first[:transaction]

    first_txn.recurring_rule_id == txn.recurring_rule_id &&
      first_txn.status == txn.status
  end

  def crosses_today_boundary?(group, txn)
    first_date = group.first[:transaction].date
    first_date < Date.current && txn.date >= Date.current
  end

  def flush_group(group, result)
    return if group.empty?

    if group.size >= 3
      # Create a TransactionGroup
      result << build_group(group)
    else
      # Add individually
      group.each { |item| result << SingleTransaction.new(item) }
    end
  end

  def build_group(items)
    first_item = items.first
    last_item = items.last
    first_txn = first_item[:transaction]

    TransactionGroup.new(
      recurring_rule: first_txn.recurring_rule,
      transactions: items,
      first_date: first_txn.date,
      last_date: last_item[:transaction].date,
      total_amount: items.sum { |i| i[:transaction].amount },
      ending_balance: last_item[:running_balance],
      status: first_txn.status,
      count: items.size,
      category: first_txn.category
    )
  end
end
