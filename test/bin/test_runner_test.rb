require "test_helper"
require "open3"
require "tmpdir"

class TestRunnerTest < ActiveSupport::TestCase
  test "paths names lines and seeds select tests and empty selections fail" do
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
    end
  end

  def run_tests(*arguments)
    Open3.capture2e("bin/test", *arguments, chdir: Rails.root)
  end
end
