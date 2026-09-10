# frozen_string_literal: true

require "test_helper"

class MaintenanceJobsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Setting.instance.update!(default_view_months: 3)
  end

  test "projection maintenance converges to the current configured horizon after downtime" do
    account = Account.create!(
      name: "Scheduled checking",
      account_type: :checking,
      current_balance: 1_000,
      balance_date: Date.current,
      warning_threshold: 100
    )
    rule = create_recurring_rule!(
      account: account,
      description: "Monthly rent",
      amount: 500,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current,
      active: true
    )

    travel 2.months
    rule.transactions.delete_all

    MaintainProjectionsJob.perform_now
    expected_horizon = ProjectionMaterializer.horizon
    expected_last_occurrence = RecurrenceCalculator.new(rule).dates_between(Date.current, expected_horizon).last
    assert_equal expected_last_occurrence, rule.transactions.maximum(:date)

    assert_no_difference -> { rule.transactions.count } do
      MaintainProjectionsJob.perform_now
    end
  end

  test "audit maintenance expires authentication events and retains financial history" do
    old_login = AuditLog.create!(action: "login_failure", created_at: 91.days.ago)
    recent_login = AuditLog.create!(action: "login_success", created_at: 89.days.ago)
    old_financial_event = AuditLog.create!(
      action: "update",
      resource_type: "Account",
      resource_id: 42,
      created_at: 1.year.ago
    )

    assert_difference -> { AuditLog.count }, -1 do
      PruneAuthenticationAuditLogsJob.perform_now
    end

    refute AuditLog.exists?(old_login.id)
    assert AuditLog.exists?(recent_login.id)
    assert AuditLog.exists?(old_financial_event.id)

    assert_no_difference -> { AuditLog.count } do
      PruneAuthenticationAuditLogsJob.perform_now
    end
  end

  test "Solid Queue recurring schedules inherit the application timezone" do
    application_zone = ActiveSupport::TimeZone[Rails.application.config.time_zone]

    assert_equal application_zone.tzinfo.name, SolidQueue.time_zone
  end
end
