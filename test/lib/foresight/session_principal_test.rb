# frozen_string_literal: true

require "test_helper"

class Foresight::SessionPrincipalTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  SessionPrincipal = Foresight::Authentication::SessionPrincipal

  test "password principal round trips through the bounded session payload" do
    now = Time.zone.parse("2026-09-10 12:00:00")
    principal = SessionPrincipal.build(authentication_method: "password", subject: "owner", now: now)
    restored = SessionPrincipal.from_session(principal.to_session)

    assert_equal "password", restored.authentication_method
    assert_equal "owner", restored.subject
    assert_nil restored.issuer
    assert_equal now, restored.authenticated_at
    assert_equal now, restored.last_seen_at
    assert_equal %w[authenticated_at last_seen_at method subject version], principal.to_session.keys.sort
  end

  test "OIDC principal requires and preserves the issuer subject pair" do
    principal = SessionPrincipal.build(
      authentication_method: "oidc",
      issuer: "https://identity.example.com",
      subject: "opaque-subject"
    )

    assert_equal "https://identity.example.com", principal.issuer
    assert_equal "opaque-subject", principal.subject
    assert_raises(ArgumentError) do
      SessionPrincipal.build(authentication_method: "oidc", subject: "opaque-subject")
    end
  end

  test "malformed session payloads fail closed" do
    assert_nil SessionPrincipal.from_session(nil)
    assert_nil SessionPrincipal.from_session("authenticated")
    assert_nil SessionPrincipal.from_session("version" => 99, "method" => "password")
    assert_nil SessionPrincipal.from_session(
      "version" => 1,
      "method" => "unknown",
      "subject" => "owner",
      "authenticated_at" => Time.current.to_i,
      "last_seen_at" => Time.current.to_i
    )
  end

  test "idle and absolute lifetimes expire independently" do
    now = Time.zone.parse("2026-09-10 12:00:00")
    principal = SessionPrincipal.build(authentication_method: "password", subject: "owner", now: now)

    refute principal.expired?(idle_timeout_minutes: 30, absolute_timeout_minutes: 120, now: now + 29.minutes)
    assert principal.expired?(idle_timeout_minutes: 30, absolute_timeout_minutes: 120, now: now + 31.minutes)

    touched = principal.touch(now: now + 100.minutes)
    refute touched.expired?(idle_timeout_minutes: 30, absolute_timeout_minutes: 120, now: now + 119.minutes)
    assert touched.expired?(idle_timeout_minutes: 30, absolute_timeout_minutes: 120, now: now + 121.minutes)
  end
end
