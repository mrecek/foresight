# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require "yaml"

class ContainerRefreshTest < ActiveSupport::TestCase
  ROOT = Rails.root
  DIGEST = "sha256:#{'a' * 64}"

  setup do
    @directory = Dir.mktmpdir
    @bin = File.join(@directory, "bin")
    FileUtils.mkdir_p(@bin)
    write_fake_docker
  end

  teardown { FileUtils.remove_entry(@directory) }

  test "digest resolution validates structured output and retries transient failures" do
    output, status = run_script("resolve-image-digest", "example.test/app:latest", env: { "FAKE_INSPECT_FAILURES" => "2" })

    assert status.success?, output
    assert_equal DIGEST, output.strip
  end

  test "digest resolution accepts an explicitly missing tag but rejects malformed output" do
    output, status = run_script("resolve-image-digest", "example.test/app:missing", "--allow-missing")
    assert status.success?, output
    assert_empty output

    output, status = run_script("resolve-image-digest", "example.test/app:invalid")
    refute status.success?
    assert_includes output, "Invalid digest"
  end

  test "candidate metadata requires both provenance and SBOM" do
    reference = "example.test/app@#{DIGEST}"
    output, status = run_script("check-container-metadata", reference)
    assert status.success?, output

    output, status = run_script("check-container-metadata", reference, env: { "FAKE_SBOM" => "missing" })
    refute status.success?
    assert_includes output, "has no SBOM metadata"
  end

  test "promotion requires the dependency audit and both native verification jobs" do
    config = workflow_config("docker")
    jobs = config.fetch("jobs")
    build = jobs.fetch("build")
    verify = jobs.fetch("verify")
    promote = jobs.fetch("promote")

    assert_equal "foresight-container-production", config.dig("concurrency", "group")
    assert_equal "build", verify.fetch("needs")
    assert_equal %w[build verify], promote.fetch("needs")
    assert_nil promote["if"], "Promotion must require successful build and every verifier"
    assert_equal false, verify.dig("strategy", "fail-fast")
    assert_native_matrix(verify)
    assert_equal "${{ needs.build.outputs.digest }}", verify.dig("env", "DIGEST")

    {
      build => [ "Verify candidate platforms", "Verify candidate provenance and SBOM", "Audit locked Ruby dependencies" ],
      verify => [ "Verify candidate OS refresh", "Smoke test exact candidate on its native architecture", "Scan native candidate with Trivy", "Verify candidate runtime and vulnerability policy" ],
      promote => [ "Generate provenance attestation", "Promote verified candidate" ]
    }.each do |job, names|
      names.each do |name|
        step = job.fetch("steps").find { |entry| entry["name"] == name }
        assert step, "Missing release gate: #{name}"
        assert_nil step["if"], "Release gate must be unconditional: #{name}"
        refute step["continue-on-error"], "Release failure must block promotion: #{name}"
      end
    end
    refute verify.fetch("steps").any? { |step| step.fetch("uses", "").include?("setup-qemu") }
    promotion = promote.fetch("steps").find { |step| step["name"] == "Promote verified candidate" }
    assert_includes promotion.fetch("run"), "${{ needs.build.outputs.digest }}"
  end

  test "weekly refresh runs independently of automated merge events" do
    release = ROOT.join(".github/workflows/docker.yml").read
    config = workflow_config("docker")
    triggers = config.fetch("on", config[true])

    assert_equal [ { "cron" => "37 17 * * 3" } ], triggers.fetch("schedule")
    assert triggers.key?("workflow_dispatch")
    assert_includes release, "no-cache-filters: os-packages,runtime"
    assert_includes release, "scheduled-refresh"
    refute_includes release, "bin/validate --ci"
  end

  test "registry scans select each native platform independently of local Docker images" do
    verify = workflow_config("docker").fetch("jobs").fetch("verify")
    assert_native_matrix(verify)
    scan = verify.fetch("steps").find { |step| step.fetch("uses", "").start_with?("aquasecurity/trivy-action@") }
    assert_equal "remote", scan.fetch("env").fetch("TRIVY_IMAGE_SRC")
    assert_equal "${{ matrix.platform }}", scan.fetch("env").fetch("TRIVY_PLATFORM")
  end

  private

  def workflow_config(name)
    YAML.safe_load_file(ROOT.join(".github/workflows/#{name}.yml"), aliases: true)
  end

  def assert_native_matrix(job)
    assert_equal [
      { "runner" => "ubuntu-24.04", "platform" => "linux/amd64", "arch" => "amd64" },
      { "runner" => "ubuntu-24.04-arm", "platform" => "linux/arm64", "arch" => "arm64" }
    ], job.dig("strategy", "matrix", "include")
    assert_equal "${{ matrix.runner }}", job.fetch("runs-on")
  end

  def run_script(name, *arguments, env: {})
    Open3.capture2e(
      {
        "PATH" => "#{@bin}:#{ENV.fetch('PATH')}",
        "REGISTRY_RETRY_ATTEMPTS" => "3",
        "REGISTRY_RETRY_DELAY" => "0",
        "FAKE_DIGEST" => DIGEST,
        "FAKE_INSPECT_FAILURES" => "0",
        "FAKE_SBOM" => "present",
        "FAKE_STATE" => @directory
      }.merge(env),
      ROOT.join("bin", name).to_s, *arguments,
      chdir: ROOT
    )
  end

  def write_fake_docker
    File.write(File.join(@bin, "docker"), <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      if [[ "$1 $2 $3" == "buildx imagetools inspect" ]]; then
        reference="$4"
        if [[ "${6:-}" == *".Provenance"* ]]; then
          printf '{"builder":"buildkit"}\n'
          exit 0
        elif [[ "${6:-}" == *".SBOM"* ]]; then
          [[ "$FAKE_SBOM" == "present" ]] && printf '{"spdx":"present"}\n' || printf '{}\n'
          exit 0
        fi
        if [[ "$reference" == *":missing" ]]; then
          echo "manifest unknown" >&2
          exit 1
        fi
        if [[ "$reference" == *":invalid" ]]; then
          printf '"not-a-digest"\n'
          exit 0
        fi
        counter="$FAKE_STATE/inspect-count"
        count="$(cat "$counter" 2>/dev/null || echo 0)"
        if (( count < FAKE_INSPECT_FAILURES )); then
          echo $((count + 1)) > "$counter"
          echo "temporary registry failure" >&2
          exit 1
        fi
        printf '"%s"\n' "$FAKE_DIGEST"
      elif [[ "$1 $2" == "image rm" ]]; then
        exit 0
      else
        echo "Unexpected docker invocation: $*" >&2
        exit 1
      fi
    SH
    FileUtils.chmod(0o755, File.join(@bin, "docker"))
  end
end
