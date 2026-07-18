require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @original_test_mode = ENV["TEST_MODE"]
    ENV["TEST_MODE"] = "true"

    @checking = Account.create!(
      name: "Checking",
      account_type: :checking,
      current_balance: 1000.0,
      balance_date: Date.current,
      warning_threshold: 100.0
    )

    @savings = Account.create!(
      name: "Savings",
      account_type: :savings,
      current_balance: 5000.0,
      balance_date: Date.current,
      warning_threshold: 100.0
    )
  end

  def teardown
    ENV["TEST_MODE"] = @original_test_mode
  end

  test "destroy with valid return_url deletes linked transfer pair and redirects back" do
    txn = Transaction.create!(
      account: @checking,
      destination_account_id: @savings.id,
      description: "Transfer to savings",
      amount: -125.0,
      date: Date.current + 1.day,
      status: :estimated
    )
    linked_id = txn.linked_transaction_id
    return_url = "/?account_id=#{@checking.id}&months=6"

    assert_difference("Transaction.count", -2) do
      delete transaction_path(txn, return_url: return_url)
    end

    assert_redirected_to return_url
    assert_not Transaction.exists?(txn.id)
    assert_not Transaction.exists?(linked_id)
  end

  test "create with a valid return_url redirects back to the originating page" do
    return_url = "/?account_id=#{@checking.id}&months=6"

    assert_difference("Transaction.count", 1) do
      post transactions_path, params: {
        transaction: {
          account_id: @checking.id,
          description: "Dashboard expense",
          amount: -45.0,
          date: Date.current,
          status: "actual"
        },
        return_url: return_url
      }
    end

    assert_redirected_to return_url
  end

  test "create validation failure retains the return_url" do
    return_url = "/?account_id=#{@checking.id}&months=6"

    assert_no_difference("Transaction.count") do
      post transactions_path, params: {
        transaction: {
          account_id: @checking.id,
          description: "",
          amount: -45.0,
          date: Date.current,
          status: "actual"
        },
        return_url: return_url
      }
    end

    assert_response :unprocessable_entity
    assert_select "input[name='return_url'][value='#{return_url}']"
  end

  test "create with an unsafe return_url redirects to transactions index" do
    assert_difference("Transaction.count", 1) do
      post transactions_path, params: {
        transaction: {
          account_id: @checking.id,
          description: "Unsafe return URL",
          amount: -45.0,
          date: Date.current,
          status: "actual"
        },
        return_url: "//evil.com"
      }
    end

    assert_redirected_to transactions_path
  end

  test "destroy without return_url redirects to transactions index" do
    txn = Transaction.create!(
      account: @checking,
      description: "One-time expense",
      amount: -45.0,
      date: Date.current + 1.day,
      status: :estimated
    )

    assert_difference("Transaction.count", -1) do
      delete transaction_path(txn)
    end

    assert_redirected_to transactions_path
  end

  test "destroy with unsafe return_url redirects to transactions index" do
    txn = Transaction.create!(
      account: @checking,
      description: "Unsafe redirect attempt",
      amount: -12.0,
      date: Date.current + 1.day,
      status: :estimated
    )

    assert_difference("Transaction.count", -1) do
      delete transaction_path(txn, return_url: "//evil.com")
    end

    assert_redirected_to transactions_path
  end

  test "destroy failure redirects to safe return_url" do
    fake_transaction = Object.new
    fake_transaction.define_singleton_method(:linked_transaction) { nil }
    fake_transaction.define_singleton_method(:destroy!) do
      raise ActiveRecord::RecordNotDestroyed.new("Could not destroy transaction", Transaction.new)
    end

    relation = Object.new
    relation.define_singleton_method(:find) { |_id| fake_transaction }

    transaction_singleton = class << Transaction
      self
    end
    audit_log_singleton = class << AuditLog
      self
    end

    original_includes = transaction_singleton.instance_method(:includes)
    original_log_delete = audit_log_singleton.instance_method(:log_delete)

    transaction_singleton.define_method(:includes) do |*|
      relation
    end

    audit_log_singleton.define_method(:log_delete) do |*|
      true
    end

    delete transaction_path(999_999, return_url: "/?account_id=#{@checking.id}&months=3")
    assert_redirected_to "/?account_id=#{@checking.id}&months=3"
  ensure
    transaction_singleton.define_method(:includes, original_includes)
    audit_log_singleton.define_method(:log_delete, original_log_delete)
  end

  test "destroy with javascript return_url redirects to transactions index" do
    txn = Transaction.create!(
      account: @checking,
      description: "Javascript redirect attempt",
      amount: -18.0,
      date: Date.current + 1.day,
      status: :estimated
    )

    assert_difference("Transaction.count", -1) do
      delete transaction_path(txn, return_url: "javascript:alert(1)")
    end

    assert_redirected_to transactions_path
  end

  test "confirm actual prefers explicit return_url over the referrer" do
    txn = estimated_transaction
    return_url = "/?account_id=#{@checking.id}&months=6"

    get confirm_actual_transaction_path(txn, return_url: return_url),
      headers: { "HTTP_REFERER" => transactions_url }

    assert_response :success
    assert_select "input[name='return_url'][value='#{return_url}']"
    assert_select "a[href='#{return_url}']", text: "Cancel"
  end

  test "mark actual redirects to the originating dashboard state" do
    txn = estimated_transaction(amount: -75.0)
    return_url = "/?account_id=#{@checking.id}&months=6"

    patch mark_actual_transaction_path(txn), params: {
      amount: "82.45",
      original_sign: "-1",
      return_url: return_url
    }

    assert_redirected_to return_url
    txn.reload
    assert_predicate txn, :actual?
    assert_equal BigDecimal("-82.45"), txn.amount
    assert_predicate txn, :user_modified?
  end

  test "invalid actual amount re-renders the form with its return_url" do
    txn = estimated_transaction
    return_url = "/?account_id=#{@checking.id}&months=3"

    patch mark_actual_transaction_path(txn), params: {
      amount: "0",
      original_sign: "-1",
      return_url: return_url
    }

    assert_response :unprocessable_entity
    assert_select ".alert-danger", text: /Amount must be greater than zero/
    assert_select "input[name='return_url'][value='#{return_url}']"
    assert_predicate txn.reload, :estimated?
  end

  test "mark actual rejects an external return_url" do
    txn = estimated_transaction

    patch mark_actual_transaction_path(txn), params: {
      amount: "40.00",
      original_sign: "-1",
      return_url: "//evil.example/path"
    }

    assert_redirected_to transactions_path
  end

  private

  def estimated_transaction(amount: -45.0)
    Transaction.create!(
      account: @checking,
      description: "Upcoming expense",
      amount: amount,
      date: Date.current + 1.day,
      status: :estimated
    )
  end
end
