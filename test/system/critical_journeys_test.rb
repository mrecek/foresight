# frozen_string_literal: true

require "application_system_test_case"

class CriticalJourneysTest < ApplicationSystemTestCase
  setup do
    @original_test_mode = ENV["TEST_MODE"]
    ENV["TEST_MODE"] = "true"
  end

  teardown { @original_test_mode.nil? ? ENV.delete("TEST_MODE") : ENV["TEST_MODE"] = @original_test_mode }

  test "owner signs in after a rejected attempt and signs out" do
    ENV.delete("TEST_MODE")
    Setting.instance.update!(auth_username: "owner", auth_password: "password-123")

    visit login_path
    fill_in "Username", with: "owner"
    fill_in "Password", with: "wrong-password"
    click_button "Sign In"
    assert_text "Invalid username or password"

    fill_in "Password", with: "password-123"
    click_button "Sign In"
    assert_current_path root_path

    click_button "Logout"
    assert_current_path login_path
    assert_text "You've been signed out."
  end

  test "owner creates a transfer using the interactive transaction form" do
    checking, savings = create_accounts

    visit new_transaction_path(account_id: checking.id)
    assert_selector "[data-smart-amount-ready='true']"
    click_button "Transfer"
    assert_selector "[data-field='destination_account']", visible: true

    fill_in "transaction_description", with: "Emergency savings"
    find("[data-smart-amount-target='input']").set("125.50")
    select checking.name, from: "transaction_account_id"
    select checking.name, from: "transaction_destination_account_id"
    assert_text "Source and destination accounts must be different"
    select savings.name, from: "transaction_destination_account_id"
    assert_no_text "Source and destination accounts must be different"
    fill_in "transaction_date", with: Date.current
    select "Actual", from: "transaction_status"
    click_button "Create Transaction"

    assert_current_path transactions_path
    assert_text "Transaction created."
    source = Transaction.find_by!(account: checking, description: "Emergency savings")
    assert_equal(-125.50, source.amount)
    assert_equal savings, source.linked_transaction.account
  end

  test "owner creates a recurring transfer and sees generated occurrences" do
    checking, savings = create_accounts

    visit new_recurring_rule_path
    assert_selector "[data-type-selector-ready='true']"
    click_button "Transfer"
    assert_selector "[data-field='destination_account']", visible: true
    fill_in "recurring_rule_description", with: "Weekly savings"
    select checking.name, from: "recurring_rule_account_id"
    select savings.name, from: "recurring_rule_destination_account_id"
    fill_in "recurring_rule_amount", with: "25.00"
    select "Weekly", from: "recurring_rule_frequency"
    assert_selector "[data-frequency-fields-target='dayOfWeek']", visible: true
    assert_selector "[data-frequency-fields-target='dayOfMonth']", visible: false
    fill_in "recurring_rule_anchor_date", with: Date.current
    click_button "Create Rule"

    assert_current_path recurring_rules_path
    assert_text "Recurring rule created"
    rule = RecurringRule.find_by!(description: "Weekly savings")
    assert_not_empty rule.transactions
    assert rule.transactions.all? { |transaction| transaction.linked_transaction.present? }
  end

  test "owner reviews and confirms reconciliation including today's transaction" do
    checking, = create_accounts
    yesterday = Transaction.create!(
      account: checking,
      description: "Yesterday",
      amount: -10,
      date: Date.current - 1.day,
      status: :actual
    )
    today = Transaction.create!(
      account: checking,
      description: "Today",
      amount: -5,
      date: Date.current,
      status: :actual
    )

    visit root_path(account_id: checking.id)
    fill_in "current_balance", with: "900.00"
    fill_in "reconcile_balance_date", with: Date.current
    click_button "Reconcile ✓"
    assert_text "Set balance to $900.00"
    assert_text "Also clear 1 transaction from today"
    check "include_today_transactions"
    click_button "Confirm Reconcile"

    assert_current_path root_path, ignore_query: true
    assert_text "Reconciled! Removed 2 old transactions."
    assert_equal 900, checking.reload.current_balance
    refute Transaction.exists?(yesterday.id)
    refute Transaction.exists?(today.id)
  end

  private

  def create_accounts
    [
      Account.create!(name: "Checking", current_balance: 1_000, balance_date: Date.current),
      Account.create!(name: "Savings", account_type: :savings, current_balance: 500, balance_date: Date.current)
    ]
  end
end
