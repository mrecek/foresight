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
    assert_includes stdout, "Non-blocking unfixed HIGH/CRITICAL findings (1): CVE-DEMO"
  end

  test "fails actionably for fixable high and critical findings" do
    findings = [
      vulnerability(id: "CVE-HIGH", severity: "HIGH", fixed_version: "1.2.4"),
      vulnerability(id: "CVE-CRITICAL", severity: "CRITICAL", fixed_version: "2.0.0")
    ]
    stdout, _stderr, status = run_policy(findings)

    refute status.success?
    assert_includes stdout, "2 fixable HIGH/CRITICAL"
    assert_includes stdout, "across 1 package"
    assert_includes stdout, "demo 1.2.3 -> 1.2.4, 2.0.0: 2 finding"
    assert_includes stdout, "CVE-CRITICAL, CVE-HIGH"
  end

  test "medium findings do not block even when fixable" do
    _stdout, _stderr, status = run_policy([ vulnerability(severity: "MEDIUM", fixed_version: "1.2.4") ])

    assert status.success?
  end

  test "the exact inactive default gem advisory requires safe image runtime evidence" do
    stdout, _stderr, status = run_policy([ resolv_finding ], evidence: image_evidence)

    assert status.success?
    assert_includes stdout, "covered by verified image runtime versions: resolv"
  end

  test "the lockfile cannot exempt a finding without image evidence" do
    _stdout, _stderr, status = run_policy([ resolv_finding ])

    refute status.success?
  end

  test "an unsafe or malformed active gem version blocks" do
    [ "0.7.1", "invalid" ].each do |version|
      evidence = image_evidence
      evidence.fetch("gems").fetch("resolv")["version"] = version
      _stdout, _stderr, status = run_policy([ resolv_finding ], evidence: evidence)
      refute status.success?
    end
  end

  test "future advisories and changed fixed versions fail closed" do
    [ { "VulnerabilityID" => "CVE-FUTURE" }, { "FixedVersion" => ">= 0.7.3" } ].each do |change|
      _stdout, _stderr, status = run_policy([ resolv_finding.merge(change) ], evidence: image_evidence)
      refute status.success?
    end
  end

  test "active copies and ambiguous package paths cannot be exempted" do
    [ "usr/local/bundle/gems/resolv-0.7.1/resolv.gemspec", "", "elsewhere/resolv-0.7.1.gemspec" ].each do |path|
      _stdout, _stderr, status = run_policy([ resolv_finding.merge("PkgPath" => path) ], evidence: image_evidence)
      refute status.success?
    end
    _stdout, _stderr, status = run_policy([ resolv_finding ], evidence: image_evidence, result_type: "gobinary")
    refute status.success?
  end

  test "a claimed safe gem must actually be the loaded Ruby source" do
    evidence = image_evidence
    evidence.fetch("gems").fetch("resolv")["loaded_path"] = "/usr/local/lib/ruby/3.4.0/resolv.rb"
    _stdout, _stderr, status = run_policy([ resolv_finding ], evidence: evidence)

    refute status.success?
  end

  test "evidence for a different image or platform is rejected" do
    [ { "image" => "different" }, { "platform" => "linux/arm64" } ].each do |change|
      _stdout, stderr, status = run_policy([ resolv_finding ], evidence: image_evidence.merge(change))
      refute status.success?
      assert_includes stderr, "does not match"
    end
  end

  test "malformed or unrecognized reports fail closed" do
    [ {}, { "SchemaVersion" => 3, "Results" => [] }, { "SchemaVersion" => 2, "Results" => "bad" },
      { "SchemaVersion" => 2, "Results" => [ { "Target" => "Ruby", "Vulnerabilities" => [ {} ] } ] } ].each do |document|
      _stdout, stderr, status = run_policy([], document: document)
      refute status.success?
      assert_includes stderr, "Invalid Trivy report"
    end
  end

  private

  IMAGE = "ghcr.io/mrecek/foresight@sha256:#{'a' * 64}"

  def image_evidence
    {
      "image" => IMAGE, "platform" => "linux/amd64",
      "gems" => { "resolv" => {
        "version" => "0.7.2", "gem_path" => "/usr/local/bundle/gems/resolv-0.7.2",
        "loaded_path" => "/usr/local/bundle/gems/resolv-0.7.2/lib/resolv.rb"
      } }
    }
  end

  def resolv_finding
    vulnerability(id: "CVE-2026-80212", package: "resolv", installed_version: "0.7.1",
      severity: "HIGH", fixed_version: "~> 0.3.2, >= 0.7.2").merge(
        "PkgPath" => "usr/local/lib/ruby/gems/3.4.0/specifications/default/resolv-0.7.1.gemspec")
  end

  def run_policy(vulnerabilities, evidence: nil, result_type: "gemspec", document: nil)
    Tempfile.create([ "trivy", ".json" ]) do |report|
      report.write(JSON.generate(document || {
        "SchemaVersion" => 2, "ArtifactName" => IMAGE,
        "Metadata" => { "ImageConfig" => { "architecture" => "amd64" } },
        "Results" => [ { "Target" => "Ruby", "Class" => "lang-pkgs", "Type" => result_type,
                         "Vulnerabilities" => vulnerabilities } ]
      }))
      report.flush
      Tempfile.create([ "image-gems", ".json" ]) do |versions|
        versions.write(JSON.generate(evidence))
        versions.flush
        args = [ RbConfig.ruby, POLICY.to_s, report.path ]
        args << versions.path if evidence
        return Open3.capture3(*args)
      end
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
