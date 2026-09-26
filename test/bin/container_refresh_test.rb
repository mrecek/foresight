# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

class ContainerRefreshTest < ActiveSupport::TestCase
  ROOT = Rails.root
  DIGEST = "sha256:#{'a' * 64}"
  OTHER_DIGEST = "sha256:#{'b' * 64}"

  setup do
    @directory = Dir.mktmpdir
    @bin = File.join(@directory, "bin")
    @output = File.join(@directory, "output")
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

  test "identical inventories classify as a no-op" do
    result = classify

    assert result[:status].success?, result[:output]
    classification = JSON.parse(File.read(File.join(@output, "classification.json")))
    assert_equal false, classification.fetch("material_change")
    assert_equal 0, classification.fetch("change_count")
  end

  test "classifies additions removals upgrades and downgrades for both platforms" do
    result = classify({ "FAKE_CANDIDATE_VARIANT" => "changed" })

    assert result[:status].success?, result[:output]
    classification = JSON.parse(File.read(File.join(@output, "classification.json")))
    assert classification.fetch("material_change")
    assert classification.fetch("has_removal")
    assert classification.fetch("has_downgrade")
    assert_equal 8, classification.fetch("change_count")
    assert_equal %w[downgraded upgraded], classification.dig("platforms", "linux/amd64", "changed").pluck("change").sort
  end

  test "a missing promoted release classifies every candidate package as added" do
    result = classify({}, promoted: "none")

    assert result[:status].success?, result[:output]
    classification = JSON.parse(File.read(File.join(@output, "classification.json")))
    assert classification.fetch("material_change")
    assert_equal 8, classification.fetch("change_count")
  end

  test "inventory fails closed when container output is malformed or empty" do
    output, status = run_script(
      "container-package-inventory", "example.test/app@#{DIGEST}", "linux/amd64",
      env: { "FAKE_INVENTORY" => "empty" }
    )

    refute status.success?
    assert_includes output, "inventory was empty"
  end

  test "refresh policy blocks package downgrades and removals while source releases record them" do
    classify({ "FAKE_CANDIDATE_VARIANT" => "changed" })
    path = File.join(@output, "classification.json")

    output, status = run_script("enforce-package-change-policy", path, "weekly-refresh")
    refute status.success?
    assert_includes output, "may not downgrade"

    output, status = run_script("enforce-package-change-policy", path, "source")
    assert status.success?, output
  end

  test "candidate metadata requires both provenance and SBOM" do
    reference = "example.test/app@#{DIGEST}"
    output, status = run_script("check-container-metadata", reference)
    assert status.success?, output

    output, status = run_script("check-container-metadata", reference, env: { "FAKE_SBOM" => "missing" })
    refute status.success?
    assert_includes output, "has no SBOM metadata"
  end

  test "operations use an off-minute weekly refresh and scan the released digest daily" do
    release = ROOT.join(".github/workflows/docker.yml").read
    audit = ROOT.join(".github/workflows/security-audit.yml").read

    assert_includes release, 'cron: "37 7 * * 0"'
    assert_includes audit, 'cron: "15 13 * * *"'
    assert_match(/docker image rm --force "\$reference".*\n\s+docker pull --platform/, release)
    assert_includes audit, 'bin/resolve-image-digest "${REGISTRY}/${IMAGE_NAME}:latest"'
    refute_includes audit, "docker build --tag foresight-security-audit"
    assert_includes audit, "gh workflow run docker.yml"
    assert_includes audit, "critical_due_at"
    assert_includes audit, "Seven-day freshness deadline"
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
        "FAKE_CANDIDATE_VARIANT" => "same",
        "FAKE_INVENTORY" => "valid",
        "FAKE_SBOM" => "present",
        "FAKE_STATE" => @directory
      }.merge(env),
      ROOT.join("bin", name).to_s, *arguments,
      chdir: ROOT
    )
  end

  def classify(overrides = {}, promoted: "example.test/app@#{OTHER_DIGEST}")
    output, status = run_script(
      "classify-container-refresh", promoted, "example.test/app@#{DIGEST}", @output,
      env: overrides
    )
    { output: output, status: status }
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
      elif [[ "$1" == "run" && "$6" == "dpkg-query" ]]; then
        [[ "$FAKE_INVENTORY" != "empty" ]] || exit 0
        reference="$7"
        if [[ "$reference" == *"#{DIGEST}" && "$FAKE_CANDIDATE_VARIANT" == "changed" ]]; then
          printf 'alpha:amd64\tamd64\t2.0\nbeta\tall\t1.0\ndelta\tall\t1.0\nold\tall\t1.0\n'
        else
          printf 'alpha:amd64\tamd64\t1.0\nbeta\tall\t2.0\ngamma\tall\t1.0\nold\tall\t1.0\n'
        fi
      elif [[ "$1" == "run" && "$6" == "dpkg" ]]; then
        new="$9"
        relation="${10}"
        old="${11}"
        if [[ "$relation" == "gt" ]]; then
          [[ "$new" > "$old" ]]
        else
          [[ "$new" < "$old" ]]
        fi
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
