# frozen_string_literal: true

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
  RELEASE_ID = "20260910T120000Z-#{SHA[0, 12]}-123-1"
  RELEASE_TAG = "release-#{RELEASE_ID}"

  setup do
    @directory = Dir.mktmpdir
    @state = File.join(@directory, "state")
    @bin = File.join(@directory, "bin")
    FileUtils.mkdir_p([ @state, @bin ])
    write_fake_tools
  end

  teardown { FileUtils.remove_entry(@directory) }

  test "promotion establishes an immutable recovery tag before latest and reruns as a no-op" do
    first = promote
    assert first[:status].success?, first[:output]
    assert_equal [ RELEASE_TAG, "latest" ], File.readlines(File.join(@state, "creates"), chomp: true)

    File.write(File.join(@state, "creates"), "")
    second = promote
    assert second[:status].success?, second[:output]
    assert_empty File.read(File.join(@state, "creates"))
  end

  test "immutable collision stale source and attestation failure cannot move production" do
    File.write(File.join(@state, RELEASE_TAG), OTHER_DIGEST)
    collision = promote
    refute collision[:status].success?
    assert_includes collision[:output], "Immutable tag collision"
    refute_path_exists File.join(@state, "latest")

    FileUtils.rm_f(File.join(@state, RELEASE_TAG))
    stale = promote("FAKE_HEAD_SHA" => "2" * 40)
    refute stale[:status].success?
    unattested = promote("FAKE_ATTESTATION" => "fail")
    refute unattested[:status].success?
    refute_path_exists File.join(@state, "latest")
  end

  test "optimistic guard rejects a concurrent production change" do
    File.write(File.join(@state, "latest"), OTHER_DIGEST)
    result = promote("EXPECTED_PROMOTED_DIGEST" => DIGEST)

    refute result[:status].success?
    assert_includes result[:output], "Production changed during verification"
    assert_equal OTHER_DIGEST, File.read(File.join(@state, "latest"))
  end

  test "partial promotion converges after immutable tag creation" do
    File.write(File.join(@state, RELEASE_TAG), DIGEST)
    result = promote

    assert result[:status].success?, result[:output]
    assert_equal DIGEST, File.read(File.join(@state, "latest"))
  end

  test "rollback restores an exact retained verified digest and guards against stale operator state" do
    File.write(File.join(@state, RELEASE_TAG), OTHER_DIGEST)
    File.write(File.join(@state, "latest"), DIGEST)
    result = rollback
    assert result[:status].success?, result[:output]
    assert_equal OTHER_DIGEST, File.read(File.join(@state, "latest"))

    File.write(File.join(@state, "latest"), OTHER_DIGEST)
    stale = rollback
    refute stale[:status].success?
    assert_includes stale[:output], "Production changed before rollback"
  end

  test "release and rollback workflows share one serialized production lane" do
    release = ROOT.join(".github/workflows/docker.yml").read
    rollback = ROOT.join(".github/workflows/rollback-container-release.yml").read

    assert_includes release, "group: foresight-container-production"
    assert_includes rollback, "group: foresight-container-production"
    assert_operator release.index("Build and push unpromoted candidate"), :<, release.index("Promote verified candidate")
    assert_includes rollback, "EXPECTED_CURRENT_DIGEST"
    assert_includes rollback, "bin/rollback-container-release"
  end

  private

  def base_env
    {
      "PATH" => "#{@bin}:#{ENV.fetch('PATH')}",
      "FAKE_STATE" => @state,
      "FAKE_HEAD_SHA" => SHA,
      "FAKE_ATTESTATION" => "pass",
      "FAKE_MANIFEST" => JSON.generate(
        "manifests" => [
          { "platform" => { "os" => "linux", "architecture" => "amd64" } },
          { "platform" => { "os" => "linux", "architecture" => "arm64" } }
        ]
      ),
      "GITHUB_REPOSITORY" => "example/foresight",
      "GITHUB_DEFAULT_BRANCH" => "main",
      "REGISTRY_RETRY_ATTEMPTS" => "1"
    }
  end

  def promote(overrides = {})
    output, status = Open3.capture2e(
      base_env.merge(overrides),
      ROOT.join("bin/promote-container-release").to_s,
      "ghcr.io/example/foresight", DIGEST, SHA, RELEASE_ID, "weekly-refresh",
      chdir: ROOT
    )
    { output: output, status: status }
  end

  def rollback(overrides = {})
    output, status = Open3.capture2e(
      base_env.merge(overrides),
      ROOT.join("bin/rollback-container-release").to_s,
      "ghcr.io/example/foresight", RELEASE_TAG, DIGEST, "operator test",
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
      elif [[ "$1 $2 $3" == "buildx imagetools inspect" && "${6:-}" == *".Provenance"* ]]; then
        printf '{"builder":"buildkit"}\n'
      elif [[ "$1 $2 $3" == "buildx imagetools inspect" && "${6:-}" == *".SBOM"* ]]; then
        printf '{"spdx":"present"}\n'
      elif [[ "$1 $2 $3" == "buildx imagetools inspect" ]]; then
        tag="${4##*:}"
        [[ -f "$FAKE_STATE/$tag" ]] || { echo "manifest unknown" >&2; exit 1; }
        printf '"%s"\n' "$(<"$FAKE_STATE/$tag")"
      elif [[ "$1 $2 $3" == "buildx imagetools create" ]]; then
        tag="${5##*:}"
        digest="${6##*@}"
        printf '%s' "$digest" > "$FAKE_STATE/$tag"
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
