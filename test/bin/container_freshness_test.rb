require "test_helper"
require "open3"
require "tmpdir"

class ContainerFreshnessTest < ActiveSupport::TestCase
  IMAGE = "example.test/app@sha256:#{'a' * 64}"
  NOW = Time.utc(2026, 11, 14, 20)

  test "fresh completion evidence passes independently of Docker creation metadata" do
    assert_nil probe((NOW - 60).iso8601)[:exit]
  end

  test "stale missing malformed and future evidence fail" do
    [ (NOW - 7.days - 1).iso8601, "", "not-a-date", (NOW + 301).iso8601 ].each do |marker|
      assert_equal 1, probe(marker)[:exit], marker
    end
    assert_equal 1, probe(NOW.iso8601, missing: true)[:exit]
  end

  test "seven day boundary is inclusive and current build rejects older refresh" do
    assert_nil probe((NOW - 7.days).iso8601)[:exit]
    assert_equal 1, probe((NOW - 60).iso8601, started: NOW.iso8601)[:exit]
    assert_nil probe(NOW.iso8601, started: NOW.iso8601)[:exit]
  end

  test "a failed package refresh cannot write completion evidence" do
    dockerfile = Rails.root.join("Dockerfile").read
    command = dockerfile.split("RUN ", 2).last.split("\n\n", 2).first.gsub("\\\n", "")
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "apt-get"), "#!/bin/sh\nexit 42\n")
      File.chmod(0o755, File.join(directory, "apt-get"))
      marker = File.join(directory, "completed")
      command = command.sub("/usr/local/share/foresight-os-refreshed-at", marker)
      _, status = Open3.capture2e({ "PATH" => "#{directory}:#{ENV.fetch('PATH')}" }, "sh", "-c", command)
      assert_equal 42, status.exitstatus
      refute File.exist?(marker)
    end
  end

  private

  def replace_method(target, name, replacement)
    original = target.method(name)
    target.define_singleton_method(name, replacement)
    yield
  ensure
    target.define_singleton_method(name, original)
  end

  def probe(marker, started: nil, missing: false)
    saved = ARGV.dup
    ARGV.replace([ IMAGE, "linux/arm64", started ].compact)
    success = Struct.new(:success?).new(true)
    failure = Struct.new(:success?).new(false)
    result = {}
    docker = lambda do |*args|
      if args.include?("cat")
        [ marker, "missing", missing ? failure : success ]
      else
        [ "", "", success ]
      end
    end
    result[:output] = capture_io do
      replace_method(Time, :now, -> { NOW }) do
        replace_method(Open3, :capture3, docker) do
          begin
            load Rails.root.join("bin/check-container-freshness")
          rescue SystemExit => error
            result[:exit] = error.status
          end
        end
      end
    end
    result
  ensure
    ARGV.replace(saved)
  end
end
