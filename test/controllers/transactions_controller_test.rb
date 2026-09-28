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

  test "editing either side of a transfer uses the sending account" do
    source = create_transfer

    [ source, source.linked_transaction ].each do |side|
      get edit_transaction_path(side)

      assert_response :success
      assert_select "form[action='#{transaction_path(source)}']"
      assert_select "select#transaction_account_id option[value='#{@savings.id}'][selected]"
      assert_select "select#transaction_destination_account_id option[value='#{@checking.id}'][selected]"
    end
  end

  test "transfer account changes use the submitted destination" do
    source = create_transfer
    third = Account.create!(name: "Third", account_type: :checking, current_balance: 100,
      balance_date: Date.current, warning_threshold: 10)

    patch transaction_path(source), params: { transaction: {
      account_id: @checking.id, destination_account_id: third.id,
      description: source.description, amount: -75, date: source.date, status: source.status
    } }

    assert_redirected_to transactions_path
    assert_equal @checking, source.reload.account
    assert_equal third, source.linked_transaction.account
    assert_equal(-75, source.amount)
    assert_equal 75, source.linked_transaction.amount
  end

  test "invalid transfer account choice remains selected after validation" do
    source = create_transfer

    patch transaction_path(source), params: { transaction: {
      account_id: @checking.id, destination_account_id: @checking.id,
      description: source.description, amount: -75, date: source.date, status: source.status
    } }

    assert_response :unprocessable_entity
    assert_select ".alert-danger", text: /cannot be the same as the source account/
    assert_select "select#transaction_account_id option[value='#{@checking.id}'][selected]"
    assert_select "select#transaction_destination_account_id option[value='#{@checking.id}'][selected]"
    assert_equal @savings, source.reload.account
    assert_equal @checking, source.linked_transaction.account
  end

  test "a stale incoming transfer form cannot reverse the transfer" do
    source = create_transfer
    incoming = source.linked_transaction

    patch transaction_path(incoming), params: { transaction: {
      account_id: @checking.id, destination_account_id: @savings.id,
      description: source.description, amount: -75, date: source.date, status: source.status
    } }

    assert_redirected_to edit_transaction_path(source, return_url: transactions_path)
    assert_equal(-75, source.reload.amount)
    assert_equal 75, incoming.reload.amount
  end

  test "editing a recurring transfer account survives later rule regeneration" do
    rule = create_recurring_transfer_rule
    source = rule.transactions.where(account: @checking).where("date > ?", Date.current).first!
    third = Account.create!(name: "Third", current_balance: 100, balance_date: Date.current)

    patch transaction_path(source), params: { transaction: recurring_transfer_params(source).merge(account_id: third.id) }

    assert_redirected_to transactions_path
    assert_predicate source.reload, :user_modified?
    assert_predicate source.linked_transaction, :user_modified?
    assert_equal third, source.account

    RecurringRuleCommand.update(rule, amount: 30)

    assert Transaction.exists?(source.id)
    assert_equal third, source.reload.account
    assert_equal(-20, source.amount)
    assert_equal @savings, source.linked_transaction.account
  end

  test "other recurring transaction field changes are protected" do
    third = Account.create!(name: "Third", current_balance: 100, balance_date: Date.current)
    category = Category.uncategorized

    [
      { destination_account_id: third.id },
      { status: "actual" },
      { category_id: category.id }
    ].each do |change|
      rule = create_recurring_transfer_rule
      source = rule.transactions.where(account: @checking).where("date > ?", Date.current).first!

      patch transaction_path(source), params: { transaction: recurring_transfer_params(source).merge(change) }

      assert_redirected_to transactions_path
      assert_predicate source.reload, :user_modified?
      assert_predicate source.linked_transaction, :user_modified?
    end
  end

  test "saving an unchanged recurring transfer keeps it automatic" do
    rule = create_recurring_transfer_rule
    source = rule.transactions.where(account: @checking).where("date > ?", Date.current).first!

    patch transaction_path(source), params: { transaction: recurring_transfer_params(source) }

    assert_redirected_to transactions_path
    assert_not source.reload.user_modified?
    assert_not source.linked_transaction.user_modified?
  end

  test "destroy with valid return_url deletes linked transfer pair and redirects back" do
    txn = TransferCommand.create(
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

  def create_transfer
    TransferCommand.create(
      account: @savings, destination_account_id: @checking.id,
      description: "Savings to checking", amount: -75,
      date: Date.current + 1.day, status: :estimated
    )
  end

  def create_recurring_transfer_rule
    RecurringRuleCommand.create(RecurringRule.new(
      account: @checking, destination_account: @savings,
      description: "Monthly transfer", amount: 20,
      rule_type: :transfer, frequency: :monthly,
      anchor_date: Date.current, active: true, is_estimated: true
    ))
  end

  def recurring_transfer_params(transaction)
    {
      account_id: transaction.account_id,
      destination_account_id: transaction.linked_transaction.account_id,
      description: transaction.description,
      amount: transaction.amount,
      date: transaction.date,
      status: transaction.status
    }
  end

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
