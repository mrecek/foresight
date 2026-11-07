require "test_helper"
require "open3"
require "tempfile"

class RuntimeVersionTest < ActiveSupport::TestCase
  test "one Docker declaration selects the runtime including the next patch" do
    %w[3.4.11 3.4.12].each do |version|
      output, status = read_version("FROM docker.io/library/ruby:#{version}-slim-trixie@sha256:#{'a' * 64} AS os-packages\n")
      assert status.success?, output
      assert_equal version, output.strip
    end
  end

  test "ambiguous or unpinned runtime inputs fail closed" do
    declaration = "FROM docker.io/library/ruby:3.4.12-slim-trixie@sha256:#{'a' * 64} AS os-packages\n"
    [ "", declaration * 2, declaration.sub(/@sha256:[a-f0-9]+/, ""), declaration.sub("3.4.12", "latest") ].each do |contents|
      output, status = read_version(contents)
      assert_not status.success?
      assert_includes output, "exactly one version-and-digest-pinned Ruby base"
    end
  end

  test "runtime discovery is independent of the caller directory" do
    root = Rails.root
    output, status = Open3.capture2e(root.join("bin/ruby-version").to_s, chdir: root.join("app"))
    assert status.success?, output
    assert_match(/\A\d+\.\d+\.\d+\n\z/, output)
  end

  private

  def read_version(contents)
    Tempfile.create("runtime-Dockerfile") do |file|
      file.write(contents)
      file.flush
      Open3.capture2e(Rails.root.join("bin/ruby-version").to_s, file.path)
    end
  end
end
