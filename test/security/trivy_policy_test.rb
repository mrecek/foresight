# frozen_string_literal: true

require "test_helper"
require "json"
require "open3"
require "tempfile"

class TrivyPolicyTest < ActiveSupport::TestCase
  POLICY = Rails.root.join("bin/check-trivy-report")

  test "passes a clean report" do
    stdout, _stderr, status = run_policy([])

    assert status.success?
    assert_includes stdout, "policy passed"
  end

  test "reports but does not block an unfixed critical finding" do
    stdout, _stderr, status = run_policy([ vulnerability(severity: "CRITICAL", fixed_version: "") ])

    assert status.success?
    assert_includes stdout, "policy passed"
  end

  test "fails actionably for fixable high and critical findings" do
    findings = [
      vulnerability(id: "CVE-HIGH", severity: "HIGH", fixed_version: "1.2.4"),
      vulnerability(id: "CVE-CRITICAL", severity: "CRITICAL", fixed_version: "2.0.0")
    ]
    stdout, _stderr, status = run_policy(findings)

    refute status.success?
    assert_includes stdout, "2 fixable HIGH/CRITICAL"
    assert_includes stdout, "CVE-HIGH: demo 1.2.3 -> 1.2.4"
    assert_includes stdout, "CVE-CRITICAL: demo 1.2.3 -> 2.0.0"
  end

  test "medium findings do not block even when fixable" do
    _stdout, _stderr, status = run_policy([ vulnerability(severity: "MEDIUM", fixed_version: "1.2.4") ])

    assert status.success?
  end

  test "a stale bundled default gem is covered only by an active secure lockfile pin" do
    stdout, _stderr, status = run_policy([
      vulnerability(
        id: "CVE-2026-80212",
        package: "resolv",
        installed_version: "0.7.1",
        severity: "HIGH",
        fixed_version: "0.7.2"
      )
    ])

    assert status.success?
    assert_includes stdout, "covered by verified lockfile pins: resolv"
  end

  test "an active pinned gem finding still blocks" do
    _stdout, _stderr, status = run_policy([
      vulnerability(
        package: "resolv",
        installed_version: "0.7.2",
        severity: "HIGH",
        fixed_version: "0.7.3"
      )
    ])

    refute status.success?
  end

  private

  def run_policy(vulnerabilities)
    Tempfile.create([ "trivy", ".json" ]) do |report|
      report.write(JSON.generate("Results" => [ { "Vulnerabilities" => vulnerabilities } ]))
      report.flush

      return Open3.capture3(RbConfig.ruby, POLICY.to_s, report.path)
    end
  end

  def vulnerability(
    id: "CVE-DEMO",
    package: "demo",
    installed_version: "1.2.3",
    severity:,
    fixed_version:
  )
    {
      "VulnerabilityID" => id,
      "PkgName" => package,
      "InstalledVersion" => installed_version,
      "FixedVersion" => fixed_version,
      "Severity" => severity
    }
  end
end
