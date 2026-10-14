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

  test "every release candidate receives the complete verification contract" do
    release = YAML.safe_load_file(ROOT.join(".github/workflows/docker.yml"), aliases: true)
    steps = release.fetch("jobs").fetch("release").fetch("steps")
    gates = [
      "Verify candidate platforms", "Verify candidate provenance and SBOM",
      "Validate application at candidate source", "Smoke test candidate on amd64 and arm64",
      "Scan amd64 candidate with Trivy", "Enforce amd64 vulnerability policy",
      "Scan and enforce arm64 vulnerability policy", "Generate provenance attestation",
      "Promote verified candidate"
    ]
    gates.each do |name|
      step = steps.find { |entry| entry["name"] == name }
      assert step, "Missing release gate: #{name}"
      assert_nil step["if"], "Release gate must not depend on package differences: #{name}"
    end
  end

  test "daily rebuild and read-only audit do not depend on automated merge events" do
    release = ROOT.join(".github/workflows/docker.yml").read
    audit = ROOT.join(".github/workflows/security-audit.yml").read

    assert_includes release, 'cron: "37 7 * * *"'
    assert_includes release, "no-cache-filters: os-packages"
    assert_includes release, "scheduled-refresh"
    assert_includes audit, 'bin/resolve-image-digest "${REGISTRY}/${IMAGE_NAME}:latest"'
    refute_includes audit, "gh workflow run"
    refute_includes audit, "actions: write"
    refute_includes audit, "critical_due_at"
    assert_includes audit, "bin/container-gem-versions"
  end

  test "registry scans select each platform independently of local Docker images" do
    %w[docker security-audit].each do |workflow|
      config = YAML.safe_load_file(ROOT.join(".github/workflows/#{workflow}.yml"), aliases: true)
      steps = config.fetch("jobs").values.flat_map { |job| job.fetch("steps") }
      scan = steps.find { |step| step.fetch("uses", "").start_with?("aquasecurity/trivy-action@") }
      assert_equal "remote", scan.fetch("env").fetch("TRIVY_IMAGE_SRC")
      assert_equal "linux/amd64", scan.fetch("env").fetch("TRIVY_PLATFORM")
      assert steps.any? { |step| step.fetch("run", "").include?("trivy image --image-src remote --platform linux/arm64") }
    end
  end

  private

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
