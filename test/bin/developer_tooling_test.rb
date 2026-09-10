# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "open3"
require "tempfile"
require "tmpdir"

class DeveloperToolingTest < ActiveSupport::TestCase
  ROOT = Rails.root

  test "mise stays a thin wrapper around canonical repository commands" do
    config = ROOT.join(".mise.toml").read

    assert_includes config, %(ruby = "#{ROOT.join(".ruby-version").read.strip}")
    assert_includes config, 'run = "bin/setup --skip-server"'
    assert_includes config, 'run = "bin/dev"'
    assert_includes config, 'run = "bin/test"'
    assert_includes config, 'run = "bin/validate"'
    refute_includes ROOT.join("mise.lock").read, "windows"
  end

  test "commit message hook accepts conventional subjects" do
    result = run_commit_hook("fix(auth): reject an expired session\n")

    assert result[:status].success?, result[:output]
  end

  test "commit message hook rejects an unstructured subject" do
    result = run_commit_hook("updated some things\n")

    assert_not result[:status].success?
    assert_includes result[:output], "Expected Conventional Commits"
  end

  test "hook installer configures a checkout idempotently" do
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p(File.join(directory, "bin"))
      FileUtils.cp(ROOT.join("bin/install-hooks"), File.join(directory, "bin/install-hooks"))
      system("git", "init", "--quiet", directory, exception: true)

      2.times do
        output, status = Open3.capture2e(File.join(directory, "bin/install-hooks"), chdir: directory)
        assert status.success?, output
      end

      hooks_path, status = Open3.capture2e("git", "config", "--local", "--get", "core.hooksPath", chdir: directory)
      assert status.success?, hooks_path
      assert_equal ".githooks", hooks_path.strip
    end
  end

  private

  def run_commit_hook(message)
    Tempfile.create("commit-message") do |file|
      file.write(message)
      file.flush
      output, status = Open3.capture2e(ROOT.join(".githooks/commit-msg").to_s, file.path)
      return { output: output, status: status }
    end
  end
end
