# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

%w[
  bundler/setup
  signalwire
  webmock/rspec
  vcr
].each { |f| require f }

Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.include MockHelpers
  config.filter_run_when_matching :focus
end

VCR.configure do |config|
  config.hook_into :webmock
  config.cassette_library_dir = 'spec/vcr_cassettes'
  # config.allow_http_connections_when_no_cassette = true
end

Signalwire::Logger.logger.level = ::Logger::FATAL