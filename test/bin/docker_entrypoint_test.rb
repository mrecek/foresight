# frozen_string_literal: true

require "digest"
require "fileutils"
require "minitest/autorun"
require "open3"
require "tmpdir"

class DockerEntrypointTest < Minitest::Test
  ENTRYPOINT = File.expand_path("../../bin/docker-entrypoint", __dir__)
  HASH_COMMAND = [
    "ruby", "-rdigest", "-e",
    'print Digest::SHA256.hexdigest(ENV.fetch("SECRET_KEY_BASE"))'
  ].freeze

  def setup
    @directory = Dir.mktmpdir("foresight-secret-test")
    @secret_file = File.join(@directory, ".secret_key_base")
  end

  def teardown
    FileUtils.chmod_R(0o700, @directory) if File.exist?(@directory)
    FileUtils.remove_entry(@directory)
  end

  def test_generates_private_persistent_secret_and_reuses_it
    first = run_entrypoint
    second = run_entrypoint

    assert_success first
    assert_success second
    assert_equal first[:stdout], second[:stdout]
    assert_equal 0o600, File.stat(@secret_file).mode & 0o777
    assert_operator File.binread(@secret_file).strip.bytesize, :>=, 30
    assert_empty first[:stderr]
  end

  def test_external_secret_takes_precedence_without_creating_a_file
    external = "e" * 64
    result = run_entrypoint("SECRET_KEY_BASE" => external)

    assert_success result
    assert_equal Digest::SHA256.hexdigest(external), result[:stdout]
    refute_path_exists @secret_file
  end

  def test_rejects_enabled_embedded_worker_configuration_with_migration_guidance
    result = run_entrypoint("SOLID_QUEUE_IN_PUMA" => "true")

    refute result[:status].success?
    assert_includes result[:stderr], "Run bin/jobs in a separate worker container"
    refute_path_exists @secret_file
  end

  def test_accepts_disabled_embedded_worker_configuration
    assert_success run_entrypoint("SOLID_QUEUE_IN_PUMA" => "false")
  end

  def test_blank_or_short_external_secret_fails_closed
    [ "", "too-short" ].each do |value|
      result = run_entrypoint("SECRET_KEY_BASE" => value)

      refute result[:status].success?
      assert_match(/at least 30 bytes/, result[:stderr])
      refute_path_exists @secret_file
    end
  end

  def test_switching_between_external_and_generated_keys_has_explicit_precedence
    generated = run_entrypoint
    external = run_entrypoint("SECRET_KEY_BASE" => "x" * 64)
    restored = run_entrypoint

    assert_success generated
    assert_success external
    assert_success restored
    refute_equal generated[:stdout], external[:stdout]
    assert_equal generated[:stdout], restored[:stdout]
  end

  def test_concurrent_first_starts_use_one_value
    results = Array.new(8) { Thread.new { run_entrypoint } }.map(&:value)

    results.each { |result| assert_success result }
    assert_equal 1, results.map { |result| result[:stdout] }.uniq.length
  end

  def test_rejects_symbolic_link
    target = File.join(@directory, "target")
    File.write(target, "s" * 64)
    File.chmod(0o600, target)
    File.symlink(target, @secret_file)

    result = run_entrypoint

    refute result[:status].success?
    assert_match(/must not be a symbolic link/, result[:stderr])
  end

  def test_rejects_group_or_other_permissions
    File.write(@secret_file, "s" * 64)
    File.chmod(0o640, @secret_file)

    result = run_entrypoint

    refute result[:status].success?
    assert_match(/must not grant group or other permissions/, result[:stderr])
  end

  def test_rejects_short_persisted_secret
    File.write(@secret_file, "short")
    File.chmod(0o600, @secret_file)

    result = run_entrypoint

    refute result[:status].success?
    assert_match(/at least 30 bytes/, result[:stderr])
  end

  def test_read_only_storage_fails_closed
    File.chmod(0o500, @directory)

    result = run_entrypoint

    refute result[:status].success?
    assert_match(/cannot create a private secret/, result[:stderr])
    refute_path_exists @secret_file
  end

  def test_dockerfile_does_not_bake_a_runtime_secret
    dockerfile_path = File.expand_path("../../Dockerfile", __dir__)
    skip "Dockerfile is intentionally excluded from the runtime image" unless File.exist?(dockerfile_path)

    dockerfile = File.read(dockerfile_path)

    refute_match(/RUN .*rails secret/, dockerfile)
    refute_match(%r{COPY .*\.secret_key_base}, dockerfile)
  end

  def test_only_the_packaged_puma_command_prepares_the_database
    FileUtils.mkdir_p(File.join(@directory, "bin"))
    rails = File.join(@directory, "bin/rails")
    File.write(rails, "#!#{RbConfig.ruby}\nputs ARGV.join(' ')\n")
    bundle = File.join(@directory, "bin/bundle")
    File.write(bundle, "#!#{RbConfig.ruby}\nputs ARGV.join(' ')\n")
    jobs = File.join(@directory, "bin/jobs")
    File.write(jobs, "#!#{RbConfig.ruby}\nputs 'worker'\n")
    FileUtils.chmod(0o700, [ rails, bundle, jobs ])
    environment = {
      "SECRET_KEY_BASE" => "s" * 64,
      "PATH" => "#{@directory}/bin:#{ENV.fetch("PATH")}"
    }

    stdout, stderr, status = Open3.capture3(
      environment, RbConfig.ruby, ENTRYPOINT, "bundle", "exec", "puma", "-C", "config/puma.rb", chdir: @directory
    )
    assert status.success?, stderr
    assert_equal [ "db:prepare", "exec puma -C config/puma.rb" ], stdout.lines.map(&:strip)

    stdout, stderr, status = Open3.capture3(
      environment, RbConfig.ruby, ENTRYPOINT, "bundle", "exec", "puma", "--help", chdir: @directory
    )
    assert status.success?, stderr
    assert_equal [ "exec puma --help" ], stdout.lines.map(&:strip)

    stdout, stderr, status = Open3.capture3(
      environment, RbConfig.ruby, ENTRYPOINT, "bin/jobs", chdir: @directory
    )
    assert status.success?, stderr
    assert_equal [ "worker" ], stdout.lines.map(&:strip)
  end

  private

  def run_entrypoint(environment = {})
    child_environment = {
      "SECRET_KEY_BASE" => nil,
      "SOLID_QUEUE_IN_PUMA" => nil,
      "SECRET_KEY_BASE_FILE" => @secret_file
    }.merge(environment)
    stdout, stderr, status = Open3.capture3(child_environment, RbConfig.ruby, ENTRYPOINT, *HASH_COMMAND)

    { stdout: stdout, stderr: stderr, status: status }
  end

  def assert_success(result)
    assert result[:status].success?, result[:stderr]
    assert_match(/\A[0-9a-f]{64}\z/, result[:stdout])
  end
end
