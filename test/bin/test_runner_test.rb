require "test_helper"
require "open3"
require "tmpdir"

class TestRunnerTest < ActiveSupport::TestCase
  test "paths names lines and seeds select tests and empty selections fail" do
    database = ActiveRecord::Base.connection_db_config.database
    inode = File.stat(database).ino
    with_fixture do |path|
      output, status = run_tests(path, "--seed", "1234", "-n", "test_selected")
      assert status.success?, output
      assert_includes output, "1 runs, 1 assertions"
      assert_includes output, "--seed 1234"
      output, status = run_tests("#{path}:4")
      assert status.success?, output
      assert_includes output, "1 runs, 1 assertions"
      output, status = run_tests(File.dirname(path))
      assert status.success?, output
      assert_includes output, "2 runs, 2 assertions"
      output, status = run_tests(path, "-n", "test_absent")
      assert_not status.success?, output
      assert_includes output, "No tests executed"
      _, status = run_tests(path, "--not-an-option")
      assert_not status.success?
      assert_equal inode, File.stat(database).ino, "Nested runner replaced the parent database"
    end
  end

  test "test setup builds styles from a checkout without compiled assets" do
    stylesheet = Rails.root.join("app/assets/builds/tailwind.css")
    original = stylesheet.binread if stylesheet.exist?
    stylesheet.delete if stylesheet.exist?
    with_fixture do |path|
      output, status = run_tests(path)
      assert status.success?, output
      assert stylesheet.file?
      assert_includes stylesheet.read, "--foresight-content"
    end
  ensure
    if original
      stylesheet.binwrite(original)
    elsif stylesheet&.exist?
      stylesheet.delete
    end
  end

  test "application browser and standalone failures produce nonzero exits" do
    [ [ "test_helper", "ActiveSupport::TestCase" ],
      [ "application_system_test_case", "ApplicationSystemTestCase" ],
      [ "minitest/autorun", "Minitest::Test" ] ].each do |helper, parent|
      with_fixture(helper: helper, parent: parent, assertion: "flunk 'intentional runner probe'") do |path|
        output, status = run_tests(path)
        assert_not status.success?, output
        assert_includes output, "intentional runner probe"
      end
    end
  end

  private

  def with_fixture(helper: "test_helper", parent: "ActiveSupport::TestCase", assertion: "assert true")
    Dir.mktmpdir("foresight-runner") do |directory|
      @runner_database = File.join(directory, "runner.sqlite3")
      path = File.join(directory, "probe_test.rb")
      File.write(path, <<~CODE)
        require #{helper.inspect}
        class RunnerProbeTest < #{parent}
          def test_selected
            #{assertion}
          end
          def test_other
            assert true
          end
        end
      CODE
      yield path
    ensure
      @runner_database = nil
    end
  end

  def run_tests(*arguments)
    # A runner invocation prepares its database; it must never reset this
    # process's database while pooled connections still refer to it.
    Open3.capture2e({ "DATABASE_URL" => "sqlite3:#{@runner_database}" }, "bin/test", *arguments, chdir: Rails.root)
  end
end
