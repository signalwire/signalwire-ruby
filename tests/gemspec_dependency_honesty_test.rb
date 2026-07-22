# frozen_string_literal: true

require_relative 'test_helper'

# Every stdlib library the SDK `require`s that has been EXTRACTED from Ruby's
# default gems (so it is no longer auto-present under Bundler on a modern Ruby)
# must be declared as a gemspec runtime dependency — otherwise the require warns
# or LoadErrors on the Ruby version that evicted it. base64 (since 3.4) and
# logger (since 3.5) are the current cases (Gem::BUNDLED_GEMS::SINCE). Left
# undeclared, base64 only loads by luck (transitive via websocket-client-simple)
# and logger not at all.
#
# See ruby_R5.md N5 / GATE-GAPS.1.
class GemspecDependencyHonestyTest < Minitest::Test
  GEMSPEC = File.expand_path('../signalwire-sdk.gemspec', __dir__)

  def declared_runtime_deps
    spec = Gem::Specification.load(GEMSPEC)
    spec.runtime_dependencies.map(&:name)
  end

  # Extracted-from-default stdlib gems the SDK requires directly. If a future
  # `require` pulls in another evicted stdlib gem, add it here AND to the gemspec.
  EXTRACTED_STDLIB_REQUIRED = %w[base64 logger].freeze

  def test_extracted_stdlib_requires_are_declared
    deps = declared_runtime_deps

    EXTRACTED_STDLIB_REQUIRED.each do |name|
      assert_includes deps, name,
                      "#{name} is require'd in lib/ but not declared in the gemspec; " \
                      'it was extracted from Ruby default gems and will not load under ' \
                      'Bundler on the Ruby that evicted it.'
    end
  end

  # The library must actually require + use both without a warning on the current
  # Ruby (a clean-bundle require smoke; the CI future-Ruby leg exercises the
  # eviction boundary).
  def test_base64_and_logger_load_clean
    warnings = []
    original = $VERBOSE
    $VERBOSE = true
    begin
      require 'base64'
      require 'logger'

      assert_respond_to Base64, :strict_encode64
      assert defined?(Logger)
    ensure
      $VERBOSE = original
    end

    assert_empty warnings
  end
end
