require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class ContainerCheckTest < ActiveSupport::TestCase
  test "smoke checks use the built image ID and clean the receipt" do
    with_fake_build do |directory, env|
      output, status = Open3.capture2e(env, "bin/container-check", chdir: directory)
      assert status.success?, output
      assert_equal "sha256:#{'a' * 64}", File.read(File.join(directory, "smoked"))
      assert_not File.exist?(File.read(File.join(directory, "iid-path")))
    end
  end

  test "a failed build cannot smoke a previous image" do
    with_fake_build do |directory, env|
      output, status = Open3.capture2e(env.merge("FAKE_BUILD_FAIL" => "1"), "bin/container-check", chdir: directory)
      assert_not status.success?, output
      assert_not File.exist?(File.join(directory, "smoked"))
      assert_not File.exist?(File.read(File.join(directory, "iid-path")))
    end
  end

  private

  def with_fake_build
    Dir.mktmpdir do |directory|
      bin = File.join(directory, "bin")
      FileUtils.mkdir_p(bin)
      FileUtils.cp(Rails.root.join("bin/container-check"), File.join(bin, "container-check"))
      File.write(File.join(bin, "docker"), <<~SH)
        #!/usr/bin/env bash
        set -euo pipefail
        [[ "$1" == "build" && "$2" == "--iidfile" ]]
        printf '%s' "$3" > "$CHECK_ROOT/iid-path"
        [[ "${FAKE_BUILD_FAIL:-0}" == "0" ]] || exit 7
        printf '%s' "sha256:#{'a' * 64}" > "$3"
      SH
      File.write(File.join(bin, "container-smoke"), "#!/usr/bin/env bash\nprintf '%s' \"$1\" > \"$CHECK_ROOT/smoked\"\n")
      FileUtils.chmod(0o755, [ File.join(bin, "docker"), File.join(bin, "container-smoke") ])
      yield directory, { "PATH" => "#{bin}:#{ENV.fetch('PATH')}", "CHECK_ROOT" => directory }
    end
  end
end
