# frozen_string_literal: true

require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_test_mode = ENV["TEST_MODE"]
    ENV["TEST_MODE"] = "true"
    @account = Account.create!(
      name: "Checking",
      account_type: :checking,
      current_balance: 1_000,
      balance_date: Date.current,
      warning_threshold: 100
    )
  end

  teardown { @original_test_mode.nil? ? ENV.delete("TEST_MODE") : ENV["TEST_MODE"] = @original_test_mode }

  test "account pages render" do
    get accounts_path
    assert_response :success
    get new_account_path
    assert_response :success
    get account_path(@account)
    assert_response :success
    get edit_account_path(@account)
    assert_response :success
  end

  test "create update and destroy persist matching audit events" do
    assert_difference([ "Account.count", "AuditLog.where(action: 'create').count" ], 1) do
      post accounts_path, params: { account: valid_attributes(name: "Savings") }
    end
    created = Account.find_by!(name: "Savings")
    assert_redirected_to accounts_path

    assert_difference("AuditLog.where(action: 'update').count", 1) do
      patch account_path(created), params: { account: valid_attributes(name: "Emergency fund") }
    end
    assert_redirected_to accounts_path
    assert_equal "Emergency fund", created.reload.name

    assert_difference([ "Account.count" ], -1) do
      assert_difference("AuditLog.where(action: 'delete').count", 1) do
        delete account_path(created)
      end
    end
    assert_redirected_to accounts_path
  end

  test "invalid create and update render errors without persistence or audit" do
    assert_no_difference([ "Account.count", "AuditLog.count" ]) do
      post accounts_path, params: { account: valid_attributes(name: "") }
    end
    assert_response :unprocessable_entity

    assert_no_difference("AuditLog.count") do
      patch account_path(@account), params: { account: valid_attributes(balance_date: Date.current + 1.day) }
    end
    assert_response :unprocessable_entity
    assert_equal Date.current, @account.reload.balance_date
  end

  test "reconciliation updates the balance and removes covered transactions atomically" do
    old = Transaction.create!(
      account: @account,
      description: "Covered purchase",
      amount: -20,
      date: Date.current - 2.days,
      status: :actual
    )

    assert_difference("AuditLog.where(action: 'update').count", 1) do
      patch reconcile_account_path(@account), params: {
        current_balance: 980,
        balance_date: Date.current - 1.day
      }
    end

    assert_redirected_to root_path(account_id: @account.id)
    assert_equal 980, @account.reload.current_balance
    refute Transaction.exists?(old.id)
  end

  test "invalid reconciliation reports failure without changing data or audit history" do
    assert_no_difference("AuditLog.count") do
      patch reconcile_account_path(@account), params: {
        current_balance: 500,
        balance_date: Date.current + 1.day
      }
    end

    assert_redirected_to root_path(account_id: @account.id)
    assert_equal 1_000, @account.reload.current_balance
    assert_equal Date.current, @account.balance_date
  end

  private

  def valid_attributes(overrides = {})
    {
      name: "Account",
      account_type: "checking",
      current_balance: "100.00",
      balance_date: Date.current,
      warning_threshold: "0.00"
    }.merge(overrides)
  end
end
