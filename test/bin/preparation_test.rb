require "test_helper"
require "open3"
require "tmpdir"

class PreparationTest < ActiveSupport::TestCase
  test "explicit preparation initializes state while boot leaves missing settings alone" do
    Dir.mktmpdir("foresight-prepare") do |directory|
      database = File.join(directory, "installation.sqlite3")
      environment = { "RAILS_ENV" => "test", "DATABASE_URL" => "sqlite3:#{database}", "SEED_DEMO_DATA" => nil }
      output, status = Open3.capture2e(environment, "bin/rails", "db:prepare")
      assert status.success?, output
      connection = SQLite3::Database.new(database)
      assert_equal 1, connection.get_first_value("SELECT COUNT(*) FROM settings")
      connection.execute("UPDATE settings SET default_view_months = 6")
      output, status = Open3.capture2e(environment, "bin/rails", "db:prepare")
      assert status.success?, output
      assert_equal 6, connection.get_first_value("SELECT default_view_months FROM settings")
      connection.execute("DELETE FROM settings")
      output, status = Open3.capture2e(environment, "bin/rails", "runner", "raise 'state created' unless Setting.count.zero?")
      assert status.success?, output
      assert_equal 0, connection.get_first_value("SELECT COUNT(*) FROM settings")
    ensure
      connection&.close
    end
  end

  test "Rails initialization does not create an absent database" do
    Dir.mktmpdir("foresight-unprepared") do |directory|
      database = File.join(directory, "missing.sqlite3")
      output, status = Open3.capture2e({ "RAILS_ENV" => "test", "DATABASE_URL" => "sqlite3:#{database}" },
        "bin/rails", "runner", "puts 'booted'")
      assert status.success?, output
      assert_not File.exist?(database)
    end
  end
end
