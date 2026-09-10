require "test_helper"
require "json"
require "open3"
require "tmpdir"

class RubyFreshnessTest < ActiveSupport::TestCase
  ROOT = Rails.root

  test "reports the configured patch as current" do
    result = run_freshness([ "v3_4_9", "v3_4_10", "v3_4_10_preview1" ])

    assert result[:status].success?, result[:output]
    assert_includes result[:output], "Ruby 3.4.10 is current"
    assert_includes File.read(result[:github_output]), "status=current"
  end

  test "reports a newer patch without failing the scheduled check" do
    result = run_freshness([ "v3_4_10", "v3_4_11" ])

    assert result[:status].success?, result[:output]
    assert_includes result[:output], "Ruby 3.4.10 is stale"
    assert_includes File.read(result[:github_output]), "latest=3.4.11"
  end

  test "fails closed when upstream data cannot be understood" do
    Dir.mktmpdir do |directory|
      refs = File.join(directory, "refs.json")
      File.write(refs, "not-json")
      output, status = Open3.capture2e(ROOT.join("bin/check-ruby-freshness").to_s, "--refs", refs, chdir: ROOT)

      assert_not status.success?
      assert_includes output, "Ruby upstream returned invalid JSON"
    end
  end

  test "patch updater changes both sources atomically" do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, ".ruby-version"), "3.4.10\n")
      File.write(File.join(directory, "Dockerfile"), "FROM docker.io/library/ruby:3.4.10-slim@sha256:#{'a' * 64} AS base\n")
      command = [ ROOT.join("bin/update-ruby-patch").to_s, "--version", "3.4.11", "--digest", "sha256:#{'b' * 64}" ]
      output, status = Open3.capture2e(*command, chdir: directory)

      assert status.success?, output
      assert_equal "3.4.11\n", File.read(File.join(directory, ".ruby-version"))
      assert_includes File.read(File.join(directory, "Dockerfile")), "ruby:3.4.11-slim@sha256:#{'b' * 64}"
    end
  end

  test "patch updater refuses a minor upgrade" do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, ".ruby-version"), "3.4.10\n")
      File.write(File.join(directory, "Dockerfile"), "FROM docker.io/library/ruby:3.4.10-slim@sha256:#{'a' * 64} AS base\n")
      command = [ ROOT.join("bin/update-ruby-patch").to_s, "--version", "3.5.0", "--digest", "sha256:#{'b' * 64}" ]
      output, status = Open3.capture2e(*command, chdir: directory)

      assert_not status.success?
      assert_includes output, "Only Ruby patch updates are automated"
      assert_equal "3.4.10\n", File.read(File.join(directory, ".ruby-version"))
    end
  end

  private

  def run_freshness(tags)
    directory = Dir.mktmpdir
    refs = File.join(directory, "refs.json")
    github_output = File.join(directory, "output")
    File.write(refs, JSON.generate(tags.map { |tag| { "ref" => "refs/tags/#{tag}" } }))
    output, status = Open3.capture2e(
      ROOT.join("bin/check-ruby-freshness").to_s,
      "--refs", refs,
      "--github-output", github_output,
      chdir: ROOT
    )
    { output: output, status: status, github_output: github_output }
  end
end
