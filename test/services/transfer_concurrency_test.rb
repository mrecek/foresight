require "test_helper"

class TransferConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    clear_financial_data
    @checking = Account.create!(name: "Checking", current_balance: 100, balance_date: Date.current)
    @savings = Account.create!(name: "Savings", current_balance: 100, balance_date: Date.current)
  end

  teardown { clear_financial_data }

  test "simultaneous creates remain complete and distinct" do
    errors = run_threads(4) do |index|
      TransferCommand.create(
        account_id: @checking.id,
        destination_account_id: @savings.id,
        amount: -(index + 1),
        description: "Concurrent #{index}",
        date: Date.current,
        status: :actual
      )
    end

    assert_empty errors
    assert_equal 8, Transaction.count
    assert_empty TransferPairIntegrity.check
  end

  test "simultaneous updates serialize without mismatched pairs" do
    source = create_pair
    errors = run_threads(2) do |index|
      transaction = Transaction.find(source.id)
      TransferCommand.update(transaction, amount: -(50 + index), description: "Update #{index}")
    end

    assert_empty errors
    source.reload
    assert_equal(-source.amount, source.linked_transaction.amount)
    assert_equal source.description, source.linked_transaction.description
    assert_empty TransferPairIntegrity.check
  end

  test "simultaneous delete attempts never leave one side" do
    source = create_pair
    errors = run_threads(2) do
      transaction = Transaction.find_by(id: source.id)
      TransferCommand.destroy(transaction) if transaction
    end

    assert errors.all? { |error| error.is_a?(ActiveRecord::RecordNotFound) || error.is_a?(ActiveRecord::StatementInvalid) }, errors.inspect
    assert_equal 0, Transaction.count
    assert_empty TransferPairIntegrity.check
  end

  test "repeated conversion and pair deletion leave no intermittent corruption" do
    10.times do |index|
      source = create_pair(description: "Round #{index}")
      TransferCommand.update(source, destination_account_id: nil)
      assert_empty TransferPairIntegrity.check
      source = TransferCommand.update(source, destination_account_id: @savings.id)
      TransferCommand.destroy(source)
      assert_empty TransferPairIntegrity.check
    end
  end

  private

  def create_pair(description: "Transfer")
    TransferCommand.create(
      account: @checking,
      destination_account_id: @savings.id,
      amount: -25,
      description: description,
      date: Date.current,
      status: :actual
    )
  end

  def run_threads(count)
    ready = Queue.new
    start = Queue.new
    errors = Queue.new
    threads = count.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          connection.execute("PRAGMA busy_timeout = 100")
          ready << true
          start.pop
          yield index
        rescue StandardError => error
          errors << error
        end
      end
    end
    count.times { ready.pop }
    count.times { start << true }
    threads.each(&:join)
    Array.new(errors.size) { errors.pop }
  end

  def clear_financial_data
    AuditLog.delete_all
    Transaction.delete_all
    RecurringRule.delete_all
    Category.delete_all
    CategoryGroup.delete_all
    Account.delete_all
  end
end
