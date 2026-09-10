# frozen_string_literal: true

require "test_helper"

class RecurringRuleCommandTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(name: "Checking", current_balance: 100, balance_date: Date.current)
  end

  test "projection failure rolls back rule creation" do
    rule = build_rule

    with_replacement(ProjectionMaterializer, :materialize, ->(*) { raise "projection failed" }) do
      assert_no_difference([ "RecurringRule.count", "Transaction.count" ]) do
        assert_raises(RuntimeError) { RecurringRuleCommand.create(rule) }
      end
    end
  end

  test "audit failure rolls back schedule update and regeneration" do
    rule = RecurringRuleCommand.create(build_rule)
    original_ids = rule.transactions.ids.sort

    assert_raises(RuntimeError) do
      RecurringRuleCommand.update(rule, { frequency: :weekly }) { raise "audit failed" }
    end

    assert_equal "monthly", rule.reload.frequency
    assert_equal original_ids, rule.transactions.ids.sort
  end

  test "deactivation and occurrence cleanup roll back together" do
    rule = RecurringRuleCommand.create(build_rule(frequency: :weekly))
    original_count = rule.transactions.count
    calls = 0
    original = TransferCommand.method(:destroy)
    failing_destroy = lambda do |transaction, **options, &block|
      calls += 1
      original.call(transaction, **options, &block)
      raise "cleanup failed" if calls == 2
    end

    with_replacement(TransferCommand, :destroy, failing_destroy) do
      assert_raises(RuntimeError) { RecurringRuleCommand.update(rule, { active: false }) }
    end

    assert rule.reload.active?
    assert_equal original_count, rule.transactions.count
  end

  private

  def build_rule(**attributes)
    RecurringRule.new({
      account: @account,
      description: "Rule",
      amount: 25,
      rule_type: :expense,
      frequency: :monthly,
      anchor_date: Date.current,
      active: true
    }.merge(attributes))
  end

  def with_replacement(target, method_name, replacement)
    singleton = class << target
      self
    end
    original = singleton.instance_method(method_name)
    singleton.define_method(method_name, replacement)
    yield
  ensure
    singleton.define_method(method_name, original)
  end
end
