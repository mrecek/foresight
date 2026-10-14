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
    assert_includes result[:github_output], "status=current"
  end

  test "reports a newer patch without failing the scheduled check" do
    result = run_freshness([ "v3_4_10", "v3_4_11" ])

    assert result[:status].success?, result[:output]
    assert_includes result[:output], "Ruby 3.4.10 is stale"
    assert_includes result[:github_output], "latest=3.4.11"
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

  test "patch updater changes every Ruby source atomically" do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, ".ruby-version"), "3.4.10\n")
      File.write(File.join(directory, ".mise.toml"), "[tools]\nruby = \"3.4.10\"\n")
      File.write(File.join(directory, "Dockerfile"), fixture_dockerfile)
      command = [ ROOT.join("bin/update-ruby-patch").to_s, "--version", "3.4.11", "--digest", "sha256:#{'b' * 64}" ]
      output, status = Open3.capture2e(*command, chdir: directory)

      assert status.success?, output
      assert_equal "3.4.11\n", File.read(File.join(directory, ".ruby-version"))
      assert_includes File.read(File.join(directory, ".mise.toml")), 'ruby = "3.4.11"'
      assert_equal fixture_dockerfile.sub(/ruby:3\.4\.10-slim-trixie@sha256:[0-9a-f]{64}/, "ruby:3.4.11-slim-trixie@sha256:#{'b' * 64}"),
        File.read(File.join(directory, "Dockerfile"))
    end
  end

  test "patch updater refuses a minor upgrade" do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, ".ruby-version"), "3.4.10\n")
      File.write(File.join(directory, ".mise.toml"), "[tools]\nruby = \"3.4.10\"\n")
      File.write(File.join(directory, "Dockerfile"), fixture_dockerfile)
      command = [ ROOT.join("bin/update-ruby-patch").to_s, "--version", "3.5.0", "--digest", "sha256:#{'b' * 64}" ]
      output, status = Open3.capture2e(*command, chdir: directory)

      assert_not status.success?
      assert_includes output, "Only Ruby patch updates are automated"
      assert_equal "3.4.10\n", File.read(File.join(directory, ".ruby-version"))
      assert_includes File.read(File.join(directory, ".mise.toml")), 'ruby = "3.4.10"'
    end
  end

  test "patch updater validates every source before writing any file" do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, ".ruby-version"), "3.4.10\n")
      File.write(File.join(directory, ".mise.toml"), "[tools]\nruby = \"3.4.9\"\n")
      File.write(File.join(directory, "Dockerfile"), fixture_dockerfile)
      output, status = Open3.capture2e(ROOT.join("bin/update-ruby-patch").to_s,
        "--version", "3.4.11", "--digest", "sha256:#{'b' * 64}", chdir: directory)

      assert_not status.success?
      assert_includes output, ".mise.toml Ruby declaration was not found"
      assert_equal "3.4.10\n", File.read(File.join(directory, ".ruby-version"))
      assert_equal fixture_dockerfile, File.read(File.join(directory, "Dockerfile"))
    end
  end

  test "patch updater supports renamed Docker stages without changing their consumers" do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, ".ruby-version"), "3.4.10\n")
      File.write(File.join(directory, ".mise.toml"), "[tools]\nruby = \"3.4.10\"\n")
      dockerfile = fixture_dockerfile.gsub("os-packages", "refreshed-runtime")
      File.write(File.join(directory, "Dockerfile"), dockerfile)
      output, status = Open3.capture2e(ROOT.join("bin/update-ruby-patch").to_s,
        "--version", "3.4.11", "--digest", "sha256:#{'b' * 64}", chdir: directory)

      assert status.success?, output
      assert_includes File.read(File.join(directory, "Dockerfile")), "AS refreshed-runtime"
      assert_includes File.read(File.join(directory, "Dockerfile")), "FROM refreshed-runtime AS runtime"
    end
  end

  private

  def fixture_dockerfile
    ROOT.join("Dockerfile").read.sub(/ruby:\d+\.\d+\.\d+-slim-trixie@sha256:[0-9a-f]{64}/,
      "ruby:3.4.10-slim-trixie@sha256:#{'a' * 64}")
  end

  def run_freshness(tags)
    Dir.mktmpdir do |directory|
      refs = File.join(directory, "refs.json")
      github_output = File.join(directory, "output")
      File.write(File.join(directory, ".ruby-version"), "3.4.10\n")
      File.write(refs, JSON.generate(tags.map { |tag| { "ref" => "refs/tags/#{tag}" } }))
      output, status = Open3.capture2e(
        ROOT.join("bin/check-ruby-freshness").to_s,
        "--refs", refs,
        "--github-output", github_output,
        chdir: directory
      )
      return { output: output, status: status, github_output: File.read(github_output) }
    end
  end
end
