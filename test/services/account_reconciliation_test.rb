require "test_helper"

class AccountReconciliationTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(name: "Checking", current_balance: 100, balance_date: Date.current - 2.days)
    @other = Account.create!(name: "Savings", current_balance: 100, balance_date: Date.current)
    @context = AuditContext.new(remote_ip: "192.0.2.1", user_agent: "Reconciliation test")
    @transfer = TransferCommand.create(account: @account, destination_account_id: @other.id,
      description: "Transfer", amount: -10, date: Date.current - 1.day, status: :actual)
    @today = TransferCommand.create(account: @account, description: "Today", amount: -5,
      date: Date.current, status: :actual)
  end

  test "reconciliation retains counterpart history and excludes today unless requested" do
    counterpart = @transfer.linked_transaction
    result = reconcile
    assert_equal 1, result.deleted_count
    assert_equal 90, @account.reload.current_balance
    assert Transaction.exists?(@today.id)
    assert_equal 10, counterpart.reload.amount
    assert_nil counterpart.linked_transaction_id
    assert_equal 0, reconcile.deleted_count
    assert_equal 1, reconcile(include_today: true).deleted_count
    assert_not Transaction.exists?(@today.id)
  end

  test "invalid balance or date does not mutate financial or audit data" do
    [ { current_balance: "NaN" }, { current_balance: "12.345" }, { current_balance: "1junk" },
      { balance_date: "2026-02-30" }, { balance_date: (Date.current + 1.day).iso8601 } ].each do |values|
      assert_raises(ActiveRecord::RecordInvalid) { reconcile(**values) }
      assert_equal 100, @account.reload.current_balance
      assert Transaction.exists?(@transfer.id)
      assert_empty AuditLog.where(resource_type: "Account", resource_id: @account.id)
    end
  end

  test "audit failure restores account deleted rows and transfer links" do
    singleton = AuditLog.singleton_class
    original = singleton.instance_method(:log_update)
    singleton.define_method(:log_update) { |*| raise "audit unavailable" }
    assert_raises(RuntimeError) { reconcile(include_today: true) }
    assert_equal 100, @account.reload.current_balance
    assert Transaction.exists?(@today.id)
    assert_equal @transfer.id, @transfer.reload.linked_transaction.linked_transaction_id
  ensure
    singleton.define_method(:log_update, original) if original
  end

  test "a deletion failure rolls back the whole reconciliation" do
    singleton = TransferCommand.singleton_class
    original = singleton.instance_method(:destroy)
    singleton.define_method(:destroy) { |*args, **options| raise "delete unavailable" }
    assert_raises(RuntimeError) { reconcile }
    assert_equal 100, @account.reload.current_balance
    assert_equal @transfer.id, @transfer.reload.linked_transaction.linked_transaction_id
    assert_empty AuditLog.where(resource_type: "Account", resource_id: @account.id)
  ensure
    singleton.define_method(:destroy, original) if original
  end

  private

  def reconcile(include_today: false, **attributes)
    AccountReconciliation.call(account: @account,
      attributes: { current_balance: "90.00", balance_date: Date.current.iso8601 }.merge(attributes),
      include_today: include_today, audit_context: @context)
  end
end
