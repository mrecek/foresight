# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class OsPackageFreshnessTest < ActiveSupport::TestCase
  ROOT = Rails.root

  test "reports current and stale released package states" do
    current = check_updates("")
    stale = check_updates("Inst gzip [1.13-1] (1.13-1+deb13u1 Debian:13 [amd64])\n")

    assert current[:status].success?, current[:output]
    assert_includes current[:output], "OS packages are current"
    assert_includes File.read(current[:github_output]), "status=current"

    assert stale[:status].success?, stale[:output]
    assert_includes stale[:output], "gzip: 1.13-1 -> 1.13-1+deb13u1"
    assert_includes File.read(stale[:github_output]), "status=stale"
    assert_includes File.read(stale[:github_output]), "packages=gzip"
  end

  test "fails closed when the image cannot be inspected" do
    result = check_updates("", exit_code: 1)

    refute result[:status].success?
    assert_includes result[:output], "Could not inspect OS packages"
  end

  test "patch epoch updater moves forward exactly once" do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "Dockerfile"), "ARG OS_PATCH_EPOCH=2026-09-13T00:00:00Z\n")

      output, status = Open3.capture2e(
        ROOT.join("bin/update-os-patch-epoch").to_s, "--time", "2026-09-13T14:15:00Z", chdir: directory
      )

      assert status.success?, output
      assert_equal "ARG OS_PATCH_EPOCH=2026-09-13T14:15:00Z\n", File.read(File.join(directory, "Dockerfile"))
    end
  end

  test "patch epoch updater rejects an invalid or non-forward date" do
    [ "2026-09-13T00:00:00Z", "September 14" ].each do |requested|
      Dir.mktmpdir do |directory|
        File.write(File.join(directory, "Dockerfile"), "ARG OS_PATCH_EPOCH=2026-09-13T00:00:00Z\n")
        _output, status = Open3.capture2e(
          ROOT.join("bin/update-os-patch-epoch").to_s, "--time", requested, chdir: directory
        )

        refute status.success?
        assert_equal "ARG OS_PATCH_EPOCH=2026-09-13T00:00:00Z\n", File.read(File.join(directory, "Dockerfile"))
      end
    end
  end

  private

  def check_updates(output, exit_code: 0)
    directory = Dir.mktmpdir
    executable = File.join(directory, "docker")
    github_output = File.join(directory, "github-output")
    File.write(executable, <<~SH)
      #!/usr/bin/env bash
      printf '%s' "$FAKE_APT_OUTPUT"
      exit "$FAKE_EXIT_CODE"
    SH
    FileUtils.chmod(0o755, executable)

    combined, status = Open3.capture2e(
      {
        "PATH" => "#{directory}:#{ENV.fetch('PATH')}",
        "FAKE_APT_OUTPUT" => output,
        "FAKE_EXIT_CODE" => exit_code.to_s
      },
      ROOT.join("bin/check-os-updates").to_s,
      "--github-output", github_output,
      "ghcr.io/example/foresight:sha-demo"
    )
    { output: combined, status: status, github_output: github_output }
  end
end
