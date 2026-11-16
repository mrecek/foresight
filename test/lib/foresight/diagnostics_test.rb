require "test_helper"
require "foresight/diagnostics"
require "tmpdir"
require "fileutils"
require "digest"
require "open3"

class DiagnosticsTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir("foresight-diagnostics")
    @root = Pathname(@directory)
    FileUtils.mkdir_p(@root.join("config"))
    FileUtils.mkdir_p(@root.join("storage"))
    FileUtils.mkdir_p(@root.join("db/migrate"))
    @root.join("db/migrate/1_initial.rb").write("# schema identity fixture\n")
    %w[queue cache].each { |name| @root.join("db/#{name}_schema.rb").write("ActiveRecord::Schema.define(version: 1)\n") }
    @root.join("config/database.yml").write(<<~YAML)
      production:
        primary:
          adapter: sqlite3
          database: storage/primary.sqlite3
        queue:
          adapter: sqlite3
          database: storage/queue.sqlite3
        cache:
          adapter: sqlite3
          database: storage/cache.sqlite3
    YAML
    @environment = { "RAILS_ENV" => "production", "SECRET_KEY_BASE" => "s" * 64, "APP_TIME_ZONE" => "UTC" }
    @now = Time.utc(2026, 11, 15, 12)
    %w[primary queue cache].each do |name|
      with_database(name) do |db|
        db.execute("CREATE TABLE schema_migrations (version text)")
        db.execute("INSERT INTO schema_migrations VALUES ('1')")
      end
    end
    with_database("primary") do |db|
      db.execute("CREATE TABLE settings (singleton_guard integer)")
      db.execute("INSERT INTO settings VALUES (1)")
    end
    with_database("queue") do |db|
      db.execute("CREATE TABLE solid_queue_processes (kind text, last_heartbeat_at text)")
      db.execute("INSERT INTO solid_queue_processes VALUES ('Worker', ?)", [ (@now - 30).strftime("%F %T") ])
      db.execute("CREATE TABLE solid_queue_failed_executions (job_id integer)")
      db.execute("CREATE TABLE solid_queue_ready_executions (created_at text)")
    end
  end

  teardown { FileUtils.remove_entry(@directory) }

  test "healthy checks are read-only and maintenance scope is explicit" do
    before = storage_snapshot
    report = diagnose
    assert_equal "healthy", report[:status]
    assert_equal "pass", check(report, "worker_heartbeat")[:status]
    assert_equal "unknown", check(report, "maintenance_coverage")[:status]
    assert_equal false, check(report, "maintenance_coverage")[:required]
    assert_equal before, storage_snapshot
  end

  test "missing stores and incomplete settings are reported without preparation" do
    with_database("primary") { |db| db.execute("DELETE FROM settings") }
    @root.join("storage/cache.sqlite3").delete
    before = storage_snapshot
    report = diagnose
    assert_equal "unhealthy", report[:status]
    assert_equal "fail", check(report, "database_primary")[:status]
    assert_equal "fail", check(report, "database_cache")[:status]
    assert_equal before, storage_snapshot
    assert_not @root.join("storage/.secret_key_base").exist?
  end

  test "unknown and pending migration history are explicit" do
    with_database("primary") { |db| db.execute("INSERT INTO schema_migrations VALUES ('2')") }
    assert_equal "fail", check(diagnose, "schema_primary")[:status]
    with_database("primary") { |db| db.execute("DELETE FROM schema_migrations") }
    assert_equal "fail", check(diagnose, "schema_primary")[:status]
  end

  test "absent and stale worker and queued failures are unhealthy" do
    with_database("queue") { |db| db.execute("DELETE FROM solid_queue_processes") }
    assert_equal "fail", check(diagnose, "worker_heartbeat")[:status]
    with_database("queue") do |db|
      db.execute("INSERT INTO solid_queue_processes VALUES ('Worker', ?)", [ (@now - 301).strftime("%F %T") ])
      db.execute("INSERT INTO solid_queue_failed_executions VALUES (1)")
      db.execute("INSERT INTO solid_queue_ready_executions VALUES (?)", [ (@now - 901).strftime("%F %T") ])
    end
    report = diagnose
    %w[worker_heartbeat queue_failures queue_wait].each { |id| assert_equal "fail", check(report, id)[:status] }
  end

  test "invalid configuration cannot disclose values in exception messages" do
    secret = "do-not-disclose-this-value"
    @environment.merge!("APP_TIME_ZONE" => secret, "AUTH_MODE" => secret, "OIDC_CLIENT_SECRET" => secret)
    report = diagnose
    assert_equal "unhealthy", report[:status]
    assert_not_includes JSON.generate(report), secret
  end

  test "session key inspection does not generate a missing key" do
    @environment.delete("SECRET_KEY_BASE")
    report = diagnose
    assert_equal "fail", check(report, "session_secret")[:status]
    assert_not @root.join("storage/.secret_key_base").exist?
  end

  test "a read-only installation can be inspected without attempted repair" do
    paths = Dir[@root.join("storage/*").to_s]
    paths.each { |path| File.chmod(0o400, path) }
    File.chmod(0o500, @root.join("storage"))
    before = storage_snapshot
    report = diagnose
    assert_equal "unhealthy", report[:status]
    assert_equal "pass", check(report, "database_primary")[:status]
    assert_equal before, storage_snapshot
  ensure
    File.chmod(0o700, @root.join("storage"))
    paths&.each { |path| File.chmod(0o600, path) }
  end

  test "CLI JSON stays valid for unhealthy state and invalid arguments" do
    missing = @root.join("storage/absent.sqlite3").to_s
    environment = { "RAILS_ENV" => "test", "DATABASE_URL" => "sqlite3:#{missing}", "APP_TIME_ZONE" => "UTC" }
    output, error, status = Open3.capture3(environment, "bin/doctor", "--json")
    assert_equal 1, status.exitstatus, error
    assert_equal "unhealthy", JSON.parse(output).fetch("status")
    assert_empty error
    assert_not File.exist?(missing)
    output, _, status = Open3.capture3(environment, "bin/doctor", "--json", "--unknown")
    assert_equal 2, status.exitstatus
    assert_equal "error", JSON.parse(output).fetch("status")
    output, _, status = Open3.capture3(environment, "bin/doctor")
    assert_equal 1, status.exitstatus
    assert_includes output, "FAIL database_primary"
  end

  private

  def diagnose
    Foresight::Diagnostics.new(root: @root, environment: @environment, now: @now).call
  end

  def check(report, id)
    report.fetch(:checks).find { |item| item[:id] == id } || flunk("Missing #{id}")
  end

  def with_database(name)
    db = SQLite3::Database.new(@root.join("storage/#{name}.sqlite3").to_s)
    yield db
  ensure
    db&.close
  end

  def storage_snapshot
    Dir[@root.join("storage/*").to_s].sort.to_h { |path| [ File.basename(path), Digest::SHA256.file(path).hexdigest ] }
  end
end
