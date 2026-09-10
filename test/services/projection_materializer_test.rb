# frozen_string_literal: true

require "test_helper"

class ProjectionMaterializerTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @account = Account.create!(
      name: "Projection account",
      account_type: :checking,
      current_balance: 1_000,
      balance_date: Date.current,
      warning_threshold: 0
    )
  end

  test "plain record persistence has no projection side effect" do
    rule = raw_rule

    assert rule.save!
    assert_empty rule.transactions
  end

  test "the rule command materializes every frequency through the fixed horizon" do
    RecurringRule.frequencies.each_key do |frequency|
      rule = RecurringRuleCommand.create(raw_rule(frequency: frequency))
      expected = RecurrenceCalculator.new(rule).dates_between(Date.current, ProjectionMaterializer.horizon)
      actual = rule.transactions.where(account: @account).order(:date).pluck(:date)

      assert_equal expected, actual, frequency
    end
  end

  test "materialization preserves a moved occurrence and its original-date exclusion" do
    rule = RecurringRuleCommand.create(raw_rule(frequency: :weekly))
    occurrence = rule.transactions.where(account: @account).order(:date).first!
    original_date = occurrence.date
    moved_date = original_date + 1.day
    TransferCommand.update(
      occurrence,
      date: moved_date,
      original_date: original_date,
      user_modified: true
    )

    ProjectionMaterializer.materialize(rule)

    assert_equal 0, rule.transactions.where(account: @account, date: original_date).count
    assert_equal 1, rule.transactions.where(account: @account, date: moved_date).count
  end

  test "batch processing reports a bad rule after materializing later rules" do
    invalid = raw_rule(rule_type: :transfer, destination_account: @account)
    invalid.save!(validate: false)
    valid = raw_rule(description: "Later valid rule")
    valid.save!

    error = assert_raises(ProjectionMaterializer::BatchError) do
      ProjectionMaterializer.materialize_all(through: Date.current + 1.day)
    end

    assert error.failures.key?(invalid.id)
    assert_not_empty valid.transactions
  end

  test "materialization uses the local date and horizon in different zones" do
    travel_to Time.utc(2026, 1, 1, 7, 30) do
      {
        "America/Los_Angeles" => Date.new(2025, 12, 31),
        "Asia/Tokyo" => Date.new(2026, 1, 1)
      }.each do |zone, local_date|
        Time.use_zone(zone) do
          rule = raw_rule(description: zone, frequency: :daily, anchor_date: Date.new(2025, 12, 1))
          rule.save!
          ProjectionMaterializer.materialize(rule, through: local_date + 1.day)

          assert_equal [ local_date, local_date + 1.day ], rule.transactions.order(:date).pluck(:date)
          assert_equal local_date.advance(months: 24), ProjectionMaterializer.horizon
        end
      end
    end
  end

  private

  def raw_rule(**attributes)
    RecurringRule.new({
      account: @account,
      description: "Projection rule",
      amount: 10,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current,
      active: true
    }.merge(attributes))
  end
end
