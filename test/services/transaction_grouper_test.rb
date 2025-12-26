require "test_helper"

class TransactionGrouperTest < ActiveSupport::TestCase
  def setup
    @account = Account.create!(
      name: "Test Account",
      account_type: :checking,
      current_balance: 1000.0,
      balance_date: Date.current,
      warning_threshold: 0.0
    )
  end

  # Test helper to create a recurring rule with specific frequency
  # Skips callbacks to avoid auto-generation of transactions
  def create_rule(frequency, amount = 10.0)
    RecurringRule.skip_callback(:create, :after, :generate_initial_transactions)
    rule = RecurringRule.create!(
      account: @account,
      description: "#{frequency.titleize} Rule",
      amount: amount,
      frequency: frequency,
      anchor_date: Date.current,
      rule_type: "expense"
    )
    RecurringRule.set_callback(:create, :after, :generate_initial_transactions)
    rule
  end

  # Test helper to create transaction items with balances
  def create_transaction_items(rule, dates, starting_balance = 1000.0)
    balance = starting_balance
    dates.map do |date|
      txn = Transaction.create!(
        account: @account,
        recurring_rule: rule,
        description: rule.description,
        amount: rule.amount,
        date: date,
        status: :estimated
      )
      balance -= rule.amount
      { transaction: txn, running_balance: balance }
    end
  end

  # ============================================================================
  # Test: High-frequency rules SHOULD group
  # ============================================================================

  test "groups daily transactions when 3 or more consecutive" do
    rule = create_rule("daily")
    dates = [ Date.current, Date.current + 1.day, Date.current + 2.days ]
    items = create_transaction_items(rule, dates)

    result = TransactionGrouper.new(items).call

    assert_equal 1, result.size
    assert result.first.group?, "Should be a TransactionGroup"
    assert_equal 3, result.first.count
    assert_equal rule, result.first.recurring_rule
  end

  test "groups weekly transactions when 3 or more consecutive" do
    rule = create_rule("weekly")
    dates = [ Date.current, Date.current + 1.week, Date.current + 2.weeks ]
    items = create_transaction_items(rule, dates)

    result = TransactionGrouper.new(items).call

    assert_equal 1, result.size
    assert result.first.group?
    assert_equal 3, result.first.count
  end

  test "groups biweekly transactions when 3 or more consecutive" do
    rule = create_rule("biweekly")
    dates = [ Date.current, Date.current + 2.weeks, Date.current + 4.weeks ]
    items = create_transaction_items(rule, dates)

    result = TransactionGrouper.new(items).call

    assert_equal 1, result.size
    assert result.first.group?
    assert_equal 3, result.first.count
  end

  test "groups semimonthly transactions when 3 or more consecutive" do
    rule = create_rule("semimonthly")
    dates = [ Date.current, Date.current + 15.days, Date.current + 30.days ]
    items = create_transaction_items(rule, dates)

    result = TransactionGrouper.new(items).call

    assert_equal 1, result.size
    assert result.first.group?
    assert_equal 3, result.first.count
  end

  # ============================================================================
  # Test: Low-frequency rules should NOT group
  # ============================================================================

  test "does not group monthly transactions" do
    rule = create_rule("monthly")
    dates = [ Date.current, Date.current + 1.month, Date.current + 2.months ]
    items = create_transaction_items(rule, dates)

    result = TransactionGrouper.new(items).call

    assert_equal 3, result.size, "Should have 3 individual transactions"
    result.each do |item|
      assert_not item.group?, "Should be SingleTransaction, not a group"
    end
  end

  test "does not group monthly_last transactions" do
    rule = create_rule("monthly_last")
    dates = [ Date.current, Date.current + 1.month, Date.current + 2.months ]
    items = create_transaction_items(rule, dates)

    result = TransactionGrouper.new(items).call

    assert_equal 3, result.size
    result.each { |item| assert_not item.group? }
  end

  test "does not group quarterly transactions" do
    rule = create_rule("quarterly")
    dates = [ Date.current, Date.current + 3.months, Date.current + 6.months ]
    items = create_transaction_items(rule, dates)

    result = TransactionGrouper.new(items).call

    assert_equal 3, result.size
    result.each { |item| assert_not item.group? }
  end

  test "does not group biyearly transactions" do
    rule = create_rule("biyearly")
    dates = [ Date.current, Date.current + 2.years, Date.current + 4.years ]
    items = create_transaction_items(rule, dates)

    result = TransactionGrouper.new(items).call

    assert_equal 3, result.size
    result.each { |item| assert_not item.group? }
  end

  test "does not group yearly transactions" do
    rule = create_rule("yearly")
    dates = [ Date.current, Date.current + 1.year, Date.current + 2.years ]
    items = create_transaction_items(rule, dates)

    result = TransactionGrouper.new(items).call

    assert_equal 3, result.size
    result.each { |item| assert_not item.group? }
  end

  # ============================================================================
  # Test: Minimum threshold (3+ transactions)
  # ============================================================================

  test "does not group when only 2 daily transactions" do
    rule = create_rule("daily")
    dates = [ Date.current, Date.current + 1.day ]
    items = create_transaction_items(rule, dates)

    result = TransactionGrouper.new(items).call

    assert_equal 2, result.size, "Should have 2 individual transactions"
    result.each { |item| assert_not item.group? }
  end

  test "does not group single transaction" do
    rule = create_rule("daily")
    dates = [ Date.current ]
    items = create_transaction_items(rule, dates)

    result = TransactionGrouper.new(items).call

    assert_equal 1, result.size
    assert_not result.first.group?
  end

  # ============================================================================
  # Test: Mixed scenarios
  # ============================================================================

  test "groups only high-frequency transactions when mixed with monthly" do
    daily_rule = create_rule("daily", 5.0)
    monthly_rule = create_rule("monthly", 100.0)

    # Create 3 daily transactions
    daily_dates = [ Date.current, Date.current + 1.day, Date.current + 2.days ]
    daily_items = create_transaction_items(daily_rule, daily_dates, 1000.0)

    # Create 3 monthly transactions
    monthly_dates = [ Date.current + 10.days, Date.current + 40.days, Date.current + 70.days ]
    monthly_items = create_transaction_items(monthly_rule, monthly_dates, 985.0)

    # Combine and sort by date
    all_items = (daily_items + monthly_items).sort_by { |i| i[:transaction].date }

    result = TransactionGrouper.new(all_items).call

    # Should have 1 group (daily) + 3 individual (monthly) = 4 items
    assert_equal 4, result.size

    # First item should be the daily group
    assert result.first.group?, "First item should be a TransactionGroup"
    assert_equal 3, result.first.count

    # Last 3 items should be individual monthly transactions
    result.last(3).each do |item|
      assert_not item.group?, "Monthly transactions should not be grouped"
    end
  end

  test "groups multiple different high-frequency rules separately" do
    daily_rule = create_rule("daily", 5.0)
    weekly_rule = create_rule("weekly", 20.0)

    daily_dates = [ Date.current, Date.current + 1.day, Date.current + 2.days ]
    daily_items = create_transaction_items(daily_rule, daily_dates, 1000.0)

    weekly_dates = [ Date.current + 10.days, Date.current + 17.days, Date.current + 24.days ]
    weekly_items = create_transaction_items(weekly_rule, weekly_dates, 985.0)

    all_items = (daily_items + weekly_items).sort_by { |i| i[:transaction].date }

    result = TransactionGrouper.new(all_items).call

    # Should have 2 groups
    assert_equal 2, result.size
    assert result[0].group?, "First group should be daily"
    assert result[1].group?, "Second group should be weekly"
    assert_equal 3, result[0].count
    assert_equal 3, result[1].count
  end

  # ============================================================================
  # Test: Edge cases
  # ============================================================================

  test "does not group transactions without recurring_rule_id" do
    # Create one-time transactions (no recurring rule)
    dates = [ Date.current, Date.current + 1.day, Date.current + 2.days ]
    items = dates.map.with_index do |date, i|
      txn = Transaction.create!(
        account: @account,
        description: "One-time expense",
        amount: -10.0,
        date: date,
        status: :estimated
      )
      { transaction: txn, running_balance: 1000.0 - (i + 1) * 10.0 }
    end

    result = TransactionGrouper.new(items).call

    assert_equal 3, result.size
    result.each { |item| assert_not item.group? }
  end

  test "does not group transactions with different statuses" do
    rule = create_rule("daily")

    # Create 2 estimated and 1 actual transaction
    items = [
      { transaction: Transaction.create!(account: @account, recurring_rule: rule, description: rule.description, amount: rule.amount, date: Date.current, status: :estimated), running_balance: 990.0 },
      { transaction: Transaction.create!(account: @account, recurring_rule: rule, description: rule.description, amount: rule.amount, date: Date.current + 1.day, status: :estimated), running_balance: 980.0 },
      { transaction: Transaction.create!(account: @account, recurring_rule: rule, description: rule.description, amount: rule.amount, date: Date.current + 2.days, status: :actual), running_balance: 970.0 }
    ]

    result = TransactionGrouper.new(items).call

    # First 2 estimated should not group (only 2), last actual should be separate
    assert_equal 3, result.size
    result.each { |item| assert_not item.group? }
  end

  test "does not group non-consecutive transactions from same rule" do
    daily_rule = create_rule("daily")
    monthly_rule = create_rule("monthly", 100.0)

    # Daily, Daily, Monthly (breaks consecutive), Daily
    items = [
      { transaction: Transaction.create!(account: @account, recurring_rule: daily_rule, description: "Daily 1", amount: -5.0, date: Date.current, status: :estimated), running_balance: 995.0 },
      { transaction: Transaction.create!(account: @account, recurring_rule: daily_rule, description: "Daily 2", amount: -5.0, date: Date.current + 1.day, status: :estimated), running_balance: 990.0 },
      { transaction: Transaction.create!(account: @account, recurring_rule: monthly_rule, description: "Monthly", amount: -100.0, date: Date.current + 2.days, status: :estimated), running_balance: 890.0 },
      { transaction: Transaction.create!(account: @account, recurring_rule: daily_rule, description: "Daily 3", amount: -5.0, date: Date.current + 3.days, status: :estimated), running_balance: 885.0 }
    ]

    result = TransactionGrouper.new(items).call

    # Should have 4 individual transactions (none meet the 3+ consecutive requirement)
    assert_equal 4, result.size
    result.each { |item| assert_not item.group? }
  end

  test "handles empty transaction list" do
    result = TransactionGrouper.new([]).call

    assert_equal [], result
  end

  # ============================================================================
  # Test: TransactionGroup struct properties
  # ============================================================================

  test "TransactionGroup includes correct properties" do
    rule = create_rule("daily", 10.0)
    dates = [ Date.current, Date.current + 1.day, Date.current + 2.days ]
    items = create_transaction_items(rule, dates, 1000.0)

    result = TransactionGrouper.new(items).call
    group = result.first

    assert group.group?
    assert_equal rule, group.recurring_rule
    assert_equal 3, group.count
    assert_equal Date.current, group.first_date
    assert_equal Date.current + 2.days, group.last_date
    assert_equal 30.0, group.total_amount
    assert_equal 970.0, group.ending_balance
    assert_equal "estimated", group.status
    assert_nil group.category # Category is nil since we didn't set one in the test
  end
end
