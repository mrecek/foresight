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
    assert_equal [ { "dependency-type" => "all", "update-types" => %w[version-update:semver-patch version-update:semver-minor] } ], bundler.fetch("allow")
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
    ruby_ignore = docker.fetch("ignore").find { |entry| entry.fetch("dependency-name") == "library/ruby" }
    assert_equal %w[version-update:semver-minor version-update:semver-major],
      ruby_ignore.fetch("update-types")
  end

  test "Ruby base patch updates use the same required-check gate" do
    assert_equal "true", eligibility_for("docker", "version-update:semver-patch", "library/ruby").fetch("eligible")
    %w[version-update:semver-minor version-update:semver-major].each do |update_type|
      assert_equal "false", eligibility_for("docker", update_type, "library/ruby").fetch("eligible")
    end
    assert_equal "false", eligibility_for("docker", "version-update:semver-patch", "other/image").fetch("eligible")
    assert_equal "false", eligibility_for("docker", "", "library/ruby").fetch("eligible")
    assert_equal "false", eligibility_for("docker", "version-update:semver-patch", "library/ruby, other/image").fetch("eligible")
  end

  test "CI derives its runtime from the container declaration" do
    action = YAML.safe_load_file(Rails.root.join(".github/actions/setup-runtime/action.yml"))
    steps = action.fetch("runs").fetch("steps")
    assert_includes steps.first.fetch("run"), "bin/ruby-version"
    assert_equal "${{ steps.runtime.outputs.version }}", steps.last.fetch("with").fetch("ruby-version")
    assert_not Rails.root.join(".github/workflows/ruby-freshness.yml").exist?
  end

  test "every accepted main revision enters the same release lane" do
    workflow = YAML.safe_load_file(Rails.root.join(".github/workflows/docker.yml"))
    triggers = workflow.fetch("on", workflow[true])
    assert_equal [ "main" ], triggers.fetch("push").fetch("branches")
    assert_not triggers.fetch("push").key?("paths-ignore")
    assert_not triggers.fetch("push").key?("paths")
  end

  test "Docker base is pinned by version and multi-architecture digest" do
    dockerfile = Rails.root.join("Dockerfile").read

    assert_match %r{^FROM docker\.io/library/ruby:#{Regexp.escape(Open3.capture2(Rails.root.join("bin/ruby-version").to_s).first.strip)}-slim-trixie@sha256:[0-9a-f]{64} AS os-packages$}, dockerfile
    refute_includes dockerfile, "OS_PATCH_EPOCH"
    assert_includes dockerfile, "FROM os-packages AS build"
    assert_includes dockerfile, "FROM os-packages AS runtime"
    assert_includes dockerfile, "apt-get upgrade --with-new-pkgs -y"
    refute_match(/apt-get install[^\n]+(?:curl|sqlite3)/, dockerfile)
    assert_includes dockerfile, 'CMD ["bin/container-healthcheck"]'
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

  def eligibility_for(ecosystem, update_type, dependency_names = "")
    Tempfile.create("dependabot-output") do |output|
      stdout, stderr, status = Open3.capture3(
        { "GITHUB_OUTPUT" => output.path },
        "bash", ELIGIBILITY_SCRIPT.to_s, ecosystem, update_type, dependency_names
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
