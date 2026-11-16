# frozen_string_literal: true

require "json"
require "yaml"
require "erb"
require "time"
require "pathname"
require "active_record"
require "active_record/database_configurations"
require "active_support/all"
require "sqlite3"
require_relative "authentication/configuration"
require_relative "time_zone"

module Foresight
  # Inspects installation evidence without Rails initialization or writable connections.
  class Diagnostics
    ENVIRONMENTS = %w[development test production].freeze
    HEARTBEAT_SECONDS = 300
    WAIT_SECONDS = 900

    def initialize(root:, environment: ENV, now: Time.now.utc)
      @root, @environment, @now = Pathname(root), environment, now
      @checks = []
      @rails_environment = environment.fetch("RAILS_ENV", "development")
    end

    def call
      check("configuration", "Set RAILS_ENV to development, test or production.") do
        raise ArgumentError unless ENVIRONMENTS.include?(@rails_environment)
        { environment: @rails_environment }
      end
      check("authentication_configuration", "Check AUTH_MODE and its credential/OIDC settings against README configuration requirements.") do
        configuration = Authentication::Configuration.new(environment: @environment, rails_environment: @rails_environment).validate!
        { mode: configuration.mode }
      end
      check("timezone", "Set APP_TIME_ZONE to an IANA timezone or Rails timezone name.") do
        { name: TimeZone.resolve!(@environment.fetch("APP_TIME_ZONE", TimeZone::DEFAULT)) }
      end
      if ENVIRONMENTS.include?(@rails_environment)
        check_secret if @rails_environment == "production"
        inspect_databases
      end
      # Queue retention cannot establish durable successful scheduled execution.
      @checks << { id: "maintenance_coverage", status: "unknown", required: false,
        evidence: "Default inspection does not certify occurrence coverage or last scheduled success.",
        next_action: "Inspect scheduled job evidence; use bin/transfers for an explicit full transfer audit." }
      healthy = @checks.none? { |item| item[:required] && item[:status] != "pass" }
      { schema_version: 1, status: healthy ? "healthy" : "unhealthy",
        runtime: { ruby: RUBY_VERSION, rails: Gem.loaded_specs.fetch("activerecord").version.to_s }, checks: @checks }
    end

    private

    def check(id, action)
      evidence = yield
      @checks << { id: id, status: "pass", required: true, evidence: evidence }
    rescue StandardError
      # Never print exception messages: configuration, SQL and file errors can contain secrets or financial values.
      @checks << { id: id, status: "fail", required: true, next_action: action }
    end

    def check_secret
      check("session_secret", "Provide a valid session secret or run normal web preparation with writable installation storage.") do
        if @environment.key?("SECRET_KEY_BASE")
          raise ArgumentError unless @environment.fetch("SECRET_KEY_BASE").bytesize >= 30
        else
          path = @environment.fetch("SECRET_KEY_BASE_FILE", @root.join("storage/.secret_key_base").to_s)
          stat = File.lstat(path)
          raise ArgumentError unless stat.file? && !stat.symlink? && stat.uid == Process.euid && (stat.mode & 0o077).zero?
          raise ArgumentError unless File.binread(path, 4096).sub(/\n+\z/, "").bytesize >= 30
        end
        "Session key configuration is present; value omitted."
      end
    end

    def inspect_databases
      configurations = nil
      check("database_configuration", "Check config/database.yml and database URL settings; SQLite is required.") do
        config = YAML.safe_load(ERB.new(@root.join("config/database.yml").read).result, aliases: true)
        configurations = ActiveRecord::DatabaseConfigurations.new(config).configs_for(env_name: @rails_environment)
        raise ArgumentError if configurations.empty? || configurations.any? { |item| item.adapter != "sqlite3" }
        { stores: configurations.map(&:name) }
      end
      return unless configurations

      configurations.each do |configuration|
        name = configuration.name
        path = @root.join(configuration.database).expand_path
        check("storage_#{name}", "Check local persistent storage ownership and read/write permissions for this process.") do
          raise IOError unless path.file? && File.readable?(path) && File.writable?(path) && File.writable?(path.dirname)
          "Configured database and its directory are accessible; no write probe performed."
        end
        check("database_#{name}", "Prepare missing stores explicitly with bin/rails db:prepare; inspect schema or unavailable storage.") do
          raise IOError unless path.file?
          open_database(path) do |database|
            check("schema_#{name}", "Inspect pending or unknown migration versions against source; do not guess at missing migration history.") do
              inspect_schema(database, configuration)
              "Schema versions match the application source."
            end
            if name == "primary"
              inspect_primary(database)
            elsif name == "queue"
              inspect_queue(database)
            end
          end
          "Read-only database/schema inspection completed."
        end
      end
    end

    def open_database(path)
      database = SQLite3::Database.new(path.to_s, readonly: true)
      database.busy_timeout = 100
      database.statement_timeout = 1000
      database.execute("PRAGMA query_only = ON")
      yield database
    ensure
      database&.close
    end

    def inspect_schema(database, configuration)
      # Schema identity is compared to source; unknown provenance remains visible.
      if configuration.name == "primary"
        versions = Dir[@root.join("db/migrate/*.rb").to_s]
          .map { |path| File.basename(path).split("_").first.to_i.to_s }.sort
      else
        schema = @root.join("db/#{configuration.name}_schema.rb").read
        version = schema[/define\(version:\s*([\d_]+)/, 1]
        raise ArgumentError unless version
        versions = [ version.delete("_").to_i.to_s ]
      end
      actual = database.execute("SELECT version FROM schema_migrations").flatten.map { |version| version.to_i.to_s }.sort
      raise ArgumentError unless actual == versions
    end

    def inspect_primary(database)
      raise ArgumentError unless database.get_first_value("SELECT COUNT(*) FROM settings WHERE singleton_guard = 1") == 1
    end

    def inspect_queue(database)
      check("worker_heartbeat", "Start/check bin/jobs using the same image, configuration and local storage as the web role.") do
        heartbeat = database.get_first_value("SELECT MAX(last_heartbeat_at) FROM solid_queue_processes WHERE kind = 'Worker'")
        age = age_seconds(heartbeat)
        raise ArgumentError unless age && age.between?(0, HEARTBEAT_SECONDS)
        { age_seconds: age.round, threshold_seconds: HEARTBEAT_SECONDS, scope: "Worker heartbeat only; not scheduled execution proof." }
      end
      check("queue_failures", "Inspect failed Solid Queue executions; diagnose before retrying work.") do
        raise ArgumentError if database.get_first_value("SELECT 1 FROM solid_queue_failed_executions LIMIT 1")
        "No failed execution is currently retained."
      end
      check("queue_wait", "Inspect the worker and waiting work; the observation threshold is not a job deadline.") do
        oldest = database.get_first_value("SELECT created_at FROM solid_queue_ready_executions ORDER BY created_at LIMIT 1")
        age = oldest ? age_seconds(oldest) : 0
        raise ArgumentError unless age && age <= WAIT_SECONDS
        { oldest_ready_age_seconds: age.round, observation_threshold_seconds: WAIT_SECONDS }
      end
    end

    def age_seconds(value)
      @now - Time.parse("#{value} UTC") if value
    end
  end
end
