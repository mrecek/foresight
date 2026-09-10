# frozen_string_literal: true

require "test_helper"

class RecurringRulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_test_mode = ENV["TEST_MODE"]
    ENV["TEST_MODE"] = "true"
    @account = Account.create!(name: "Checking", current_balance: 1_000, balance_date: Date.current)
  end

  teardown { @original_test_mode.nil? ? ENV.delete("TEST_MODE") : ENV["TEST_MODE"] = @original_test_mode }

  test "recurring rule pages render" do
    rule = create_recurring_rule!(**valid_attributes)

    get recurring_rules_path
    assert_response :success
    get new_recurring_rule_path
    assert_response :success
    get recurring_rule_path(rule)
    assert_response :success
    get edit_recurring_rule_path(rule)
    assert_response :success
  end

  test "create update and destroy use the transactional rule command" do
    assert_difference([ "RecurringRule.count", "AuditLog.where(action: 'create').count" ], 1) do
      post recurring_rules_path, params: { recurring_rule: valid_attributes }
    end
    rule = RecurringRule.order(:id).last
    assert_redirected_to recurring_rules_path
    assert_not_empty rule.transactions

    old_ids = rule.transactions.ids.sort
    assert_difference("AuditLog.where(action: 'update').count", 1) do
      patch recurring_rule_path(rule), params: {
        recurring_rule: valid_attributes.merge(frequency: "weekly", amount: "12.00")
      }
    end
    assert_redirected_to recurring_rules_path
    assert_equal "weekly", rule.reload.frequency
    refute_equal old_ids, rule.transactions.ids.sort

    assert_difference([ "RecurringRule.count" ], -1) do
      assert_difference("AuditLog.where(action: 'delete').count", 1) do
        delete recurring_rule_path(rule)
      end
    end
    assert_redirected_to recurring_rules_path
    assert_empty Transaction.where(recurring_rule_id: rule.id)
  end

  test "invalid create and update render errors with no partial changes" do
    assert_no_difference([ "RecurringRule.count", "Transaction.count", "AuditLog.count" ]) do
      post recurring_rules_path, params: { recurring_rule: valid_attributes.merge(description: "") }
    end
    assert_response :unprocessable_entity

    rule = create_recurring_rule!(**valid_attributes)
    original_count = rule.transactions.count
    assert_no_difference("AuditLog.count") do
      patch recurring_rule_path(rule), params: { recurring_rule: valid_attributes.merge(amount: "-1") }
    end
    assert_response :unprocessable_entity
    assert_equal 10, rule.reload.amount
    assert_equal original_count, rule.transactions.count
  end

  private

  def valid_attributes
    {
      account_id: @account.id,
      rule_type: "expense",
      description: "Monthly service",
      amount: "10.00",
      frequency: "monthly",
      anchor_date: Date.current,
      day_of_month: Date.current.day,
      is_estimated: "1",
      active: "1"
    }
  end
end
