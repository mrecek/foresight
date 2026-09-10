# frozen_string_literal: true

require "test_helper"

class AuditedChangeTest < ActiveSupport::TestCase
  Request = Data.define(:remote_ip, :user_agent)

  setup do
    @request = Request.new("192.0.2.10", "Foresight test client")
  end

  test "create persists the record and audit event together" do
    account = build_account(name: "Created account")

    assert_difference([ "Account.count", "AuditLog.count" ], 1) do
      AuditedChange.create(account, @request)
    end

    audit = AuditLog.order(:id).last
    assert_equal "create", audit.action
    assert_equal account.id, audit.resource_id
  end

  test "update persists the change and audit event together" do
    account = create_account(name: "Before")

    assert_difference("AuditLog.count", 1) do
      AuditedChange.update(account, { name: "After" }, @request)
    end

    assert_equal "After", account.reload.name
    assert_equal "update", AuditLog.order(:id).last.action
  end

  test "destroy removes the record and writes its audit event together" do
    account = create_account

    assert_difference("Account.count", -1) do
      assert_difference("AuditLog.count", 1) do
        AuditedChange.destroy(account, @request)
      end
    end

    assert_equal "delete", AuditLog.order(:id).last.action
  end

  test "an audit failure rolls back create update and destroy" do
    error = ->(*) { raise ActiveRecord::RecordInvalid }

    with_audit_failure(:log_create, error) do
      assert_no_difference([ "Account.count", "AuditLog.count" ]) do
        assert_raises(ActiveRecord::RecordInvalid) { AuditedChange.create(build_account, @request) }
      end
    end

    account = create_account(name: "Stable")

    with_audit_failure(:log_update, error) do
      assert_no_difference("AuditLog.count") do
        assert_raises(ActiveRecord::RecordInvalid) do
          AuditedChange.update(account, { name: "Rolled back" }, @request)
        end
      end
    end
    assert_equal "Stable", account.reload.name

    with_audit_failure(:log_delete, error) do
      assert_no_difference([ "Account.count", "AuditLog.count" ]) do
        assert_raises(ActiveRecord::RecordInvalid) { AuditedChange.destroy(account, @request) }
      end
    end
    assert Account.exists?(account.id)
  end

  private

  def build_account(name: "Audited account")
    Account.new(
      name: name,
      account_type: :checking,
      current_balance: 100,
      balance_date: Date.current,
      warning_threshold: 0
    )
  end

  def create_account(**attributes)
    build_account(**attributes).tap(&:save!)
  end

  def with_audit_failure(method_name, replacement)
    singleton = class << AuditLog
      self
    end
    original = singleton.instance_method(method_name)
    singleton.define_method(method_name, replacement)
    yield
  ensure
    singleton.define_method(method_name, original)
  end
end
