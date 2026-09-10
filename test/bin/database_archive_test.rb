require "test_helper"
require "fileutils"
require "json"
require "open3"
require "rubygems/package"
require "sqlite3"
require "tmpdir"
require "zlib"

class DatabaseArchiveTest < ActiveSupport::TestCase
  ROOT = Rails.root

  setup do
    @directory = Dir.mktmpdir
    @database = File.join(@directory, "production.sqlite3")
    @archive = File.join(@directory, "backup.tar.gz")
    @restored = File.join(@directory, "restored.sqlite3")
    @connection = SQLite3::Database.new(@database)
    @connection.execute("PRAGMA journal_mode=WAL")
    @connection.execute("CREATE TABLE schema_migrations (version varchar NOT NULL PRIMARY KEY)")
    @connection.execute("INSERT INTO schema_migrations VALUES ('20260910000000')")
    @connection.execute("CREATE TABLE accounts (id integer PRIMARY KEY, name varchar NOT NULL)")
    @connection.execute("CREATE TABLE audit_logs (id integer PRIMARY KEY, action varchar NOT NULL)")
    @connection.execute("INSERT INTO accounts (name) VALUES ('Checking')")
    @connection.execute("INSERT INTO audit_logs (action) VALUES ('created')")
  end

  teardown do
    @connection&.close
    FileUtils.remove_entry(@directory)
  end

  test "live WAL database round trips with metadata and restrictive permissions" do
    backup = run_command("bin/backup", "--database", @database, "--output", @archive)
    assert backup[:status].success?, backup[:output]
    assert_equal 0o600, File.stat(@archive).mode & 0o777
    assert_equal %w[database.sqlite3 manifest.json], archive_entries.sort

    restore = run_command("bin/restore", "--archive", @archive, "--target", @restored)
    assert restore[:status].success?, restore[:output]
    assert_equal 0o600, File.stat(@restored).mode & 0o777

    restored = SQLite3::Database.new(@restored)
    assert_equal [ [ "Checking" ] ], restored.execute("SELECT name FROM accounts")
    assert_equal [ [ "created" ] ], restored.execute("SELECT action FROM audit_logs")
    assert_equal "ok", restored.get_first_value("PRAGMA integrity_check")
  ensure
    restored&.close
  end

  test "archive excludes cache queue and runtime secret state" do
    assert run_command("bin/backup", "--database", @database, "--output", @archive)[:status].success?

    assert_equal %w[database.sqlite3 manifest.json], archive_entries.sort
    manifest = archive_manifest
    assert_includes manifest.fetch("excluded"), "cache database"
    assert_includes manifest.fetch("excluded"), "queue database"
    assert_includes manifest.fetch("excluded"), "runtime session secret"
  end

  test "restore refuses an existing destination without explicit replacement" do
    assert run_command("bin/backup", "--database", @database, "--output", @archive)[:status].success?
    File.write(@restored, "do not overwrite")

    refused = run_command("bin/restore", "--archive", @archive, "--target", @restored)
    assert_not refused[:status].success?
    assert_includes refused[:output], "rerun with --replace"
    assert_equal "do not overwrite", File.read(@restored)

    replaced = run_command("bin/restore", "--archive", @archive, "--target", @restored, "--replace")
    assert replaced[:status].success?, replaced[:output]
    assert Dir.glob("#{@restored}.before-restore-*").one?
  end

  test "restore rejects backup schemas newer than this application" do
    @connection.execute("DELETE FROM schema_migrations")
    @connection.execute("INSERT INTO schema_migrations VALUES ('99990101000000')")
    assert run_command("bin/backup", "--database", @database, "--output", @archive)[:status].success?

    restore = run_command("bin/restore", "--archive", @archive, "--target", @restored)
    assert_not restore[:status].success?
    assert_includes restore[:output], "newer than supported"
    refute_path_exists @restored
  end

  test "restore accepts an older schema for migration on next application startup" do
    @connection.execute("DELETE FROM schema_migrations")
    @connection.execute("INSERT INTO schema_migrations VALUES ('20250101000000')")
    assert run_command("bin/backup", "--database", @database, "--output", @archive)[:status].success?

    restore = run_command("bin/restore", "--archive", @archive, "--target", @restored)
    assert restore[:status].success?, restore[:output]
    assert File.file?(@restored)
  end

  test "restore rejects corrupt archives without publishing a target" do
    assert run_command("bin/backup", "--database", @database, "--output", @archive)[:status].success?
    bytes = File.binread(@archive)
    File.binwrite(@archive, bytes.byteslice(0, bytes.bytesize / 2))

    restore = run_command("bin/restore", "--archive", @archive, "--target", @restored)
    assert_not restore[:status].success?
    refute_path_exists @restored
  end

  private

  def run_command(*arguments)
    output, status = Open3.capture2e(ROOT.join(arguments.shift).to_s, *arguments, chdir: ROOT)
    { output: output, status: status }
  end

  def archive_entries
    entries = []
    Zlib::GzipReader.open(@archive) do |gzip|
      Gem::Package::TarReader.new(gzip) { |tar| tar.each { |entry| entries << entry.full_name } }
    end
    entries
  end

  def archive_manifest
    manifest = nil
    Zlib::GzipReader.open(@archive) do |gzip|
      Gem::Package::TarReader.new(gzip) do |tar|
        tar.each { |entry| manifest = JSON.parse(entry.read) if entry.full_name == "manifest.json" }
      end
    end
    manifest
  end
end
