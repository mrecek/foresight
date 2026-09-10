require "test_helper"

class SettingTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  def setup
    Setting.ensure_instance!.update_columns(
      default_view_months: 3,
      session_timeout_minutes: 30,
      auth_username: nil,
      auth_password_digest: nil
    )
  end

  # ============================================================================
  # Singleton Tests
  # ============================================================================

  test "instance returns the bootstrapped setting without writing" do
    writes = []
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      writes << payload[:sql] if payload[:sql].match?(/\A(?:INSERT|UPDATE|DELETE)/i)
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      setting = Setting.instance
      assert setting.persisted?
      assert_equal 3, setting.default_view_months
    end

    assert_empty writes
  end

  test "instance fails clearly when the boot invariant is missing" do
    Setting.delete_all

    assert_raises(ActiveRecord::RecordNotFound) { Setting.instance }
  ensure
    Setting.ensure_instance!
  end

  test "ensure_instance bootstraps an empty database" do
    Setting.delete_all

    setting = Setting.ensure_instance!
    assert_predicate setting, :persisted?
    assert_equal 3, setting.default_view_months
  end

  test "instance returns existing setting if present" do
    existing = update_setting!(
      default_view_months: 6,
      session_timeout_minutes: 60,
      auth_username: "testuser",
      auth_password: "password123"
    )

    setting = Setting.instance
    assert_equal existing.id, setting.id
  end

  # ============================================================================
  # Validation Tests - default_view_months
  # ============================================================================

  test "valid setting with default_view_months 1" do
    setting = Setting.new(default_view_months: 1)
    assert setting.valid?
  end

  test "valid setting with default_view_months 3" do
    setting = Setting.new(default_view_months: 3)
    assert setting.valid?
  end

  test "valid setting with default_view_months 6" do
    setting = Setting.new(default_view_months: 6)
    assert setting.valid?
  end

  test "default_view_months must be 1, 3, or 6" do
    setting = Setting.new(default_view_months: 12)
    assert_not setting.valid?
    assert_includes setting.errors[:default_view_months], "is not included in the list"
  end

  test "default_view_months cannot be nil" do
    setting = Setting.new(default_view_months: nil)
    assert_not setting.valid?
    assert_includes setting.errors[:default_view_months], "can't be blank"
  end

  # ============================================================================
  # Validation Tests - session_timeout_minutes (Issue 5)
  # ============================================================================

  test "session_timeout_minutes valid at minimum (1 minute)" do
    setting = Setting.new(
      default_view_months: 3,
      session_timeout_minutes: 1
    )
    assert setting.valid?
  end

  test "session_timeout_minutes valid at maximum (1440 minutes)" do
    setting = Setting.new(
      default_view_months: 3,
      session_timeout_minutes: 1440
    )
    assert setting.valid?
  end

  test "session_timeout_minutes valid at common value (30 minutes)" do
    setting = Setting.new(
      default_view_months: 3,
      session_timeout_minutes: 30
    )
    assert setting.valid?
  end

  test "CRITICAL: session_timeout_minutes cannot exceed 1440 (Issue 5)" do
    setting = Setting.new(
      default_view_months: 3,
      session_timeout_minutes: 1441
    )
    assert_not setting.valid?
    assert_includes setting.errors[:session_timeout_minutes],
                    "must be between 1 and 1440 minutes (24 hours)"
  end

  test "CRITICAL: session_timeout_minutes cannot be unreasonably large (Issue 5)" do
    setting = Setting.new(
      default_view_months: 3,
      session_timeout_minutes: 999999
    )
    assert_not setting.valid?
    assert_includes setting.errors[:session_timeout_minutes],
                    "must be between 1 and 1440 minutes (24 hours)"
  end

  test "session_timeout_minutes cannot be zero" do
    setting = Setting.new(
      default_view_months: 3,
      session_timeout_minutes: 0
    )
    assert_not setting.valid?
    assert_includes setting.errors[:session_timeout_minutes],
                    "must be between 1 and 1440 minutes (24 hours)"
  end

  test "session_timeout_minutes cannot be negative" do
    setting = Setting.new(
      default_view_months: 3,
      session_timeout_minutes: -30
    )
    assert_not setting.valid?
    assert_includes setting.errors[:session_timeout_minutes],
                    "must be between 1 and 1440 minutes (24 hours)"
  end

  test "session_timeout_minutes must be integer" do
    setting = Setting.new(
      default_view_months: 3,
      session_timeout_minutes: 30.5
    )
    assert_not setting.valid?
    # Custom message overrides the default "must be an integer" message
    assert_includes setting.errors[:session_timeout_minutes], "must be between 1 and 1440 minutes (24 hours)"
  end

  test "session_timeout_minutes cannot be nil" do
    setting = Setting.new(
      default_view_months: 3,
      session_timeout_minutes: nil
    )
    assert_not setting.valid?
    assert_includes setting.errors[:session_timeout_minutes], "can't be blank"
  end

  # ============================================================================
  # Validation Tests - Authentication
  # ============================================================================

  test "auth_username required if auth_password_digest present" do
    setting = Setting.new(
      default_view_months: 3,
      session_timeout_minutes: 30,
      auth_password: "password123"
    )
    assert_not setting.valid?
    assert_includes setting.errors[:auth_username], "can't be blank"
  end

  test "auth_password minimum length 8 characters" do
    setting = Setting.new(
      default_view_months: 3,
      session_timeout_minutes: 30,
      auth_username: "testuser",
      auth_password: "1234567"  # Only 7 characters
    )
    assert_not setting.valid?
    assert_includes setting.errors[:auth_password], "is too short (minimum is 8 characters)"
  end

  test "auth_password accepts exactly 8 characters" do
    setting = Setting.new(
      default_view_months: 3,
      session_timeout_minutes: 30,
      auth_username: "testuser",
      auth_password: "12345678"
    )
    assert setting.valid?
  end

  test "auth_password accepts long passwords" do
    setting = Setting.new(
      default_view_months: 3,
      session_timeout_minutes: 30,
      auth_username: "testuser",
      auth_password: "a" * 100
    )
    assert setting.valid?
  end

  test "can create setting without auth credentials" do
    setting = Setting.new(
      default_view_months: 3,
      session_timeout_minutes: 30
    )
    assert setting.valid?
  end

  test "can create setting with auth credentials" do
    setting = Setting.new(
      default_view_months: 3,
      session_timeout_minutes: 30,
      auth_username: "testuser",
      auth_password: "password123"
    )
    assert setting.valid?
  end

  # ============================================================================
  # Method Tests - has_secure_password
  # ============================================================================

  test "has_secure_password stores hashed password" do
    setting = update_setting!(
      default_view_months: 3,
      session_timeout_minutes: 30,
      auth_username: "testuser",
      auth_password: "password123"
    )

    assert setting.auth_password_digest.present?
    assert_not_equal "password123", setting.auth_password_digest
    assert setting.authenticate_auth_password("password123")
  end

  test "has_secure_password rejects wrong password" do
    setting = update_setting!(
      default_view_months: 3,
      session_timeout_minutes: 30,
      auth_username: "testuser",
      auth_password: "password123"
    )

    assert_not setting.authenticate_auth_password("wrongpassword")
  end

  # ============================================================================
  # Method Tests - setup_complete?
  # ============================================================================

  test "setup_complete returns true when auth configured" do
    setting = update_setting!(
      default_view_months: 3,
      session_timeout_minutes: 30,
      auth_username: "testuser",
      auth_password: "password123"
    )

    assert setting.setup_complete?
  end

  test "setup_complete returns false when no auth_username" do
    setting = update_setting!(
      default_view_months: 3,
      session_timeout_minutes: 30
    )

    assert_not setting.setup_complete?
  end

  test "setup_complete returns false when no auth_password_digest" do
    setting = update_setting!(
      default_view_months: 3,
      session_timeout_minutes: 30,
      auth_username: "testuser"
    )

    assert_not setting.setup_complete?
  end

  # ============================================================================
  # Edge Cases
  # ============================================================================

  test "can update session_timeout_minutes on existing setting" do
    setting = update_setting!(
      default_view_months: 3,
      session_timeout_minutes: 30,
      auth_username: "testuser",
      auth_password: "password123"
    )

    setting.update!(session_timeout_minutes: 120)
    assert_equal 120, setting.session_timeout_minutes
  end

  test "cannot update session_timeout_minutes to invalid value" do
    setting = update_setting!(
      default_view_months: 3,
      session_timeout_minutes: 30,
      auth_username: "testuser",
      auth_password: "password123"
    )

    assert_not setting.update(session_timeout_minutes: 2000)
    assert_includes setting.errors[:session_timeout_minutes],
                    "must be between 1 and 1440 minutes (24 hours)"
  end

  test "can change password on existing setting" do
    setting = update_setting!(
      default_view_months: 3,
      session_timeout_minutes: 30,
      auth_username: "testuser",
      auth_password: "password123"
    )

    old_digest = setting.auth_password_digest
    setting.update!(auth_password: "newpassword123")

    assert_not_equal old_digest, setting.auth_password_digest
    assert setting.authenticate_auth_password("newpassword123")
    assert_not setting.authenticate_auth_password("password123")
  end

  test "database rejects a second settings row" do
    error = assert_raises(ActiveRecord::RecordNotUnique) do
      Setting.insert_all!([ {
        singleton_guard: Setting::SINGLETON_GUARD,
        default_view_months: 3,
        session_timeout_minutes: 30,
        created_at: Time.current,
        updated_at: Time.current
      } ])
    end

    assert_includes error.message, "settings.singleton_guard"
    assert_equal 1, Setting.count
  end

  test "database rejects an alternate singleton guard" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Setting.insert_all!([ {
        singleton_guard: 2,
        default_view_months: 3,
        session_timeout_minutes: 30,
        created_at: Time.current,
        updated_at: Time.current
      } ])
    end
  end

  test "concurrent bootstrap converges on one settings row" do
    Setting.delete_all
    ready = Queue.new
    start = Queue.new
    results = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          results << Setting.ensure_instance!.id
        rescue StandardError => error
          results << error
        end
      end
    end

    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:join)
    outcomes = 2.times.map { results.pop }

    assert outcomes.none?(Exception), outcomes.grep(Exception).map(&:full_message).join("\n")
    assert_equal 1, outcomes.uniq.size
    assert_equal 1, Setting.count
  ensure
    threads&.each(&:join)
    Setting.ensure_instance!
  end

  private

  def update_setting!(attributes)
    Setting.instance.tap { |setting| setting.update!(attributes) }
  end
end
