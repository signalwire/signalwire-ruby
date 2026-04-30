# frozen_string_literal: true

require 'minitest/autorun'
require 'signalwire'

# =========================================================================
# WebMixin parity: on_request / on_swml_request
#
# Python parity:
#   tests/unit/core/mixins/test_web_mixin.py::
#     test_on_request_delegates_to_on_swml_request
#     test_on_swml_request_called
# =========================================================================
class WebMixinTest < Minitest::Test
  # Subclass that overrides on_swml_request to capture inputs and
  # return a configured Hash.
  class CustomService < SignalWire::SWML::Service
    attr_accessor :last_request_data, :last_callback_path, :custom_return

    def initialize(name)
      super(name: name)
      @custom_return = nil
    end

    def on_swml_request(request_data = nil, callback_path = nil)
      @last_request_data = request_data
      @last_callback_path = callback_path
      @custom_return
    end
  end

  def test_on_request_delegates_to_on_swml_request
    svc = CustomService.new('t')
    svc.custom_return = { 'custom' => true }
    rd = { 'data' => 'val' }
    result = svc.on_request(rd, '/cb')
    assert_equal rd, svc.last_request_data
    assert_equal '/cb', svc.last_callback_path
    assert_equal({ 'custom' => true }, result)
  end

  def test_on_swml_request_default_returns_nil
    svc = SignalWire::SWML::Service.new(name: 't')
    assert_nil svc.on_swml_request(nil, nil)
  end

  def test_on_request_default_returns_nil
    svc = SignalWire::SWML::Service.new(name: 't')
    assert_nil svc.on_request(nil, nil)
  end

  def test_on_request_passes_nils_to_hook
    svc = CustomService.new('t')
    svc.custom_return = nil
    result = svc.on_request(nil, nil)
    assert_nil result
    assert_nil svc.last_request_data
    assert_nil svc.last_callback_path
  end
end
