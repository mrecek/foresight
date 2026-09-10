# frozen_string_literal: true

require "test_helper"

class ReadOnlyRequestsTest < ActionDispatch::IntegrationTest
  APPLICATION_TABLES = %w[
    accounts audit_logs categories category_groups recurring_rules settings transactions
  ].freeze

  setup do
    @original_test_mode = ENV["TEST_MODE"]
    ENV["TEST_MODE"] = "true"
    @account = Account.create!(name: "Checking", current_balance: 100, balance_date: Date.current)
    @rule = create_recurring_rule!(
      account: @account,
      description: "Monthly bill",
      amount: 10,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current
    )
    @group = CategoryGroup.create!(name: "Living", color: "teal")
    @category = @group.categories.create!(name: "Rent")
  end

  teardown { @original_test_mode.nil? ? ENV.delete("TEST_MODE") : ENV["TEST_MODE"] = @original_test_mode }

  test "all application GET pages are free of domain writes" do
    writes = []
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      sql = payload[:sql]
      next unless sql.match?(/\A(?:INSERT|UPDATE|DELETE)/i)
      next unless APPLICATION_TABLES.any? { |table| sql.match?(/\b#{table}\b/i) }

      writes << sql
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      get_and_assert root_path(account_id: @account.id)
      get_and_assert accounts_path
      get_and_assert new_account_path
      get_and_assert account_path(@account)
      get_and_assert edit_account_path(@account)
      get_and_assert recurring_rules_path
      get_and_assert new_recurring_rule_path
      get_and_assert recurring_rule_path(@rule)
      get_and_assert edit_recurring_rule_path(@rule)
      get_and_assert category_groups_path
      get_and_assert new_category_group_path
      get_and_assert edit_category_group_path(@group)
      get_and_assert new_category_group_category_path(@group)
      get_and_assert edit_category_group_category_path(@group, @category)
      get_and_assert edit_settings_path
    end

    assert_empty writes
  end

  private

  def get_and_assert(path)
    get path
    assert_response :success
  end
end
