require "test_helper"

class TransferCommandTest < ActiveSupport::TestCase
  setup do
    @checking = Account.create!(name: "Checking", current_balance: 100, balance_date: Date.current)
    @savings = Account.create!(name: "Savings", current_balance: 100, balance_date: Date.current)
    @attributes = {
      account: @checking,
      destination_account_id: @savings.id,
      amount: -25,
      description: "Transfer",
      date: Date.current,
      status: :actual
    }
  end

  test "create update and delete commit complete pairs" do
    source = TransferCommand.create(@attributes)
    target = source.linked_transaction
    assert_equal source.id, target.linked_transaction_id
    assert_equal 25, target.amount

    TransferCommand.update(source, amount: -40, description: "Moved")
    assert_equal 40, target.reload.amount
    assert_equal "Moved", target.description

    assert_difference("Transaction.count", -2) { TransferCommand.destroy(source) }
  end

  test "invalid destination and audit failure roll back every row" do
    invalid = @attributes.merge(destination_account_id: 999_999)
    assert_no_difference("Transaction.count") do
      assert_raises(ActiveRecord::RecordInvalid) { TransferCommand.create(invalid) }
    end

    assert_no_difference([ "Transaction.count", "AuditLog.count" ]) do
      assert_raises(RuntimeError) do
        TransferCommand.create(@attributes) { raise "audit unavailable" }
      end
    end
  end

  test "update and delete failures retain both original rows" do
    source = TransferCommand.create(@attributes)
    target = source.linked_transaction

    assert_raises(RuntimeError) do
      TransferCommand.update(source, amount: -90) { raise "audit unavailable" }
    end
    assert_equal(-25, source.reload.amount)
    assert_equal 25, target.reload.amount

    assert_raises(RuntimeError) do
      TransferCommand.destroy(source) { raise "audit unavailable" }
    end
    assert Transaction.exists?(source.id)
    assert Transaction.exists?(target.id)
  end

  test "database rejects self-links and many-to-one links" do
    source = TransferCommand.create(@attributes)
    target = source.linked_transaction
    third = Transaction.create!(account: @checking, amount: -5, description: "Third", date: Date.current, status: :actual)

    assert_raises(ActiveRecord::StatementInvalid) { source.update_column(:linked_transaction_id, source.id) }
    assert_raises(ActiveRecord::RecordNotUnique) { third.update_column(:linked_transaction_id, target.id) }
  end

  test "busy retries are bounded" do
    attempts = 0
    result = TransferCommand.send(:with_busy_retry) do
      attempts += 1
      raise ActiveRecord::StatementInvalid.new("busy"), cause: SQLite3::BusyException.new("locked") if attempts < 3
      :ok
    end
    assert_equal :ok, result
    assert_equal 3, attempts

    attempts = 0
    assert_raises(ActiveRecord::StatementInvalid) do
      TransferCommand.send(:with_busy_retry) do
        attempts += 1
        raise ActiveRecord::StatementInvalid.new("busy"), cause: SQLite3::BusyException.new("locked")
      end
    end
    assert_equal TransferCommand::MAX_BUSY_ATTEMPTS, attempts
  end
end
