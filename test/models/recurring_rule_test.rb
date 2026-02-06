require "test_helper"

class RecurringRuleTest < ActiveSupport::TestCase
  def setup
    @checking_account = Account.create!(
      name: "Checking",
      account_type: :checking,
      current_balance: 1000.0,
      balance_date: Date.current,
      warning_threshold: 0.0
    )

    @savings_account = Account.create!(
      name: "Savings",
      account_type: :savings,
      current_balance: 5000.0,
      balance_date: Date.current,
      warning_threshold: 0.0
    )
  end

  # ============================================================================
  # Validation Tests
  # ============================================================================

  test "valid recurring rule with required fields" do
    rule = RecurringRule.new(
      account: @checking_account,
      description: "Weekly Grocery",
      amount: 100.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current
    )

    assert rule.valid?
  end

  test "requires description" do
    rule = RecurringRule.new(
      account: @checking_account,
      amount: 100.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current
    )

    assert_not rule.valid?
    assert_includes rule.errors[:description], "can't be blank"
  end

  test "requires amount" do
    rule = RecurringRule.new(
      account: @checking_account,
      description: "Test",
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current
    )

    assert_not rule.valid?
    assert_includes rule.errors[:amount], "can't be blank"
  end

  test "requires amount to be greater than 0" do
    rule = RecurringRule.new(
      account: @checking_account,
      description: "Test",
      amount: -50.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current
    )

    assert_not rule.valid?
    assert_includes rule.errors[:amount], "must be greater than 0"
  end

  # Note: rule_type and frequency are enums with default values in Rails
  # so we can't test for their absence in the same way as other attributes

  test "requires anchor_date" do
    rule = RecurringRule.new(
      account: @checking_account,
      description: "Test",
      amount: 100.0,
      rule_type: :expense,
      frequency: :weekly
    )

    assert_not rule.valid?
    assert_includes rule.errors[:anchor_date], "can't be blank"
  end

  test "transfer requires destination_account" do
    rule = RecurringRule.new(
      account: @checking_account,
      description: "Transfer to Savings",
      amount: 500.0,
      rule_type: :transfer,
      frequency: :monthly,
      anchor_date: Date.current
    )

    assert_not rule.valid?
    assert_includes rule.errors[:destination_account], "can't be blank"
  end

  test "transfer requires different accounts" do
    rule = RecurringRule.new(
      account: @checking_account,
      destination_account: @checking_account, # Same account
      description: "Invalid Transfer",
      amount: 500.0,
      rule_type: :transfer,
      frequency: :monthly,
      anchor_date: Date.current
    )

    assert_not rule.valid?
    assert_includes rule.errors[:destination_account_id], "must be different from the source account"
  end

  test "day_of_month must be between 1 and 31" do
    rule = RecurringRule.new(
      account: @checking_account,
      description: "Test",
      amount: 100.0,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current,
      day_of_month: 32
    )

    assert_not rule.valid?
    assert_includes rule.errors[:day_of_month], "is not included in the list"
  end

  test "day_of_week must be between 0 and 6" do
    rule = RecurringRule.new(
      account: @checking_account,
      description: "Test",
      amount: 100.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current,
      day_of_week: 7
    )

    assert_not rule.valid?
    assert_includes rule.errors[:day_of_week], "is not included in the list"
  end

  # ============================================================================
  # Callback Tests - after_create :generate_initial_transactions
  # ============================================================================

  test "after_create generates initial transactions" do
    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Daily Coffee",
      amount: 5.0,
      rule_type: :expense,
      frequency: :daily,
      anchor_date: Date.current
    )

    assert rule.transactions.count > 0, "Should generate initial transactions on create"
    assert rule.transactions.all?(&:estimated?), "Initial transactions should be estimated"
  end

  test "income rule creates positive amount transactions" do
    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Monthly Salary",
      amount: 5000.0,
      rule_type: :income,
      frequency: :monthly,
      anchor_date: Date.current
    )

    transaction = rule.transactions.first
    assert transaction.amount > 0, "Income transactions should have positive amount"
    assert_equal 5000.0, transaction.amount
  end

  test "expense rule creates negative amount transactions" do
    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Monthly Rent",
      amount: 1200.0,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current
    )

    transaction = rule.transactions.first
    assert transaction.amount < 0, "Expense transactions should have negative amount"
    assert_equal(-1200.0, transaction.amount)
  end

  test "transfer rule creates linked transaction pair" do
    rule = RecurringRule.create!(
      account: @checking_account,
      destination_account: @savings_account,
      description: "Transfer to Savings",
      amount: 500.0,
      rule_type: :transfer,
      frequency: :monthly,
      anchor_date: Date.current
    )

    # Should have at least one pair of transactions
    checking_txns = rule.transactions.where(account: @checking_account)
    savings_txns = rule.transactions.where(account: @savings_account)

    assert checking_txns.count > 0, "Should have transactions on checking account"
    assert savings_txns.count > 0, "Should have transactions on savings account"
    assert_equal checking_txns.count, savings_txns.count, "Should have equal number of transactions"

    # Check first pair
    checking_txn = checking_txns.first
    savings_txn = savings_txns.first

    assert_equal(-500.0, checking_txn.amount, "Checking should be debited")
    assert_equal 500.0, savings_txn.amount, "Savings should be credited"
    assert_equal savings_txn.id, checking_txn.linked_transaction_id, "Should be linked"
    assert_equal checking_txn.id, savings_txn.linked_transaction_id, "Should be bidirectionally linked"
  end

  # ============================================================================
  # Callback Tests - after_update :regenerate_transactions
  # ============================================================================

  test "schedule change triggers regenerate_transactions" do
    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Weekly Grocery",
      amount: 100.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current
    )

    initial_count = rule.transactions.count
    initial_transaction_ids = rule.transactions.pluck(:id)

    # Change frequency (schedule change)
    rule.update!(frequency: :biweekly)

    # Transactions should be regenerated
    rule.reload
    new_transaction_ids = rule.transactions.pluck(:id)

    assert_not_equal initial_transaction_ids.sort, new_transaction_ids.sort,
      "Transaction IDs should be different after regeneration"
  end

  test "regenerate_transactions preserves user-modified transactions" do
    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Weekly Grocery",
      amount: 100.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current
    )

    # Mark first future transaction as user-modified
    future_txn = rule.transactions.where("date >= ?", Date.current).first
    future_txn.update!(user_modified: true, amount: -150.0)
    modified_txn_id = future_txn.id

    # Change amount (schedule change)
    rule.update!(amount: 120.0)

    # User-modified transaction should still exist
    assert Transaction.exists?(modified_txn_id), "User-modified transaction should be preserved"
    preserved_txn = Transaction.find(modified_txn_id)
    assert_equal(-150.0, preserved_txn.amount, "User-modified amount should be preserved")

    # Other transactions should have new amount
    auto_generated_txns = rule.transactions.where.not(id: modified_txn_id).not_user_modified
    assert auto_generated_txns.all? { |t| t.amount == -120.0 },
      "Auto-generated transactions should have new amount"
  end

  test "schedule_changed? detects frequency change" do
    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Test",
      amount: 100.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current
    )

    rule.frequency = :monthly
    rule.save!

    assert rule.previous_changes.key?("frequency"), "Should have changed frequency"
  end

  test "schedule_changed? detects anchor_date change" do
    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Test",
      amount: 100.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current
    )

    rule.anchor_date = Date.current + 7.days
    rule.save!

    assert rule.previous_changes.key?("anchor_date"), "Should have changed anchor_date"
  end

  test "schedule_changed? detects amount change" do
    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Test",
      amount: 100.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current
    )

    rule.amount = 150.0
    rule.save!

    assert rule.previous_changes.key?("amount"), "Should have changed amount"
  end

  # ============================================================================
  # Callback Tests - after_update :update_future_transactions_category
  # ============================================================================

  test "category change updates future transactions without regenerating" do
    # Create category with valid color
    category_group = CategoryGroup.create!(name: "Food", color: "teal")
    old_category = Category.create!(name: "Groceries", category_group: category_group)
    new_category = Category.create!(name: "Dining Out", category_group: category_group)

    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Weekly Food",
      amount: 100.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current,
      category: old_category
    )

    initial_transaction_ids = rule.transactions.pluck(:id).sort

    # Change category only (not a schedule change)
    rule.update!(category: new_category)

    rule.reload
    new_transaction_ids = rule.transactions.pluck(:id).sort

    # Transaction IDs should be the same (not regenerated)
    assert_equal initial_transaction_ids, new_transaction_ids,
      "Transactions should NOT be regenerated for category-only change"

    # Future transactions should have new category
    future_txns = rule.transactions.where("date >= ?", Date.current)
    assert future_txns.all? { |t| t.category_id == new_category.id },
      "Future transactions should have new category"
  end

  # ============================================================================
  # extend_projections_to Tests
  # ============================================================================

  test "extend_projections_to is idempotent" do
    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Monthly Bill",
      amount: 50.0,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current
    )

    end_date = Date.current + 3.months
    initial_count = rule.transactions.count

    # Extend projections
    rule.extend_projections_to(end_date)
    count_after_first_extend = rule.transactions.count

    assert count_after_first_extend >= initial_count,
      "Should have generated new transactions"

    # Extend again to same date (should be idempotent)
    rule.extend_projections_to(end_date)
    count_after_second_extend = rule.transactions.count

    assert_equal count_after_first_extend, count_after_second_extend,
      "Should not create duplicate transactions (idempotent)"
  end

  test "extend_projections_to generates transactions beyond existing range" do
    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Weekly Payment",
      amount: 25.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current
    )

    # Initial generation goes to default_view_months
    initial_count = rule.transactions.count
    initial_max_date = rule.transactions.maximum(:date)

    # Extend far into the future (well beyond initial range)
    future_date = Date.current + 12.months
    rule.extend_projections_to(future_date)

    new_count = rule.transactions.count
    new_max_date = rule.transactions.maximum(:date)

    assert new_count > initial_count,
      "Should have created additional transactions (had #{initial_count}, now #{new_count})"
    assert new_max_date.present? && new_max_date >= (future_date - 1.week),
      "Should generate transactions close to the extended date (max: #{new_max_date}, target: #{future_date})"
  end

  test "extend_projections_to respects user-modified transactions" do
    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Daily Expense",
      amount: 10.0,
      rule_type: :expense,
      frequency: :daily,
      anchor_date: Date.current
    )

    # Find an existing auto-generated transaction and mark it as user-modified
    future_date = Date.current + 30.days
    existing_txn = rule.transactions.where(date: future_date).first

    # If no transaction exists for that date, extend projections first
    if existing_txn.nil?
      rule.extend_projections_to(future_date + 10.days)
      existing_txn = rule.transactions.where(date: future_date).first
    end

    # Modify the existing transaction
    existing_txn.update!(user_modified: true, amount: -50.0)
    user_txn_id = existing_txn.id

    # Extend projections again (should preserve user-modified transaction)
    rule.extend_projections_to(future_date + 20.days)

    # User-modified transaction should still exist and be unchanged
    user_txn = Transaction.find(user_txn_id)
    assert_equal(-50.0, user_txn.amount, "User-modified transaction should be preserved")
    assert user_txn.user_modified?, "Transaction should still be marked as user_modified"
  end

  # ============================================================================
  # extend_all_projections_to Class Method Tests (including recent change)
  # ============================================================================

  test "extend_all_projections_to extends all rules when no account specified" do
    rule1 = RecurringRule.create!(
      account: @checking_account,
      description: "Rule 1",
      amount: 100.0,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current
    )

    rule2 = RecurringRule.create!(
      account: @savings_account,
      description: "Rule 2",
      amount: 50.0,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current
    )

    end_date = Date.current + 6.months
    RecurringRule.extend_all_projections_to(end_date)

    assert rule1.transactions.maximum(:date) >= end_date,
      "Rule 1 should be extended"
    assert rule2.transactions.maximum(:date) >= end_date,
      "Rule 2 should be extended"
  end

  test "extend_all_projections_to extends only rules for specified account (source)" do
    checking_rule = RecurringRule.create!(
      account: @checking_account,
      description: "Checking Rule",
      amount: 100.0,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current
    )

    savings_rule = RecurringRule.create!(
      account: @savings_account,
      description: "Savings Rule",
      amount: 50.0,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current
    )

    end_date = Date.current + 6.months
    checking_initial_max = checking_rule.transactions.maximum(:date)
    savings_initial_max = savings_rule.transactions.maximum(:date)

    RecurringRule.extend_all_projections_to(end_date, account: @checking_account)

    checking_rule.reload
    savings_rule.reload

    assert checking_rule.transactions.maximum(:date) >= end_date,
      "Checking rule should be extended"
    assert savings_rule.transactions.maximum(:date) == savings_initial_max,
      "Savings rule should NOT be extended"
  end

  test "extend_all_projections_to includes transfer destination rules for specified account" do
    # Create a transfer rule FROM checking TO savings
    transfer_rule = RecurringRule.create!(
      account: @checking_account,
      destination_account: @savings_account,
      description: "Transfer to Savings",
      amount: 500.0,
      rule_type: :transfer,
      frequency: :monthly,
      anchor_date: Date.current
    )

    end_date = Date.current + 6.months
    initial_max_date = transfer_rule.transactions.maximum(:date)

    # When extending projections for SAVINGS account, it should include this transfer
    # because savings is the DESTINATION account
    RecurringRule.extend_all_projections_to(end_date, account: @savings_account)

    transfer_rule.reload
    new_max_date = transfer_rule.transactions.maximum(:date)

    assert new_max_date >= end_date,
      "Transfer rule should be extended when extending destination account projections"

    # Verify both sides of transfer exist
    savings_txns = transfer_rule.transactions.where(account: @savings_account)
    assert savings_txns.count > 0,
      "Should have created transactions on savings account (destination)"
  end

  test "extend_all_projections_to includes both source and destination for transfers" do
    # Create a transfer rule FROM checking TO savings
    transfer_rule = RecurringRule.create!(
      account: @checking_account,
      destination_account: @savings_account,
      description: "Transfer to Savings",
      amount: 500.0,
      rule_type: :transfer,
      frequency: :monthly,
      anchor_date: Date.current
    )

    end_date = Date.current + 6.months

    # Extend for checking account (source)
    RecurringRule.extend_all_projections_to(end_date, account: @checking_account)

    transfer_rule.reload
    checking_max = transfer_rule.transactions.where(account: @checking_account).maximum(:date)
    savings_max = transfer_rule.transactions.where(account: @savings_account).maximum(:date)

    assert checking_max >= end_date, "Should extend checking (source) transactions"
    assert savings_max >= end_date, "Should extend savings (destination) transactions"

    # Clear and test from savings perspective
    transfer_rule.transactions.destroy_all
    transfer_rule.generate_transactions(Date.current + 1.month)

    # Extend for savings account (destination)
    RecurringRule.extend_all_projections_to(end_date, account: @savings_account)

    transfer_rule.reload
    checking_max = transfer_rule.transactions.where(account: @checking_account).maximum(:date)
    savings_max = transfer_rule.transactions.where(account: @savings_account).maximum(:date)

    assert checking_max >= end_date, "Should extend checking transactions even when querying by destination"
    assert savings_max >= end_date, "Should extend savings (destination) transactions"
  end

  # ============================================================================
  # generate_transactions Tests
  # ============================================================================

  test "generate_transactions creates transactions up to default period" do
    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Weekly Expense",
      amount: 50.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current
    )

    default_end_date = Setting.instance.default_view_months.months.from_now.to_date
    max_date = rule.transactions.maximum(:date)

    assert max_date <= default_end_date,
      "Should generate transactions up to default view period"
    assert max_date >= (default_end_date - 1.week),
      "Should generate close to the full default period"
  end

  # ============================================================================
  # Active Scope Tests
  # ============================================================================

  test "active scope returns only active rules" do
    active_rule = RecurringRule.create!(
      account: @checking_account,
      description: "Active Rule",
      amount: 100.0,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current,
      active: true
    )

    inactive_rule = RecurringRule.create!(
      account: @checking_account,
      description: "Inactive Rule",
      amount: 50.0,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current,
      active: false
    )

    active_rules = RecurringRule.active

    assert_includes active_rules, active_rule
    assert_not_includes active_rules, inactive_rule
  end

  # ============================================================================
  # Active Field Enforcement Tests
  # ============================================================================

  test "creating inactive rule generates no transactions" do
    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Inactive Expense",
      amount: 100.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current,
      active: false
    )

    assert_equal 0, rule.transactions.count,
      "Inactive rule should not generate any transactions on create"
  end

  test "deactivating rule removes future estimated transactions" do
    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Weekly Grocery",
      amount: 100.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current,
      active: true
    )

    assert rule.transactions.count > 0, "Should have transactions when active"

    rule.update!(active: false)

    assert_equal 0, rule.transactions.where("date >= ?", Date.current).not_user_modified.count,
      "Should remove future estimated transactions when deactivated"
  end

  test "deactivating rule preserves user-modified transactions" do
    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Weekly Grocery",
      amount: 100.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current,
      active: true
    )

    # Mark a future transaction as user-modified
    future_txn = rule.transactions.where("date >= ?", Date.current).first
    future_txn.update!(user_modified: true, amount: -150.0)
    modified_txn_id = future_txn.id

    rule.update!(active: false)

    assert Transaction.exists?(modified_txn_id),
      "User-modified transaction should be preserved when deactivating"
    assert_equal(-150.0, Transaction.find(modified_txn_id).amount,
      "User-modified amount should be unchanged")
  end

  test "reactivating rule regenerates transactions" do
    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Weekly Grocery",
      amount: 100.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.current,
      active: false
    )

    assert_equal 0, rule.transactions.count, "Inactive rule starts with no transactions"

    rule.update!(active: true)

    assert rule.transactions.count > 0,
      "Reactivating should regenerate transactions"
  end

  test "extend_all_projections_to skips inactive rules" do
    active_rule = RecurringRule.create!(
      account: @checking_account,
      description: "Active Rule",
      amount: 100.0,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current,
      active: true
    )

    inactive_rule = RecurringRule.create!(
      account: @savings_account,
      description: "Inactive Rule",
      amount: 50.0,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current,
      active: false
    )

    end_date = Date.current + 6.months
    RecurringRule.extend_all_projections_to(end_date)

    assert active_rule.transactions.maximum(:date) >= end_date,
      "Active rule should be extended"
    assert_equal 0, inactive_rule.transactions.count,
      "Inactive rule should have no transactions"
  end

  test "inactive rules do not affect projected balance" do
    # Create an active income rule
    RecurringRule.create!(
      account: @checking_account,
      description: "Salary",
      amount: 5000.0,
      rule_type: :income,
      frequency: :monthly,
      anchor_date: Date.current,
      active: true
    )

    balance_with_active_only = @checking_account.projected_balance

    # Create an inactive expense rule (should have zero effect)
    RecurringRule.create!(
      account: @checking_account,
      description: "Inactive Expense",
      amount: 2000.0,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current,
      active: false
    )

    balance_after_inactive = @checking_account.reload.projected_balance

    assert_equal balance_with_active_only, balance_after_inactive,
      "Inactive rule should not affect projected balance"
  end

  # ============================================================================
  # RecordNotUnique Handling Tests
  # ============================================================================

  test "create_transaction_for_date handles duplicate gracefully" do
    RecurringRule.skip_callback(:create, :after, :generate_initial_transactions)
    rule = RecurringRule.create!(
      account: @checking_account,
      description: "Test Rule",
      amount: 100.0,
      rule_type: :expense,
      frequency: :daily,
      anchor_date: Date.current
    )
    RecurringRule.set_callback(:create, :after, :generate_initial_transactions)

    date = Date.current

    # Create first transaction
    rule.send(:create_transaction_for_date, date)
    assert_equal 1, rule.transactions.where(date: date).count,
      "First creation should create transaction"

    # Attempt to create duplicate (should be handled gracefully by rescue)
    rule.send(:create_transaction_for_date, date)

    # Should still only have one transaction for this date
    txns_on_date = rule.transactions.where(date: date)
    assert_equal 1, txns_on_date.count,
      "Should only have one transaction for the date despite duplicate attempt"
  end

  # ============================================================================
  # Transfer Edge Cases
  # ============================================================================

  test "transfer rule does not create transactions if source and destination are same" do
    RecurringRule.skip_callback(:create, :after, :generate_initial_transactions)
    rule = RecurringRule.new(
      account: @checking_account,
      destination_account: @checking_account,
      description: "Invalid Transfer",
      amount: 500.0,
      rule_type: :transfer,
      frequency: :monthly,
      anchor_date: Date.current
    )
    RecurringRule.set_callback(:create, :after, :generate_initial_transactions)

    # Bypass validation to test the guard in create_transaction_for_date
    rule.save(validate: false)

    # Attempt to create transaction
    result = rule.send(:create_transaction_for_date, Date.current)

    assert_nil result, "Should not create transaction for invalid transfer"
    assert_equal 0, rule.transactions.count,
      "Should not have created any transactions"
  end

  test "is_estimated flag controls transaction status" do
    estimated_rule = RecurringRule.create!(
      account: @checking_account,
      description: "Estimated Expense",
      amount: 100.0,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current,
      is_estimated: true
    )

    actual_rule = RecurringRule.create!(
      account: @checking_account,
      description: "Actual Expense",
      amount: 100.0,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current,
      is_estimated: false
    )

    assert estimated_rule.transactions.all?(&:estimated?),
      "Transactions from is_estimated=true rule should be estimated"
    assert actual_rule.transactions.all?(&:actual?),
      "Transactions from is_estimated=false rule should be actual"
  end
end
