# frozen_string_literal: true

require "test_helper"
require "json"
require "open3"
require "tempfile"

class ContainerRetentionTest < ActiveSupport::TestCase
  POLICY = Rails.root.join("bin/plan-container-retention")
  NOW = "2026-09-26T12:00:00Z"

  test "keeps five promoted digests and current latest while expiring old releases and candidates" do
    versions = (1..7).map do |number|
      tags = [ "release-2026090#{number}T120000Z-aaaaaaaaaaaa-#{number}-1" ]
      tags << "candidate-old-#{number}"
      tags << "latest" if number == 1
      version(number, "2026-09-0#{number}T12:00:00Z", tags)
    end
    versions.concat([
      version(20, "2026-09-01T12:00:00Z", [ "candidate-expired" ]),
      version(21, "2026-09-20T12:00:00Z", [ "candidate-fresh" ]),
      version(22, "2026-08-01T12:00:00Z", [])
    ])

    result = plan(versions)
    assert result[:status].success?, result[:output]
    document = JSON.parse(result[:output])
    assert_equal [ 2, 20 ], document.fetch("delete").pluck("id").sort
    assert_includes document.fetch("protected").pluck("id"), 1
    assert_includes document.fetch("protected").pluck("id"), 22
  end

  test "keeps all releases when fewer than five exist and produces a stable repeated plan" do
    versions = (1..3).map do |number|
      version(number, "2026-09-0#{number}T12:00:00Z", [ "release-2026090#{number}T120000Z-aaaaaaaaaaaa-#{number}-1" ])
    end

    first = plan(versions)
    second = plan(versions)
    assert first[:status].success?
    assert_equal first[:output], second[:output]
    assert_empty JSON.parse(first[:output]).fetch("delete")
  end

  test "fails closed on partial registry metadata" do
    result = plan([ { "id" => 1, "created_at" => NOW } ])

    refute result[:status].success?
    assert_includes result[:output], "Incomplete package version metadata"
  end

  test "retention workflow serializes with promotion and defaults manual runs to dry-run" do
    workflow = Rails.root.join(".github/workflows/container-retention.yml").read

    assert_includes workflow, "group: foresight-container-production"
    assert_includes workflow, "default: false"
    assert_includes workflow, "inputs.apply == true"
    assert_includes workflow, "bin/plan-container-retention"
  end

  private

  def version(id, created_at, tags)
    {
      "id" => id,
      "created_at" => created_at,
      "metadata" => { "container" => { "tags" => tags } }
    }
  end

  def plan(versions)
    Tempfile.create([ "versions", ".json" ]) do |file|
      file.write(JSON.generate(versions))
      file.flush
      output, status = Open3.capture2e(POLICY.to_s, file.path, NOW)
      return { output: output, status: status }
    end
  end
end
