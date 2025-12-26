require "test_helper"

class SettingTest < ActiveSupport::TestCase
  def setup
    # Clear any existing settings
    Setting.destroy_all
  end

  # ============================================================================
  # Singleton Tests
  # ============================================================================

  test "instance returns first setting or creates one" do
    setting = Setting.instance
    assert setting.persisted?
    assert_equal 3, setting.default_view_months
  end

  test "instance returns existing setting if present" do
    existing = Setting.create!(
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
    setting = Setting.create!(
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
    setting = Setting.create!(
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
    setting = Setting.create!(
      default_view_months: 3,
      session_timeout_minutes: 30,
      auth_username: "testuser",
      auth_password: "password123"
    )

    assert setting.setup_complete?
  end

  test "setup_complete returns false when no auth_username" do
    setting = Setting.create!(
      default_view_months: 3,
      session_timeout_minutes: 30
    )

    assert_not setting.setup_complete?
  end

  test "setup_complete returns false when no auth_password_digest" do
    setting = Setting.create!(
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
    setting = Setting.create!(
      default_view_months: 3,
      session_timeout_minutes: 30,
      auth_username: "testuser",
      auth_password: "password123"
    )

    setting.update!(session_timeout_minutes: 120)
    assert_equal 120, setting.session_timeout_minutes
  end

  test "cannot update session_timeout_minutes to invalid value" do
    setting = Setting.create!(
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
    setting = Setting.create!(
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
end
