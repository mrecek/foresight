require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  def setup
    @original_test_mode = ENV["TEST_MODE"]
    ENV["TEST_MODE"] = "true"
    Setting.instance.update!(default_view_months: 3)

    @checking = Account.create!(
      name: "Checking",
      account_type: :checking,
      current_balance: 1_000.0,
      balance_date: Date.current,
      warning_threshold: 100.0
    )
    @savings = Account.create!(
      name: "Savings",
      account_type: :savings,
      current_balance: 2_000.0,
      balance_date: Date.current,
      warning_threshold: 100.0
    )
  end

  def teardown
    ENV["TEST_MODE"] = @original_test_mode
  end

  test "account cards use the selected range for lows and statuses" do
    Transaction.create!(
      account: @checking,
      description: "Checking annual expense",
      amount: -1_100.0,
      date: Date.current + 6.months,
      status: :estimated
    )
    Transaction.create!(
      account: @savings,
      description: "Savings annual expense",
      amount: -2_100.0,
      date: Date.current + 6.months,
      status: :estimated
    )

    get root_path(account_id: @checking.id, months: 12)

    assert_response :success
    assert_select "turbo-frame#transactions a.relative.block", count: 2
    assert_select ".status-dot-danger", count: 2
    assert_select "span", text: /-100\.00 low/, count: 2
  end

  test "extending the selected range generates projections for every card" do
    rule = RecurringRule.create!(
      account: @savings,
      description: "Savings monthly expense",
      amount: 100.0,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current + 1.month,
      active: true
    )

    get root_path(account_id: @checking.id, months: 12)

    assert_response :success
    assert_operator rule.transactions.maximum(:date), :>=, 12.months.from_now.to_date
  end

  test "already-negative accounts render a safe warning without a future alert date" do
    @checking.update!(current_balance: -100.0)
    Transaction.create!(
      account: @checking,
      description: "Future expense while negative",
      amount: -50.0,
      date: Date.current + 1.day,
      status: :estimated
    )

    get root_path(account_id: @checking.id, months: 3)

    assert_response :success
    assert_select "div", text: "Balance is already negative."
    assert_select "div", text: "Current balance: $-100.00"
    assert_select "div", text: /Goes negative/, count: 0
  end

  test "invalid dashboard ranges fall back to the default view period" do
    get root_path(account_id: @checking.id, months: 99)

    assert_response :success
    assert_select "a.bg-primary-600", text: "3 mo"
  end
end
