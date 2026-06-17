# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/rest/rest_client'

class RestCallingDetailedTest < Minitest::Test
  def setup
    @http = SignalWire::REST::HttpClient.new('proj', 'tok', 'test.signalwire.com')
  end

  def test_calling_path
    resource = SignalWire::REST::Namespaces::CallingNamespace.new(@http)

    assert_equal '/api/calling/calls', resource.instance_variable_get(:@base_path)
  end

  def test_calling_namespace_exists
    client = SignalWire::REST::RestClient.new(
      project: 'proj', token: 'tok', host: 'test.signalwire.com'
    )

    refute_nil client.calling
  end
end
