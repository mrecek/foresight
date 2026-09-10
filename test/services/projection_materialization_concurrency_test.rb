# frozen_string_literal: true

require "test_helper"

class ProjectionMaterializationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    clear_data
    @account = Account.create!(name: "Checking", current_balance: 100, balance_date: Date.current)
    @rule = RecurringRule.create!(
      account: @account,
      description: "Concurrent projection",
      amount: 10,
      rule_type: :expense,
      frequency: :daily,
      anchor_date: Date.current,
      active: true
    )
  end

  teardown { clear_data }

  test "concurrent materialization produces one occurrence per date" do
    through = Date.current + 14.days
    errors = run_threads(3) do
      ProjectionMaterializer.materialize(RecurringRule.find(@rule.id), through: through)
    end

    assert_empty errors
    assert_equal (Date.current..through).to_a,
      @rule.transactions.where(account: @account).order(:date).pluck(:date)
  end

  private

  def run_threads(count)
    ready = Queue.new
    start = Queue.new
    errors = Queue.new
    threads = count.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          connection.execute("PRAGMA busy_timeout = 100")
          ready << true
          start.pop
          yield
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

  def clear_data
    Transaction.delete_all
    RecurringRule.delete_all
    Account.delete_all
  end
end
