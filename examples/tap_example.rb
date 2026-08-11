# frozen_string_literal: true

# Example: TAP configuration for call monitoring.
#
# Demonstrates starting and stopping tap streams over WebSocket and
# RTP for monitoring, analytics, and compliance.

require 'signalwire'
require 'json'

# --- WebSocket tap ---

puts '=== Basic WebSocket Tap ==='
ws_tap = SignalWire::Swaig::FunctionResult.new('Starting call monitoring')
                                          .tap('wss://monitoring.company.com/audio-stream')
                                          .say('Call monitoring is now active')
puts JSON.pretty_generate(ws_tap.to_h)
puts

# --- RTP tap ---

puts '=== Basic RTP Tap ==='
rtp_tap = SignalWire::Swaig::FunctionResult.new('Starting RTP monitoring')
                                           .tap('rtp://192.168.1.100:5004')
                                           .update_global_data('rtp_monitoring' => true)
puts JSON.pretty_generate(rtp_tap.to_h)
puts

# --- Advanced compliance monitoring ---

puts '=== Compliance Monitoring ==='
compliance = SignalWire::Swaig::FunctionResult.new('Setting up compliance monitoring')
                                              .tap(
                                                'wss://compliance.company.com/secure-stream',
                                                control_id: 'compliance_tap_001',
                                                direction: 'both',
                                                codec: 'PCMA',
                                                status_url: 'https://api.company.com/compliance-events'
                                              )
                                              .set_metadata(
                                                'compliance_session' => true,
                                                'agent_id' => 'agent_123',
                                                'recording_purpose' => 'regulatory_compliance'
                                              )
                                              .say('This call may be monitored for compliance purposes')
puts JSON.pretty_generate(compliance.to_h)
puts

# --- Stop specific tap ---

puts '=== Stop Tap ==='
stop = SignalWire::Swaig::FunctionResult.new('Ending compliance monitoring')
                                        .stop_tap(control_id: 'compliance_tap_001')
                                        .update_global_data('compliance_session' => false)
                                        .say('Compliance monitoring has been deactivated')
puts JSON.pretty_generate(stop.to_h)
puts

# --- Multi-tap management ---

puts '=== Multi-Tap ==='
multi = SignalWire::Swaig::FunctionResult.new('Initialising multi-stream monitoring')
multi
  .tap('wss://compliance.company.com/stream', control_id: 'compliance_stream', direction: 'both')
  .tap('rtp://analytics.company.com:5006',    control_id: 'analytics_stream',  codec: 'PCMA')
  .tap('wss://quality.company.com/monitoring', control_id: 'quality_stream', direction: 'speak')
  .update_global_data(
    'active_streams' => %w[compliance analytics quality],
    'monitoring_level' => 'comprehensive'
  )
puts JSON.pretty_generate(multi.to_h)
