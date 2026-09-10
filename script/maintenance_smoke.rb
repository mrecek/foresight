# frozen_string_literal: true

account = Account.create!(
  name: "Packaged maintenance smoke",
  current_balance: 100,
  balance_date: Date.current
)
rule = RecurringRule.create!(
  account: account,
  description: "Daily smoke projection",
  amount: 1,
  rule_type: :expense,
  frequency: :daily,
  anchor_date: Date.current,
  active: true
)
raise "recurring-rule persistence unexpectedly materialized projections" if rule.transactions.exists?

MaintainProjectionsJob.perform_now
expected_horizon = ProjectionMaterializer.horizon
raise "projection maintenance did not execute through its horizon" unless rule.transactions.maximum(:date) == expected_horizon

expired_login = AuditLog.create!(action: "login_failure", created_at: 91.days.ago)
financial_event = AuditLog.create!(action: "update", resource_type: "Account", resource_id: account.id, created_at: 1.year.ago)
PruneAuthenticationAuditLogsJob.perform_now
raise "authentication maintenance did not remove expired event" if AuditLog.exists?(expired_login.id)
raise "authentication maintenance removed financial history" unless AuditLog.exists?(financial_event.id)

puts "Packaged maintenance execution passed."
