require "test_helper"
require Rails.root.join("db/migrate/20260910010000_preflight_transfer_pair_integrity")

class TransferPairIntegrityTest < ActiveSupport::TestCase
  setup do
    @checking = Account.create!(name: "Checking", current_balance: 100, balance_date: Date.current)
    @savings = Account.create!(name: "Savings", current_balance: 100, balance_date: Date.current)
  end

  test "valid reciprocal pair passes and repair is a no-op" do
    left, right = pair

    assert_empty TransferPairIntegrity.check
    issues, changes = TransferPairIntegrity.repair
    assert_empty issues
    assert_empty changes
    assert_equal right.id, left.reload.linked_transaction_id
  end

  test "dry run reports structural account and metadata corruption without mutation" do
    one_way_left, one_way_right = pair(linked: false)
    one_way_left.update_column(:linked_transaction_id, one_way_right.id)

    same_left, same_right = pair(accounts: [ @checking, @checking ])
    mismatch_left, mismatch_right = pair
    mismatch_right.update_column(:description, "Different")
    mismatch_right.update_column(:amount, 99)

    original_links = Transaction.order(:id).pluck(:id, :linked_transaction_id)
    types = TransferPairIntegrity.check.map(&:type)

    assert_includes types, :one_way_link
    assert_includes types, :invalid_accounts
    assert_includes types, :amount_mismatch
    assert_includes types, :metadata_mismatch
    assert_equal original_links, Transaction.order(:id).pluck(:id, :linked_transaction_id)
  end

  test "checker reports a missing counterpart without loading the association" do
    values = [ [ 42, 999, @checking.id, -10, "Transfer", Date.current, "actual", nil, nil, false, nil ] ]
    scope = Object.new
    scope.define_singleton_method(:pluck) { |*_columns| values }

    issues = TransferPairIntegrity.new(scope).check

    assert_equal [ :missing_counterpart ], issues.map(&:type)
    assert_equal [ 42, 999 ], issues.first.transaction_ids
  end

  test "checker reports self-links and many-to-one legacy corruption" do
    today = Date.current
    values = [
      [ 1, 3, @checking.id, -10, "Transfer", today, "actual", nil, nil, false, nil ],
      [ 2, 3, @checking.id, -10, "Transfer", today, "actual", nil, nil, false, nil ],
      [ 3, nil, @savings.id, 10, "Transfer", today, "actual", nil, nil, false, nil ],
      [ 4, 4, @checking.id, -5, "Self", today, "actual", nil, nil, false, nil ]
    ]
    scope = Object.new
    scope.define_singleton_method(:pluck) { |*_columns| values }

    types = TransferPairIntegrity.new(scope).check.map(&:type)

    assert_includes types, :many_to_one
    assert_includes types, :self_link
  end

  test "repair restores an unambiguous back-link and unlinks ambiguous data" do
    one_way_left, one_way_right = pair(linked: false)
    one_way_left.update_column(:linked_transaction_id, one_way_right.id)
    mismatch_left, mismatch_right = pair
    mismatch_right.update_column(:amount, 99)

    issues, changes = TransferPairIntegrity.repair

    assert issues.any?
    assert changes.any?
    assert_equal one_way_left.id, one_way_right.reload.linked_transaction_id
    assert_nil mismatch_left.reload.linked_transaction_id
    assert_nil mismatch_right.reload.linked_transaction_id
    assert_empty TransferPairIntegrity.check
    assert_empty TransferPairIntegrity.repair.last
  end

  test "migration preflight refuses unresolved corruption" do
    left, right = pair
    right.update_column(:description, "Conflicting data")

    error = assert_raises(ActiveRecord::MigrationError) do
      PreflightTransferPairIntegrity.new.migrate(:up)
    end
    assert_includes error.message, "bin/transfers --repair"
  end

  private

  def pair(linked: true, accounts: [ @checking, @savings ])
    left = transaction(accounts.first, -10)
    right = transaction(accounts.last, 10)
    if linked
      left.update_column(:linked_transaction_id, right.id)
      right.update_column(:linked_transaction_id, left.id)
    end
    [ left, right ]
  end

  def transaction(account, amount)
    Transaction.create!(
      account: account,
      amount: amount,
      description: "Transfer",
      date: Date.current,
      status: :actual,
      user_modified: false
    )
  end
end
