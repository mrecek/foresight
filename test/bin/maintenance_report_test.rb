require "test_helper"
load Rails.root.join(".github/scripts/report-maintenance-failure")

class MaintenanceReportTest < ActiveSupport::TestCase
  def run_record(lane = 1)
    { "id" => 1, "workflow_id" => lane, "name" => "Audit", "html_url" => "https://example.test/run/1", "head_sha" => "a" * 40, "created_at" => "2026-11-14T20:00:00Z" }
  end

  test "repeats preserve first failure and operator notes without duplicate sections" do
    initial = MaintenanceFailure.body(nil, run_record, [ { "name" => "image", "conclusion" => "failure" } ])
    initial += "\nOperator diagnosis: inspect refresh\n"
    repeat = MaintenanceFailure.body(initial, run_record.merge("html_url" => "https://example.test/run/2"), [ { "name" => "dependencies", "conclusion" => "failure" } ])
    assert_includes repeat, "First observed failure: https://example.test/run/1"
    assert_includes repeat, "Operator diagnosis: inspect refresh"
    assert_includes repeat, "Latest failed run: https://example.test/run/2"
    assert_includes repeat, "Failed stages: dependencies"
    assert_equal 1, repeat.scan("<!-- maintenance-workflow:1 -->").size
    newer = MaintenanceFailure.body(repeat, run_record.merge("id" => 3), [])
    assert_equal newer, MaintenanceFailure.body(newer, run_record.merge("id" => 2), [])
    both = MaintenanceFailure.body(repeat, run_record(2), [])
    assert_includes both, "maintenance-workflow:1"
    assert_includes both, "maintenance-workflow:2"
  end

  test "first failure creates an assigned issue and repeat patches the same issue" do
    saved = ENV.to_h.slice("GITHUB_REPOSITORY", "MAINTENANCE_RUN_ID")
    ENV.update("GITHUB_REPOSITORY" => "example/app", "MAINTENANCE_RUN_ID" => "1")
    original = MaintenanceFailure.method(:gh)
    [ false, true ].each do |existing|
      writes = []
      MaintenanceFailure.define_singleton_method(:gh) do |*args, input: nil|
        if input
          writes << [ args, JSON.parse(input) ]
          {}
        elsif args.first == "issue"
          existing ? [ { "number" => 12, "title" => MaintenanceFailure::TITLE, "body" => "Human diagnosis" } ] : []
        elsif args.include?("--paginate")
          [ { "jobs" => [ { "name" => "image", "conclusion" => "failure" } ] } ]
        else
          { "id" => 1, "workflow_id" => 1, "status" => "completed", "conclusion" => "failure", "name" => "Audit", "html_url" => "https://example.test/run/1", "created_at" => "2026-11-14T20:00:00Z", "head_sha" => "a" * 40 }
        end
      end
      MaintenanceFailure.report
      assert_equal 1, writes.length
      args, payload = writes.first
      assert_includes args, existing ? "PATCH" : "POST"
      assert_equal [ "mrecek" ], payload.fetch("assignees")
      assert_includes payload.fetch("body"), "Human diagnosis" if existing
    end
  ensure
    MaintenanceFailure.define_singleton_method(:gh, original)
    %w[GITHUB_REPOSITORY MAINTENANCE_RUN_ID].each { |key| saved.key?(key) ? ENV[key] = saved[key] : ENV.delete(key) }
  end

  test "successful cancelled or incomplete runs cannot mutate incidents" do
    with_env = { "GITHUB_REPOSITORY" => "example/app", "MAINTENANCE_RUN_ID" => "1" }
    saved = ENV.to_h.slice(*with_env.keys)
    ENV.update(with_env)
    [ [ "completed", "success" ], [ "completed", "cancelled" ], [ "in_progress", nil ] ].each do |status, conclusion|
      calls = 0
      original = MaintenanceFailure.method(:gh)
      begin
        MaintenanceFailure.define_singleton_method(:gh, ->(*) { calls += 1; { "status" => status, "conclusion" => conclusion } })
        MaintenanceFailure.report
      ensure
        MaintenanceFailure.define_singleton_method(:gh, original)
      end
      assert_equal 1, calls
    end
  ensure
    with_env.each_key { |key| saved.key?(key) ? ENV[key] = saved[key] : ENV.delete(key) }
  end
end
