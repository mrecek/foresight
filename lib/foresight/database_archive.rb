# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "rubygems/package"
require "securerandom"
require "sqlite3"
require "time"
require "zlib"

module Foresight
  module DatabaseArchive
    FORMAT_VERSION = 1
    DATABASE_ENTRY = "database.sqlite3"
    MANIFEST_ENTRY = "manifest.json"
    INTERNAL_TABLES = %w[ar_internal_metadata schema_migrations].freeze

    module_function

    def backup(database:, output:)
      source = File.expand_path(database)
      destination = File.expand_path(output)
      validate_new_destination!(destination)
      raise "Primary database does not exist: #{source}" unless File.file?(source)

      snapshot = temporary_path(File.dirname(destination), "snapshot")
      archive = temporary_path(File.dirname(destination), "archive")
      create_sqlite_snapshot(source, snapshot)
      metadata = inspect_database(snapshot).merge(
        "format_version" => FORMAT_VERSION,
        "created_at" => Time.now.utc.iso8601,
        "database_sha256" => Digest::SHA256.file(snapshot).hexdigest,
        "included" => [ "primary financial database and audit logs" ],
        "excluded" => [ "cache database", "queue database", "runtime session secret" ]
      )
      write_archive(archive, snapshot, metadata)
      File.chmod(0o600, archive)
      File.link(archive, destination)
      FileUtils.rm_f(archive)
      sync_directory(File.dirname(destination))
      metadata
    ensure
      FileUtils.rm_f(snapshot) if snapshot
      FileUtils.rm_f(archive) if archive
    end

    def restore(archive:, target:, replace: false)
      source = File.expand_path(archive)
      destination = File.expand_path(target)
      raise "Backup archive does not exist: #{source}" unless File.file?(source)
      validate_restore_destination!(destination, replace: replace)

      extracted = temporary_path(File.dirname(destination), "restore")
      metadata = extract_archive(source, extracted)
      actual_digest = Digest::SHA256.file(extracted).hexdigest
      raise "Backup database checksum does not match its manifest" unless actual_digest == metadata.fetch("database_sha256")

      observed = inspect_database(extracted)
      raise "Backup material record counts do not match its manifest" unless observed.fetch("record_counts") == metadata.fetch("record_counts")
      validate_schema_compatibility!(observed.fetch("schema_version"))
      File.chmod(0o600, extracted)

      preserved = nil
      if File.exist?(destination)
        preserved = "#{destination}.before-restore-#{Time.now.utc.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(4)}"
        File.link(destination, preserved)
        File.rename(extracted, destination)
      else
        File.link(extracted, destination)
        FileUtils.rm_f(extracted)
      end
      sync_directory(File.dirname(destination))
      metadata.merge("replaced_database" => preserved)
    ensure
      FileUtils.rm_f(extracted) if extracted
    end

    def create_sqlite_snapshot(source_path, destination_path)
      source = SQLite3::Database.new(source_path, readonly: true)
      destination = SQLite3::Database.new(destination_path)
      backup = SQLite3::Backup.new(destination, "main", source, "main")
      backup.step(-1)
      backup.finish
    ensure
      backup&.finish rescue nil
      destination&.close
      source&.close
    end
    private_class_method :create_sqlite_snapshot

    def inspect_database(path)
      database = SQLite3::Database.new(path, readonly: true)
      integrity = database.get_first_value("PRAGMA integrity_check")
      raise "SQLite integrity check failed: #{integrity}" unless integrity == "ok"

      tables = database.execute(<<~SQL).flatten - INTERNAL_TABLES
        SELECT name FROM sqlite_schema
        WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
        ORDER BY name
      SQL
      counts = tables.to_h do |table|
        identifier = table.gsub('"', '""')
        [ table, database.get_first_value(%(SELECT COUNT(*) FROM "#{identifier}")).to_i ]
      end
      schema_version = database.get_first_value("SELECT MAX(version) FROM schema_migrations")
      raise "Database has no schema migration version" if schema_version.nil? || schema_version.empty?

      { "integrity_check" => integrity, "schema_version" => schema_version, "record_counts" => counts }
    ensure
      database&.close
    end
    private_class_method :inspect_database

    def write_archive(path, database_path, metadata)
      File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
        gzip = Zlib::GzipWriter.new(file)
        Gem::Package::TarWriter.new(gzip) do |tar|
          manifest = JSON.pretty_generate(metadata) + "\n"
          tar.add_file_simple(MANIFEST_ENTRY, 0o600, manifest.bytesize) { |entry| entry.write(manifest) }
          size = File.size(database_path)
          tar.add_file_simple(DATABASE_ENTRY, 0o600, size) do |entry|
            File.open(database_path, "rb") { |database| IO.copy_stream(database, entry) }
          end
        end
        gzip.finish
        file.flush
        file.fsync
      end
    end
    private_class_method :write_archive

    def extract_archive(path, database_path)
      manifest = nil
      database_seen = false
      names = []
      Zlib::GzipReader.open(path) do |gzip|
        Gem::Package::TarReader.new(gzip) do |tar|
          tar.each do |entry|
            raise "Backup contains an unsafe or unsupported entry: #{entry.full_name}" unless [ MANIFEST_ENTRY, DATABASE_ENTRY ].include?(entry.full_name)
            raise "Backup contains a duplicate entry: #{entry.full_name}" if names.include?(entry.full_name)
            names << entry.full_name
            if entry.full_name == MANIFEST_ENTRY
              manifest = JSON.parse(entry.read)
            else
              File.open(database_path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| IO.copy_stream(entry, file) }
              database_seen = true
            end
          end
        end
      end
      raise "Backup manifest is missing" unless manifest
      raise "Backup database is missing" unless database_seen
      raise "Unsupported backup format version: #{manifest['format_version'].inspect}" unless manifest["format_version"] == FORMAT_VERSION

      manifest
    rescue JSON::ParserError => error
      raise "Backup manifest is invalid JSON: #{error.message}"
    end
    private_class_method :extract_archive

    def validate_schema_compatibility!(backup_version)
      schema = File.read(File.expand_path("../../db/schema.rb", __dir__))
      current = schema[/define\(version: (\d[\d_]*)\)/, 1]&.delete("_")
      raise "Current schema version could not be determined" unless current
      return if backup_version.to_i <= current.to_i

      raise "Backup schema #{backup_version} is newer than supported schema #{current}"
    end
    private_class_method :validate_schema_compatibility!

    def validate_new_destination!(path)
      directory = File.dirname(path)
      raise "Destination directory does not exist: #{directory}" unless File.directory?(directory)
      raise "Destination directory must not be a symbolic link" if File.symlink?(directory)
      raise "Refusing to overwrite existing backup: #{path}" if File.exist?(path) || File.symlink?(path)
    end
    private_class_method :validate_new_destination!

    def validate_restore_destination!(path, replace:)
      directory = File.dirname(path)
      raise "Restore destination directory does not exist: #{directory}" unless File.directory?(directory)
      raise "Restore destination directory must not be a symbolic link" if File.symlink?(directory)
      raise "Restore destination must be a file path" if File.directory?(path)
      raise "Restore destination must not be a symbolic link" if File.symlink?(path)
      if File.exist?(path) && !replace
        raise "Restore destination exists; rerun with --replace after stopping the application"
      end
      if replace && [ "#{path}-wal", "#{path}-shm" ].any? { |sidecar| File.exist?(sidecar) }
        raise "Refusing to replace a database with live WAL state; stop the application and checkpoint it first"
      end
    end
    private_class_method :validate_restore_destination!

    def temporary_path(directory, purpose)
      File.join(directory, ".foresight-#{purpose}-#{Process.pid}-#{SecureRandom.hex(8)}")
    end
    private_class_method :temporary_path

    def sync_directory(directory)
      File.open(directory, "r") { |handle| handle.fsync }
    end
    private_class_method :sync_directory
  end
end
