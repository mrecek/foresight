require "test_helper"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

class ContainerReleaseTest < ActiveSupport::TestCase
  ROOT = Rails.root
  DIGEST = "sha256:#{'a' * 64}"
  OTHER_DIGEST = "sha256:#{'b' * 64}"
  SHA = "1" * 40
  DATE = "2026.09.10"

  setup do
    @directory = Dir.mktmpdir
    @state = File.join(@directory, "state")
    @bin = File.join(@directory, "bin")
    FileUtils.mkdir_p([ @state, @bin ])
    write_fake_tools
  end

  teardown { FileUtils.remove_entry(@directory) }

  test "promotion writes the completion marker last and reruns as a no-op" do
    first = promote
    assert first[:status].success?, first[:output]

    creates = File.readlines(File.join(@state, "creates"), chomp: true)
    assert_equal [ "#{DATE}-1111111", DATE, "latest", "sha-#{SHA}" ], creates

    File.write(File.join(@state, "creates"), "")
    second = promote
    assert second[:status].success?, second[:output]
    assert_empty File.read(File.join(@state, "creates"))
  end

  test "immutable collision fails before mutable tags move" do
    File.write(File.join(@state, "#{DATE}-1111111"), OTHER_DIGEST)

    result = promote

    assert_not result[:status].success?
    assert_includes result[:output], "Immutable tag collision"
    refute_path_exists File.join(@state, "latest")
  end

  test "stale default branch and failed attestation leave release tags unchanged" do
    stale = promote("FAKE_HEAD_SHA" => "2" * 40)
    assert_not stale[:status].success?
    refute_path_exists File.join(@state, "latest")

    unattested = promote("FAKE_ATTESTATION" => "fail")
    assert_not unattested[:status].success?
    refute_path_exists File.join(@state, "latest")
  end

  test "partial promotion converges to the expected digest" do
    File.write(File.join(@state, "#{DATE}-1111111"), DIGEST)
    File.write(File.join(@state, DATE), DIGEST)

    result = promote

    assert result[:status].success?, result[:output]
    assert_equal DIGEST, File.read(File.join(@state, "latest"))
    assert_equal DIGEST, File.read(File.join(@state, "sha-#{SHA}"))
  end

  test "a failed mutable-tag update is repaired by the next run" do
    failed = promote("FAKE_FAIL_TAG" => "latest")
    assert_not failed[:status].success?
    assert_equal DIGEST, File.read(File.join(@state, "#{DATE}-1111111"))
    refute_path_exists File.join(@state, "sha-#{SHA}")

    repaired = promote
    assert repaired[:status].success?, repaired[:output]
    assert_equal DIGEST, File.read(File.join(@state, "sha-#{SHA}"))
  end

  test "manifest validation fails when an architecture is absent" do
    result = promote("FAKE_MANIFEST" => '{"manifests":[{"platform":{"os":"linux","architecture":"amd64"}}]}')

    assert_not result[:status].success?
    assert_includes result[:output], "missing platforms: linux/arm64"
    refute_path_exists File.join(@state, "latest")
  end

  test "workflows keep candidates unpromoted until verification and reconcile drift" do
    release = ROOT.join(".github/workflows/docker.yml").read
    reconcile = ROOT.join(".github/workflows/reconcile-container-release.yml").read
    ci = ROOT.join(".github/workflows/ci.yml").read

    assert_operator release.index("Build and push unpromoted candidate"), :<, release.index("Smoke test candidate")
    assert_operator release.index("Smoke test candidate"), :<, release.index("Generate provenance attestation")
    assert_operator release.index("Generate provenance attestation"), :<, release.index("Promote verified candidate")
    assert_includes release, "DOCKER_DEFAULT_PLATFORM=\"$platform\""
    assert_operator release.index("bin/container-smoke \"$reference\""), :<, release.index("docker image rm \"$reference\"")
    assert_includes reconcile, "bin/promote-container-release"
    assert_includes reconcile, "Safely redispatch a missing release"
    assert_includes ci, "bin/validate container"
  end

  private

  def promote(overrides = {})
    env = {
      "PATH" => "#{@bin}:#{ENV.fetch('PATH')}",
      "FAKE_STATE" => @state,
      "FAKE_DIGEST" => DIGEST,
      "FAKE_HEAD_SHA" => SHA,
      "FAKE_ATTESTATION" => "pass",
      "FAKE_FAIL_TAG" => "",
      "FAKE_MANIFEST" => JSON.generate(
        "manifests" => [
          { "platform" => { "os" => "linux", "architecture" => "amd64" } },
          { "platform" => { "os" => "linux", "architecture" => "arm64" } }
        ]
      ),
      "GITHUB_REPOSITORY" => "example/foresight",
      "GITHUB_DEFAULT_BRANCH" => "main"
    }.merge(overrides)
    output, status = Open3.capture2e(
      env,
      ROOT.join("bin/promote-container-release").to_s,
      "ghcr.io/example/foresight", DIGEST, SHA, DATE,
      chdir: ROOT
    )
    { output: output, status: status }
  end

  def write_fake_tools
    File.write(File.join(@bin, "docker"), <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      if [[ "$1 $2 $3 $4" == "buildx imagetools inspect --raw" ]]; then
        printf '%s\n' "$FAKE_MANIFEST"
      elif [[ "$1 $2 $3" == "buildx imagetools inspect" ]]; then
        tag="${4##*:}"
        [[ -f "$FAKE_STATE/$tag" ]] || exit 1
        printf '"%s"\n' "$(<"$FAKE_STATE/$tag")"
      elif [[ "$1 $2 $3" == "buildx imagetools create" ]]; then
        tag="${5##*:}"
        [[ "$tag" != "$FAKE_FAIL_TAG" ]] || exit 1
        printf '%s' "$FAKE_DIGEST" > "$FAKE_STATE/$tag"
        printf '%s\n' "$tag" >> "$FAKE_STATE/creates"
      else
        echo "Unexpected docker invocation: $*" >&2
        exit 1
      fi
    SH
    File.write(File.join(@bin, "gh"), <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      if [[ "$1" == "api" ]]; then
        printf '%s\n' "$FAKE_HEAD_SHA"
      elif [[ "$1 $2" == "attestation verify" && "$FAKE_ATTESTATION" == "pass" ]]; then
        exit 0
      else
        exit 1
      fi
    SH
    FileUtils.chmod(0o755, [ File.join(@bin, "docker"), File.join(@bin, "gh") ])
  end
end
