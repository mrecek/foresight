require "test_helper"

class AccountTest < ActiveSupport::TestCase
  def setup
    @checking = Account.new(
      name: "Checking",
      account_type: :checking,
      current_balance: 1000.0,
      balance_date: Date.current,
      warning_threshold: 300.0
    )

    @savings = Account.new(
      name: "Savings",
      account_type: :savings,
      current_balance: 5000.0,
      balance_date: Date.current,
      warning_threshold: 1000.0
    )
  end

  # ============================================================================
  # Validation Tests
  # ============================================================================

  test "valid account with required fields" do
    assert @checking.valid?
  end

  test "requires name" do
    @checking.name = nil
    assert_not @checking.valid?
    assert_includes @checking.errors[:name], "can't be blank"
  end

  test "requires account_type" do
    @checking.account_type = nil
    assert_not @checking.valid?
    assert_includes @checking.errors[:account_type], "can't be blank"
  end

  test "requires current_balance" do
    @checking.current_balance = nil
    assert_not @checking.valid?
    assert_includes @checking.errors[:current_balance], "can't be blank"
  end

  test "current_balance must be numeric" do
    @checking.current_balance = "not a number"
    assert_not @checking.valid?
    assert_includes @checking.errors[:current_balance], "is not a number"
  end

  test "requires balance_date" do
    @checking.balance_date = nil
    assert_not @checking.valid?
    assert_includes @checking.errors[:balance_date], "can't be blank"
  end

  test "balance_date cannot be in future" do
    @checking.balance_date = Date.current + 1.day
    assert_not @checking.valid?
    assert_includes @checking.errors[:balance_date], "cannot be in the future"
  end

  test "balance_date can be today" do
    @checking.balance_date = Date.current
    assert @checking.valid?
  end

  test "balance_date can be in past" do
    @checking.balance_date = Date.current - 5.days
    assert @checking.valid?
  end

  test "requires warning_threshold" do
    @checking.warning_threshold = nil
    assert_not @checking.valid?
    assert_includes @checking.errors[:warning_threshold], "can't be blank"
  end

  test "warning_threshold must be numeric" do
    @checking.warning_threshold = "not a number"
    assert_not @checking.valid?
    assert_includes @checking.errors[:warning_threshold], "is not a number"
  end

  test "warning_threshold must be non-negative" do
    @checking.warning_threshold = -1
    assert_not @checking.valid?
    assert_includes @checking.errors[:warning_threshold], "must be greater than or equal to 0"
  end

  test "warning_threshold can be zero" do
    @checking.warning_threshold = 0
    assert @checking.valid?
  end

  # ============================================================================
  # Enum Tests
  # ============================================================================

  test "account_type enum works correctly" do
    @checking.save!
    assert @checking.checking?
    assert_not @checking.savings?

    @checking.update!(account_type: :savings)
    assert @checking.savings?
    assert_not @checking.checking?
  end

  # ============================================================================
  # Association Tests
  # ============================================================================

  test "has many transactions dependent destroy" do
    @checking.save!

    txn1 = Transaction.create!(
      account: @checking,
      description: "T1",
      amount: -100.0,
      date: Date.current,
      status: :estimated
    )

    txn2 = Transaction.create!(
      account: @checking,
      description: "T2",
      amount: -50.0,
      date: Date.current,
      status: :estimated
    )

    assert_equal 2, @checking.transactions.count

    @checking.destroy

    assert_not Transaction.exists?(txn1.id)
    assert_not Transaction.exists?(txn2.id)
  end

  test "has many recurring_rules dependent destroy" do
    @checking.save!

    rule1 = RecurringRule.create!(
      account: @checking,
      description: "Rule 1",
      amount: 100.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current
    )

    rule2 = RecurringRule.create!(
      account: @checking,
      description: "Rule 2",
      amount: 50.0,
      rule_type: :income,
      frequency: :monthly,
      anchor_date: Date.current
    )

    assert_equal 2, @checking.recurring_rules.count

    @checking.destroy

    assert_not RecurringRule.exists?(rule1.id)
    assert_not RecurringRule.exists?(rule2.id)
  end

  test "CRITICAL: cannot delete account used as transfer source (Issue 3)" do
    @checking.save!
    @savings.save!

    # Create transfer rule FROM checking TO savings
    transfer_rule = RecurringRule.create!(
      account: @checking,
      destination_account: @savings,
      description: "Transfer to Savings",
      amount: 500.0,
      rule_type: :transfer,
      frequency: :monthly,
      anchor_date: Date.current
    )

    result = @checking.destroy

    assert_not result, "Destroy should return false"
    assert @checking.errors[:base].present?, "Should have error message"
    assert_includes @checking.errors[:base].first, "Cannot delete account because it is used in"
    assert_includes @checking.errors[:base].first, "transfer rule"
    assert Account.exists?(@checking.id), "Account should still exist"
  end

  test "CRITICAL: cannot delete account used as transfer destination (Issue 3)" do
    @checking.save!
    @savings.save!

    # Create transfer rule FROM checking TO savings
    transfer_rule = RecurringRule.create!(
      account: @checking,
      destination_account: @savings,
      description: "Transfer to Savings",
      amount: 500.0,
      rule_type: :transfer,
      frequency: :monthly,
      anchor_date: Date.current
    )

    result = @savings.destroy

    assert_not result, "Destroy should return false"
    assert @savings.errors[:base].present?, "Should have error message"
    assert_includes @savings.errors[:base].first, "Cannot delete account because it is used in"
    assert_includes @savings.errors[:base].first, "transfer rule"
    assert Account.exists?(@savings.id), "Account should still exist"
  end

  test "can delete account after removing transfer rules" do
    @checking.save!
    @savings.save!

    transfer_rule = RecurringRule.create!(
      account: @checking,
      destination_account: @savings,
      description: "Transfer",
      amount: 500.0,
      rule_type: :transfer,
      frequency: :monthly,
      anchor_date: Date.current
    )

    # Delete the transfer rule
    transfer_rule.destroy

    # Now should be able to delete account
    result = @checking.destroy
    assert result, "Should successfully destroy account after removing transfer rules"
    assert_not Account.exists?(@checking.id)
  end

  test "can delete account with non-transfer rules" do
    @checking.save!

    expense_rule = RecurringRule.create!(
      account: @checking,
      description: "Expense",
      amount: 100.0,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current
    )

    income_rule = RecurringRule.create!(
      account: @checking,
      description: "Income",
      amount: 1000.0,
      rule_type: :income,
      frequency: :monthly,
      anchor_date: Date.current
    )

    # Should be able to delete account (dependent: :destroy handles non-transfer rules)
    result = @checking.destroy
    assert result, "Should successfully destroy account with non-transfer rules"
    assert_not Account.exists?(@checking.id)
  end

  # ============================================================================
  # Method Tests - projected_balance
  # ============================================================================

  test "projected_balance calculates correctly" do
    @checking.save!
    @checking.update!(current_balance: 1000.0, balance_date: Date.current)

    Transaction.create!(
      account: @checking,
      description: "T1",
      amount: -100.0,
      date: Date.current + 1.day,
      status: :estimated
    )

    Transaction.create!(
      account: @checking,
      description: "T2",
      amount: 200.0,
      date: Date.current + 2.days,
      status: :estimated
    )

    Transaction.create!(
      account: @checking,
      description: "T3",
      amount: -50.0,
      date: Date.current + 3.days,
      status: :estimated
    )

    # 1000 - 100 + 200 - 50 = 1050
    end_date = Date.current + 3.days
    assert_equal 1050.0, @checking.projected_balance(end_date)
  end

  test "projected_balance ignores transactions before balance_date" do
    @checking.save!
    @checking.update!(current_balance: 1000.0, balance_date: Date.current)

    Transaction.create!(
      account: @checking,
      description: "Before",
      amount: -500.0,
      date: Date.current - 1.day,
      status: :actual
    )

    Transaction.create!(
      account: @checking,
      description: "After",
      amount: -100.0,
      date: Date.current + 1.day,
      status: :estimated
    )

    # Should only count transaction after balance_date
    # 1000 - 100 = 900
    assert_equal 900.0, @checking.projected_balance(Date.current + 1.day)
  end

  test "projected_balance uses default view months if no date provided" do
    @checking.save!
    @checking.update!(current_balance: 1000.0, balance_date: Date.current)

    # Create transaction within default period
    Transaction.create!(
      account: @checking,
      description: "T1",
      amount: -100.0,
      date: Date.current + 1.month,
      status: :estimated
    )

    # Should use Setting.instance.default_view_months
    projected = @checking.projected_balance
    assert_equal 900.0, projected
  end

  # ============================================================================
  # Method Tests - lowest_projected_balance
  # ============================================================================

  test "lowest_projected_balance finds minimum balance" do
    @checking.save!
    @checking.update!(current_balance: 1000.0, balance_date: Date.current)

    Transaction.create!(
      account: @checking,
      description: "T1",
      amount: -800.0,  # Balance drops to 200
      date: Date.current + 1.day,
      status: :estimated
    )

    Transaction.create!(
      account: @checking,
      description: "T2",
      amount: 500.0,   # Balance rises to 700
      date: Date.current + 2.days,
      status: :estimated
    )

    Transaction.create!(
      account: @checking,
      description: "T3",
      amount: -100.0,  # Balance drops to 600
      date: Date.current + 3.days,
      status: :estimated
    )

    # Lowest point is 200
    assert_equal 200.0, @checking.lowest_projected_balance(Date.current + 3.days)
  end

  test "lowest_projected_balance returns current balance if no transactions" do
    @checking.save!
    @checking.update!(current_balance: 1000.0, balance_date: Date.current)

    assert_equal 1000.0, @checking.lowest_projected_balance(Date.current + 30.days)
  end

  test "lowest_projected_balance handles negative balances" do
    @checking.save!
    @checking.update!(current_balance: 100.0, balance_date: Date.current)

    Transaction.create!(
      account: @checking,
      description: "T1",
      amount: -200.0,  # Balance drops to -100
      date: Date.current + 1.day,
      status: :estimated
    )

    Transaction.create!(
      account: @checking,
      description: "T2",
      amount: 150.0,   # Balance rises to 50
      date: Date.current + 2.days,
      status: :estimated
    )

    assert_equal(-100.0, @checking.lowest_projected_balance(Date.current + 2.days))
  end

  test "lowest_projected_balance excludes past dips from forward-looking minimum" do
    @checking.save!
    @checking.update!(current_balance: 10000.0, balance_date: Date.current - 14.days)

    # Large past expense creates a dip to 2000 (in the past)
    Transaction.create!(
      account: @checking,
      description: "Past big expense",
      amount: -8000.0,
      date: Date.current - 7.days,
      status: :actual
    )

    # Salary restores balance to 7000 (in the past)
    Transaction.create!(
      account: @checking,
      description: "Past salary",
      amount: 5000.0,
      date: Date.current - 3.days,
      status: :actual
    )

    # Smaller future expense drops to 6000
    Transaction.create!(
      account: @checking,
      description: "Future expense",
      amount: -1000.0,
      date: Date.current + 5.days,
      status: :estimated
    )

    # Forward-looking low should be 6000 (future dip), NOT 2000 (past dip)
    assert_equal 6000.0, @checking.lowest_projected_balance(Date.current + 30.days)
  end

  test "lowest_projected_balance accumulates past transactions into running balance" do
    @checking.save!
    @checking.update!(current_balance: 5000.0, balance_date: Date.current - 10.days)

    # Past expense reduces running balance
    Transaction.create!(
      account: @checking,
      description: "Past expense",
      amount: -3000.0,
      date: Date.current - 5.days,
      status: :actual
    )

    # Future expense from the reduced base
    Transaction.create!(
      account: @checking,
      description: "Future expense",
      amount: -500.0,
      date: Date.current + 5.days,
      status: :estimated
    )

    # Running balance after past: 5000 - 3000 = 2000
    # After future expense: 2000 - 500 = 1500
    assert_equal 1500.0, @checking.lowest_projected_balance(Date.current + 30.days)
  end

  test "lowest_projected_balance returns running balance when no future transactions" do
    @checking.save!
    @checking.update!(current_balance: 5000.0, balance_date: Date.current - 10.days)

    # Only past transactions
    Transaction.create!(
      account: @checking,
      description: "Past expense",
      amount: -2000.0,
      date: Date.current - 5.days,
      status: :actual
    )

    Transaction.create!(
      account: @checking,
      description: "Past income",
      amount: 1000.0,
      date: Date.current - 2.days,
      status: :actual
    )

    # No future transactions, should return balance after all past txns: 5000 - 2000 + 1000 = 4000
    assert_equal 4000.0, @checking.lowest_projected_balance(Date.current + 30.days)
  end

  # ============================================================================
  # Method Tests - projection_status
  # ============================================================================

  test "projection_status returns danger when balance goes negative" do
    @checking.save!
    @checking.update!(current_balance: 100.0, balance_date: Date.current, warning_threshold: 200.0)

    Transaction.create!(
      account: @checking,
      description: "T1",
      amount: -150.0,  # Balance drops to -50
      date: Date.current + 1.day,
      status: :estimated
    )

    assert_equal :danger, @checking.projection_status(Date.current + 1.day)
  end

  test "projection_status returns warning when below threshold but positive" do
    @checking.save!
    @checking.update!(current_balance: 100.0, balance_date: Date.current, warning_threshold: 200.0)

    Transaction.create!(
      account: @checking,
      description: "T1",
      amount: -50.0,  # Balance drops to 50 (below 200 threshold)
      date: Date.current + 1.day,
      status: :estimated
    )

    assert_equal :warning, @checking.projection_status(Date.current + 1.day)
  end

  test "projection_status returns normal when above threshold" do
    @checking.save!
    @checking.update!(current_balance: 1000.0, balance_date: Date.current, warning_threshold: 200.0)

    Transaction.create!(
      account: @checking,
      description: "T1",
      amount: -500.0,  # Balance drops to 500 (still above 200)
      date: Date.current + 1.day,
      status: :estimated
    )

    assert_equal :normal, @checking.projection_status(Date.current + 1.day)
  end

  test "projection_status edge case: exactly at threshold is normal" do
    @checking.save!
    @checking.update!(current_balance: 300.0, balance_date: Date.current, warning_threshold: 300.0)

    # No transactions, balance stays at exactly threshold
    assert_equal :normal, @checking.projection_status(Date.current + 30.days)
  end

  test "projection_status edge case: exactly at zero is warning" do
    @checking.save!
    @checking.update!(current_balance: 100.0, balance_date: Date.current, warning_threshold: 200.0)

    Transaction.create!(
      account: @checking,
      description: "T1",
      amount: -100.0,  # Balance drops to exactly 0
      date: Date.current + 1.day,
      status: :estimated
    )

    # The code checks `lowest < 0`, so 0 should be warning, not danger
    assert_equal :warning, @checking.projection_status(Date.current + 1.day)
  end

  # ============================================================================
  # Method Tests - running_balances_for
  # ============================================================================

  test "running_balances_for calculates running balance for each transaction" do
    @checking.save!
    @checking.update!(current_balance: 1000.0, balance_date: Date.current)

    txn1 = Transaction.create!(
      account: @checking,
      description: "T1",
      amount: -100.0,
      date: Date.current + 1.day,
      status: :estimated
    )

    txn2 = Transaction.create!(
      account: @checking,
      description: "T2",
      amount: -50.0,
      date: Date.current + 2.days,
      status: :estimated
    )

    txn3 = Transaction.create!(
      account: @checking,
      description: "T3",
      amount: 200.0,
      date: Date.current + 3.days,
      status: :estimated
    )

    txns = [ txn1, txn2, txn3 ]
    results = @checking.running_balances_for(txns)

    assert_equal 3, results.length

    assert_equal txn1, results[0][:transaction]
    assert_equal 900.0, results[0][:running_balance]  # 1000 - 100

    assert_equal txn2, results[1][:transaction]
    assert_equal 850.0, results[1][:running_balance]  # 900 - 50

    assert_equal txn3, results[2][:transaction]
    assert_equal 1050.0, results[2][:running_balance] # 850 + 200
  end

  test "running_balances_for handles empty array" do
    @checking.save!
    @checking.update!(current_balance: 1000.0, balance_date: Date.current)

    results = @checking.running_balances_for([])
    assert_equal 0, results.length
  end
end
