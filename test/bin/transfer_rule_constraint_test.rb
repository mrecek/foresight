require "test_helper"
require "open3"
require "tmpdir"

class TransferRuleConstraintTest < ActiveSupport::TestCase
  VERSION = "20261116010000"

  test "fresh migrations and schema loading both reject self transfers at the database boundary" do
    [ "db:migrate", "db:schema:load" ].each do |command|
      with_database do |database, environment|
        run_rails(environment, command)
        assert_database_guard(database)
      end
    end
  end

  test "an upgrade preserves existing records and replaces legacy triggers" do
    with_database do |database, environment|
      run_rails(environment, "db:migrate", "VERSION=20261116000000")
      db = SQLite3::Database.new(database)
      add_accounts(db)
      insert_rule(db, type: 2, destination: 2)
      before = db.execute("SELECT * FROM recurring_rules")
      db.close

      run_rails(environment, "db:migrate")
      db = SQLite3::Database.new(database)
      assert_equal before, db.execute("SELECT * FROM recurring_rules")
      assert_empty db.execute("SELECT name FROM sqlite_master WHERE type = 'trigger'")
      db.close
      assert_database_guard(database, create_accounts: false)
    end
  end

  test "invalid legacy records abort upgrade without rewriting data or migration history" do
    with_database do |database, environment|
      run_rails(environment, "db:migrate", "VERSION=20261116000000")
      db = SQLite3::Database.new(database)
      add_accounts(db)
      %w[insert update].each { |operation| db.execute("DROP TRIGGER enforce_different_transfer_accounts_#{operation}") }
      insert_rule(db, type: 2, destination: 1)
      before = db.execute("SELECT * FROM recurring_rules")
      db.close

      output, status = Open3.capture2e(environment, "bin/rails", "db:migrate")
      assert_not status.success?
      assert_includes output, "1 recurring rules use the same source and destination"
      db = SQLite3::Database.new(database)
      assert_equal before, db.execute("SELECT * FROM recurring_rules")
      assert_equal 0, db.get_first_value("SELECT COUNT(*) FROM schema_migrations WHERE version = ?", VERSION)
      db.close
    end
  end

  private

  def with_database
    Dir.mktmpdir("foresight-rule-constraint") do |directory|
      database = File.join(directory, "installation.sqlite3")
      environment = { "RAILS_ENV" => "test", "DATABASE_URL" => "sqlite3:#{database}",
        "SCHEMA" => File.join(directory, "schema.rb"), "SEED_DEMO_DATA" => nil }
      # Schema-loading must use the tracked schema, while migration dumps stay isolated.
      FileUtils.cp(Rails.root.join("db/schema.rb"), environment["SCHEMA"])
      yield database, environment
    end
  end

  def run_rails(environment, *arguments)
    output, status = Open3.capture2e(environment, "bin/rails", *arguments)
    assert status.success?, output
  end

  def add_accounts(database)
    [ "Checking", "Savings" ].each do |name|
      database.execute("INSERT INTO accounts (name, current_balance, balance_date, created_at, updated_at) VALUES (?, 100, '2026-11-15', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)", name)
    end
  end

  def insert_rule(database, type:, destination:)
    database.execute(<<~SQL, [ destination, type ])
      INSERT INTO recurring_rules (account_id, destination_account_id, rule_type, description,
        amount, frequency, anchor_date, created_at, updated_at)
      VALUES (1, ?, ?, 'Rule', 10, 0, '2026-11-15', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end

  def assert_database_guard(path, create_accounts: true)
    database = SQLite3::Database.new(path)
    add_accounts(database) if create_accounts
    assert_raises(SQLite3::ConstraintException) { insert_rule(database, type: 2, destination: 1) }
    insert_rule(database, type: 2, destination: 2)
    id = database.last_insert_row_id
    assert_raises(SQLite3::ConstraintException) { database.execute("UPDATE recurring_rules SET destination_account_id = 1 WHERE id = ?", id) }
    insert_rule(database, type: 1, destination: 1)
    id = database.last_insert_row_id
    assert_raises(SQLite3::ConstraintException) { database.execute("UPDATE recurring_rules SET rule_type = 2 WHERE id = ?", id) }
  ensure
    database&.close
  end
end
