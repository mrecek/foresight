require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  def setup
    @checking = Account.create!(
      name: "Checking",
      account_type: :checking,
      current_balance: 1000.0,
      balance_date: Date.today,
      warning_threshold: 0.0
    )

    @savings = Account.create!(
      name: "Savings",
      account_type: :savings,
      current_balance: 5000.0,
      balance_date: Date.today,
      warning_threshold: 0.0
    )

    @category_group = CategoryGroup.create!(name: "Food", color: "teal", display_order: 1)
    @category = Category.create!(name: "Groceries", category_group: @category_group, display_order: 1)
  end

  # ============================================================================
  # Validation Tests
  # ============================================================================

  test "valid transaction with required fields" do
    txn = Transaction.new(
      account: @checking,
      description: "Test Transaction",
      amount: 100.0,
      date: Date.today,
      status: :estimated
    )
    assert txn.valid?
  end

  test "requires description" do
    txn = Transaction.new(
      account: @checking,
      amount: 100.0,
      date: Date.today,
      status: :estimated
    )
    assert_not txn.valid?
    assert_includes txn.errors[:description], "can't be blank"
  end

  test "requires amount" do
    txn = Transaction.new(
      account: @checking,
      description: "Test",
      date: Date.today,
      status: :estimated
    )
    assert_not txn.valid?
    assert_includes txn.errors[:amount], "can't be blank"
  end

  test "requires date" do
    txn = Transaction.new(
      account: @checking,
      description: "Test",
      amount: 100.0,
      status: :estimated
    )
    assert_not txn.valid?
    assert_includes txn.errors[:date], "can't be blank"
  end

  test "requires account" do
    txn = Transaction.new(
      description: "Test",
      amount: 100.0,
      date: Date.today,
      status: :estimated
    )
    assert_not txn.valid?
    assert_includes txn.errors[:account], "can't be blank"
  end

  test "amount must be numeric" do
    txn = Transaction.new(
      account: @checking,
      description: "Test",
      amount: "not a number",
      date: Date.today,
      status: :estimated
    )
    assert_not txn.valid?
    assert_includes txn.errors[:amount], "is not a number"
  end

  test "transfer requires different accounts" do
    txn = Transaction.new(
      account: @checking,
      destination_account_id: @checking.id,
      description: "Invalid Transfer",
      amount: 100.0,
      date: Date.today,
      status: :estimated
    )
    assert_not txn.valid?
    assert_includes txn.errors[:destination_account_id], "cannot be the same as the source account"
  end

  # ============================================================================
  # Transfer Tests - manage_transfer callback
  # ============================================================================

  test "creating transfer creates linked transaction pair" do
    txn = Transaction.create!(
      account: @checking,
      destination_account_id: @savings.id,
      description: "Transfer to Savings",
      amount: -500.0,
      date: Date.today,
      status: :estimated
    )

    assert txn.linked_transaction.present?, "Should have created linked transaction"
    linked = txn.linked_transaction

    assert_equal @savings.id, linked.account_id, "Linked transaction should be in destination account"
    assert_equal 500.0, linked.amount, "Linked transaction should have inverse amount"
    assert_equal txn.description, linked.description
    assert_equal txn.date, linked.date
    assert_equal txn.status, linked.status
    assert_equal txn.id, linked.linked_transaction_id, "Should be bidirectionally linked"
  end

  test "updating transfer amount updates linked transaction" do
    txn = Transaction.create!(
      account: @checking,
      destination_account_id: @savings.id,
      description: "Transfer",
      amount: -500.0,
      date: Date.today,
      status: :estimated
    )

    linked = txn.linked_transaction

    txn.update!(amount: -750.0)
    linked.reload

    assert_equal 750.0, linked.amount, "Linked transaction amount should update"
  end

  test "updating transfer date updates linked transaction" do
    txn = Transaction.create!(
      account: @checking,
      destination_account_id: @savings.id,
      description: "Transfer",
      amount: -500.0,
      date: Date.today,
      status: :estimated
    )

    linked = txn.linked_transaction
    new_date = Date.today + 7.days

    txn.update!(date: new_date)
    linked.reload

    assert_equal new_date, linked.date, "Linked transaction date should update"
  end

  test "updating transfer description updates linked transaction" do
    txn = Transaction.create!(
      account: @checking,
      destination_account_id: @savings.id,
      description: "Transfer",
      amount: -500.0,
      date: Date.today,
      status: :estimated
    )

    linked = txn.linked_transaction

    txn.update!(description: "Updated Transfer")
    linked.reload

    assert_equal "Updated Transfer", linked.description
  end

  test "updating transfer category updates linked transaction" do
    txn = Transaction.create!(
      account: @checking,
      destination_account_id: @savings.id,
      description: "Transfer",
      amount: -500.0,
      date: Date.today,
      status: :estimated,
      category: @category
    )

    linked = txn.linked_transaction
    assert_equal @category.id, linked.category_id

    new_category = Category.create!(name: "Transport", category_group: @category_group, display_order: 2)
    txn.update!(category: new_category)
    linked.reload

    assert_equal new_category.id, linked.category_id
  end

  test "removing destination_account_id destroys linked transaction" do
    txn = Transaction.create!(
      account: @checking,
      destination_account_id: @savings.id,
      description: "Transfer",
      amount: -500.0,
      date: Date.today,
      status: :estimated
    )

    linked_id = txn.linked_transaction_id

    # Simulate converting transfer to expense by clearing destination
    txn.destination_account_id = nil
    txn.save!

    assert_nil txn.linked_transaction_id, "Linked transaction reference should be cleared"
    assert_not Transaction.exists?(linked_id), "Linked transaction should be destroyed"
  end

  test "transfer method returns true for transaction with linked_transaction" do
    txn = Transaction.create!(
      account: @checking,
      destination_account_id: @savings.id,
      description: "Transfer",
      amount: -500.0,
      date: Date.today,
      status: :estimated
    )

    assert txn.transfer?, "Should recognize as transfer when linked_transaction exists"
  end

  test "transfer method returns true for transaction with destination_account_id" do
    txn = Transaction.new(
      account: @checking,
      destination_account_id: @savings.id,
      description: "Transfer",
      amount: -500.0,
      date: Date.today,
      status: :estimated
    )

    assert txn.transfer?, "Should recognize as transfer when destination_account_id is present"
  end

  test "transfer method returns false for regular transaction" do
    txn = Transaction.new(
      account: @checking,
      description: "Regular Expense",
      amount: -100.0,
      date: Date.today,
      status: :estimated
    )

    assert_not txn.transfer?, "Should not recognize as transfer"
  end

  # ============================================================================
  # Callback Tests - before_destroy :unlink_transaction
  # ============================================================================

  test "destroying transaction unlinks its linked transaction" do
    txn = Transaction.create!(
      account: @checking,
      destination_account_id: @savings.id,
      description: "Transfer",
      amount: -500.0,
      date: Date.today,
      status: :estimated
    )

    linked = txn.linked_transaction
    linked_id = linked.id

    txn.destroy

    # Linked transaction should still exist but have nil linked_transaction_id
    assert Transaction.exists?(linked_id), "Linked transaction should still exist"
    linked.reload
    assert_nil linked.linked_transaction_id, "Linked transaction reference should be nil"
  end

  test "CRITICAL: reconciliation properly unlinks transfers (Issue 2)" do
    # This tests the fix for Issue 2: Reconciliation using destroy_all instead of delete_all
    # Create a transfer
    txn = Transaction.create!(
      account: @checking,
      destination_account_id: @savings.id,
      description: "Transfer",
      amount: -500.0,
      date: Date.today - 10.days,
      status: :actual
    )

    linked = txn.linked_transaction
    linked_id = linked.id

    # Simulate reconciliation by destroying transactions before a date
    # This mimics what the controller does in accounts_controller.rb
    @checking.transactions.where("date < ?", Date.today).destroy_all

    # Main transaction should be deleted
    assert_not Transaction.exists?(txn.id), "Main transaction should be deleted"

    # Linked transaction should exist but be unlinked
    assert Transaction.exists?(linked_id), "Linked transaction should still exist"
    linked.reload
    assert_nil linked.linked_transaction_id, "Linked transaction should be unlinked (not orphaned)"
  end

  # ============================================================================
  # Enum Tests
  # ============================================================================

  test "status enum works correctly" do
    txn = Transaction.create!(
      account: @checking,
      description: "Test",
      amount: 100.0,
      date: Date.today,
      status: :estimated
    )

    assert txn.estimated?, "Should be estimated"
    assert_not txn.actual?, "Should not be actual"

    txn.update!(status: :actual)
    assert txn.actual?, "Should be actual"
    assert_not txn.estimated?, "Should not be estimated"
  end

  # ============================================================================
  # Scope Tests
  # ============================================================================

  test "upcoming scope returns future transactions" do
    past = Transaction.create!(
      account: @checking,
      description: "Past",
      amount: -100.0,
      date: Date.current - 5.days,
      status: :estimated
    )

    future = Transaction.create!(
      account: @checking,
      description: "Future",
      amount: -100.0,
      date: Date.current + 5.days,
      status: :estimated
    )

    today = Transaction.create!(
      account: @checking,
      description: "Today",
      amount: -100.0,
      date: Date.current,
      status: :estimated
    )

    upcoming = Transaction.upcoming

    assert_includes upcoming, future
    assert_includes upcoming, today
    assert_not_includes upcoming, past
  end

  test "in_attention_window scope returns next 30 days estimated" do
    old = Transaction.create!(
      account: @checking,
      description: "Old",
      amount: -100.0,
      date: Date.current - 5.days,
      status: :estimated
    )

    in_window = Transaction.create!(
      account: @checking,
      description: "In Window",
      amount: -100.0,
      date: Date.current + 15.days,
      status: :estimated
    )

    beyond_window = Transaction.create!(
      account: @checking,
      description: "Beyond",
      amount: -100.0,
      date: Date.current + 31.days,
      status: :estimated
    )

    actual_in_window = Transaction.create!(
      account: @checking,
      description: "Actual",
      amount: -100.0,
      date: Date.current + 15.days,
      status: :actual
    )

    attention = Transaction.in_attention_window

    assert_includes attention, in_window
    assert_not_includes attention, old
    assert_not_includes attention, beyond_window
    assert_not_includes attention, actual_in_window
  end

  test "for_account scope filters by account" do
    checking_txn = Transaction.create!(
      account: @checking,
      description: "Checking",
      amount: -100.0,
      date: Date.today,
      status: :estimated
    )

    savings_txn = Transaction.create!(
      account: @savings,
      description: "Savings",
      amount: 100.0,
      date: Date.today,
      status: :estimated
    )

    checking_filtered = Transaction.for_account(@checking.id)

    assert_includes checking_filtered, checking_txn
    assert_not_includes checking_filtered, savings_txn
  end

  test "not_user_modified scope excludes user modified transactions" do
    auto = Transaction.create!(
      account: @checking,
      description: "Auto",
      amount: -100.0,
      date: Date.today,
      status: :estimated,
      user_modified: false
    )

    modified = Transaction.create!(
      account: @checking,
      description: "Modified",
      amount: -100.0,
      date: Date.today,
      status: :estimated,
      user_modified: true
    )

    not_modified = Transaction.not_user_modified

    assert_includes not_modified, auto
    assert_not_includes not_modified, modified
  end

  # ============================================================================
  # Method Tests
  # ============================================================================

  test "formatted_amount shows positive with + prefix" do
    txn = Transaction.create!(
      account: @checking,
      description: "Income",
      amount: 1234.56,
      date: Date.today,
      status: :estimated
    )

    assert_equal "+$1,234.56", txn.formatted_amount
  end

  test "formatted_amount shows negative with - prefix" do
    txn = Transaction.create!(
      account: @checking,
      description: "Expense",
      amount: -1234.56,
      date: Date.today,
      status: :estimated
    )

    assert_equal "-$1,234.56", txn.formatted_amount
  end

  test "formatted_amount handles zero" do
    txn = Transaction.create!(
      account: @checking,
      description: "Zero",
      amount: 0.0,
      date: Date.today,
      status: :estimated
    )

    assert_equal "+$0.00", txn.formatted_amount
  end

  test "running_balance calculates correctly" do
    @checking.update!(current_balance: 1000.0, balance_date: Date.today)

    Transaction.create!(
      account: @checking,
      description: "T1",
      amount: -100.0,
      date: Date.today + 1.day,
      status: :estimated
    )

    txn2 = Transaction.create!(
      account: @checking,
      description: "T2",
      amount: -50.0,
      date: Date.today + 2.days,
      status: :estimated
    )

    # Should be: 1000 - 100 - 50 = 850
    assert_equal 850.0, txn2.running_balance
  end

  test "running_balance uses pre-computed value if set" do
    txn = Transaction.create!(
      account: @checking,
      description: "Test",
      amount: -100.0,
      date: Date.today,
      status: :estimated
    )

    txn.running_balance = 12345.67
    assert_equal 12345.67, txn.running_balance
  end

  # ============================================================================
  # Association Tests
  # ============================================================================

  test "belongs to account" do
    txn = Transaction.create!(
      account: @checking,
      description: "Test",
      amount: -100.0,
      date: Date.today,
      status: :estimated
    )

    assert_equal @checking, txn.account
  end

  test "belongs to category optionally" do
    txn = Transaction.create!(
      account: @checking,
      description: "Test",
      amount: -100.0,
      date: Date.today,
      status: :estimated,
      category: @category
    )

    assert_equal @category, txn.category

    txn.update!(category: nil)
    assert_nil txn.category
  end

  test "belongs to recurring_rule optionally" do
    rule = RecurringRule.create!(
      account: @checking,
      description: "Weekly",
      amount: 100.0,
      rule_type: :expense,
      frequency: :weekly,
      anchor_date: Date.today
    )

    txn = rule.transactions.first

    assert_equal rule, txn.recurring_rule
  end
end
