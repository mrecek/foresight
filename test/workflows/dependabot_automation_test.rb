# frozen_string_literal: true

require "test_helper"
require "open3"
require "tempfile"
require "yaml"

class DependabotAutomationTest < ActiveSupport::TestCase
  ELIGIBILITY_SCRIPT = Rails.root.join(".github/scripts/dependabot-auto-merge-eligibility")

  test "only Bundler patch and minor updates are eligible" do
    assert_equal "true", eligibility_for("bundler", "version-update:semver-patch").fetch("eligible")
    assert_equal "true", eligibility_for("bundler", "version-update:semver-minor").fetch("eligible")
    assert_equal "false", eligibility_for("bundler", "version-update:semver-major").fetch("eligible")
  end

  test "other ecosystems remain ineligible regardless of update size" do
    %w[github-actions docker].each do |ecosystem|
      result = eligibility_for(ecosystem, "version-update:semver-patch")

      assert_equal "false", result.fetch("eligible")
      assert_includes result.fetch("reason"), "manual review"
    end
  end

  test "Dependabot groups Bundler version and security updates separately" do
    bundler = dependabot_updates.fetch("bundler")
    groups = bundler.fetch("groups")

    assert_equal "version-updates", groups.fetch("minor-and-patch-gems").fetch("applies-to")
    assert_equal %w[minor patch], groups.fetch("minor-and-patch-gems").fetch("update-types")
    assert_equal "security-updates", groups.fetch("security-gems").fetch("applies-to")
    assert_equal [ "*" ], groups.fetch("security-gems").fetch("patterns")
  end

  test "Actions stay monthly and Docker monitoring is configured" do
    actions = dependabot_updates.fetch("github-actions")
    docker = dependabot_updates.fetch("docker")

    assert_equal "monthly", actions.dig("schedule", "interval")
    assert actions.fetch("groups").key?("actions")
    assert_equal "weekly", docker.dig("schedule", "interval")
    ruby_ignore = docker.fetch("ignore").find { |entry| entry.fetch("dependency-name") == "ruby" }
    assert_equal %w[version-update:semver-patch version-update:semver-minor version-update:semver-major],
      ruby_ignore.fetch("update-types")
  end

  test "Ruby patch automation validates candidates and avoids duplicate pull requests" do
    workflow = Rails.root.join(".github/workflows/ruby-freshness.yml").read

    assert_includes workflow, "schedule:"
    assert_includes workflow, "bin/check-ruby-freshness"
    assert_includes workflow, "gh pr list --state all"
    assert_includes workflow, "bin/validate --ci"
    assert_includes workflow, "gh pr create"
  end

  test "Docker base is pinned by version and multi-architecture digest" do
    dockerfile = Rails.root.join("Dockerfile").read

    assert_match %r{^FROM docker\.io/library/ruby:3\.4\.10-slim@sha256:[0-9a-f]{64} AS base$}, dockerfile
  end

  test "automation does not depend on an automerge label" do
    dependabot = Rails.root.join(".github/dependabot.yml").read
    workflow = Rails.root.join(".github/workflows/auto-merge-dependabot.yml").read

    refute_includes dependabot, "automerge"
    refute_includes workflow, "labels.*.name"
    assert_includes workflow, "pull_request.user.login == 'dependabot[bot]'"
    assert_includes workflow, "package-ecosystem"
    assert_includes workflow, "Report auto-merge decision"
  end

  private

  def eligibility_for(ecosystem, update_type)
    Tempfile.create("dependabot-output") do |output|
      stdout, stderr, status = Open3.capture3(
        { "GITHUB_OUTPUT" => output.path },
        "bash", ELIGIBILITY_SCRIPT.to_s, ecosystem, update_type
      )
      assert status.success?, [ stdout, stderr ].join("\n")

      return output.tap(&:rewind).each_line(chomp: true).to_h { |line| line.split("=", 2) }
    end
  end

  def dependabot_updates
    @dependabot_updates ||= YAML.safe_load_file(Rails.root.join(".github/dependabot.yml"))
      .fetch("updates")
      .index_by { |update| update.fetch("package-ecosystem") }
  end
end
