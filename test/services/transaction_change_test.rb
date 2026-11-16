require "test_helper"

class TransactionChangeTest < ActiveSupport::TestCase
  setup do
    @checking = Account.create!(name: "Checking", current_balance: 1000, balance_date: Date.current)
    @savings = Account.create!(name: "Savings", current_balance: 100, balance_date: Date.current)
    @context = AuditContext.new(remote_ip: "192.0.2.1", user_agent: "Operation test")
    @transaction = TransferCommand.create(account: @checking, description: "Savings", amount: -20,
      date: Date.current, status: :estimated, destination_account_id: @savings.id)
  end

  test "editing a transfer updates both sides and records one audit event" do
    assert_difference "AuditLog.count", 1 do
      edit(amount: "-25.12", description: "Reserve")
    end
    assert_equal BigDecimal("-25.12"), @transaction.reload.amount
    assert_equal BigDecimal("25.12"), @transaction.linked_transaction.amount
    assert_equal "Reserve", @transaction.linked_transaction.description
    assert_equal @context.remote_ip, AuditLog.last.ip_address
    assert_equal @transaction.id, @transaction.linked_transaction.linked_transaction_id
  end

  test "actual confirmation uses stored direction on either side" do
    TransactionChange.confirm_actual(@transaction, amount: "30.10", audit_context: @context)
    assert_equal BigDecimal("-30.10"), @transaction.reload.amount
    incoming = @transaction.linked_transaction
    TransactionChange.confirm_actual(incoming, amount: "40.20", audit_context: @context)
    assert_equal BigDecimal("40.20"), incoming.reload.amount
    assert_equal BigDecimal("-40.20"), @transaction.reload.amount
    assert_predicate @transaction, :actual?
    assert_predicate incoming, :user_modified?
  end

  test "invalid edits leave financial and audit state unchanged" do
    [ { amount: "NaN" }, { amount: "Infinity" }, { amount: "12oops" }, { amount: "1.234" },
      { amount: "10000000000" }, { date: "2026-02-30" }, { date: "" }, { status: "unknown" },
      { destination_account_id: "missing" }, { destination_account_id: 999999 },
      { destination_account_id: @checking.id }, { account_id: "" }, { description: "" } ].each do |attributes|
      before = Transaction.order(:id).map(&:attributes)
      assert_no_difference "AuditLog.count" do
        assert_raises(ActiveRecord::RecordInvalid, attributes.inspect) { edit(**attributes) }
      end
      assert_equal before, Transaction.order(:id).map(&:attributes), attributes.inspect
      @transaction.reload
    end
  end

  test "actual confirmation rejects missing zero and nonfinite amounts" do
    [ nil, "", "0", "NaN", "Infinity", "3.456", "20junk" ].each do |amount|
      assert_no_difference "AuditLog.count" do
        assert_raises(ActiveRecord::RecordInvalid) do
          TransactionChange.confirm_actual(@transaction, amount: amount, audit_context: @context)
        end
      end
      assert_equal(-20, @transaction.reload.amount)
      assert_equal 20, @transaction.linked_transaction.amount
    end
  end

  test "incoming transfer edit has an explicit validation outcome" do
    assert_raises ActiveRecord::RecordInvalid do
      TransactionChange.update(@transaction.linked_transaction, attributes: { amount: "50" }, audit_context: @context)
    end
    assert_equal(-20, @transaction.reload.amount)
  end

  test "recurring edits retain occurrence identity and preserve explicit changes" do
    rule = create_recurring_rule!(account: @checking, destination_account: @savings, description: "Weekly",
      amount: 10, rule_type: :transfer, frequency: :weekly, anchor_date: Date.current)
    @transaction = rule.transactions.find_by!(account_id: @checking.id, date: Date.current)
    original = @transaction.date
    edit(date: (original + 1.day).iso8601)
    assert_equal original, @transaction.reload.original_date
    assert_predicate @transaction, :user_modified?
    assert_no_difference "Transaction.count" do
      ProjectionMaterializer.materialize(rule)
    end
    edit(date: original.iso8601)
    assert_nil @transaction.reload.original_date
    assert_nil @transaction.linked_transaction.original_date
    assert_no_difference "Transaction.count" do
      ProjectionMaterializer.materialize(rule)
    end
    category_group = CategoryGroup.create!(name: "Living", color: "teal")
    category = category_group.categories.create!(name: "Reserve")
    edit(category_id: category.id, status: "actual", description: "Explicit", amount: BigDecimal("-12.30"))
    RecurringRuleCommand.update(rule, amount: 15)
    assert_equal BigDecimal("-12.30"), @transaction.reload.amount
    assert_equal category, @transaction.linked_transaction.category
    assert_equal "Explicit", @transaction.description
  end

  test "conversion to a regular transaction removes the counterpart" do
    counterpart = @transaction.linked_transaction_id
    edit(destination_account_id: "")
    assert_nil @transaction.reload.linked_transaction_id
    assert_not Transaction.exists?(counterpart)
  end

  test "counterpart failure rolls back the source and audit" do
    counterpart = @transaction.linked_transaction
    counterpart.define_singleton_method(:save!) { raise ActiveRecord::RecordInvalid, self }
    assert_no_difference "AuditLog.count" do
      assert_raises(ActiveRecord::RecordInvalid) { edit(amount: "-55") }
    end
    assert_equal(-20, @transaction.reload.amount)
    assert_equal 20, @transaction.linked_transaction.amount
  end

  test "audit failure rolls back edits and actual confirmation" do
    singleton = AuditLog.singleton_class
    original = singleton.instance_method(:log_update)
    singleton.define_method(:log_update) { |*| raise "audit unavailable" }
    [ -> { edit(amount: "-99") },
      -> { TransactionChange.confirm_actual(@transaction, amount: "88", audit_context: @context) } ].each do |operation|
      assert_no_difference "AuditLog.count" do
        assert_raises(RuntimeError) { operation.call }
      end
      assert_equal(-20, @transaction.reload.amount)
      assert_equal 20, @transaction.linked_transaction.amount
      assert_predicate @transaction, :estimated?
    end
  ensure
    singleton.define_method(:log_update, original) if original
  end

  private

  def edit(**attributes)
    TransactionChange.update(@transaction, attributes: attributes, audit_context: @context)
  end
end
