# frozen_string_literal: true

# Example: Call recording via FunctionResult helpers.
#
# Demonstrates record_call and stop_record_call actions from within
# tool handlers, including basic recording, voicemail, and a complete
# customer-service workflow.

require 'signalwire'
require 'json'

# --- Basic recording ---

puts '=== Basic Recording ==='
basic = SignalWire::Swaig::FunctionResult.new('Starting basic call recording')
                                         .record_call
                                         .say('This call is now being recorded')
puts JSON.pretty_generate(basic.to_h)
puts

# --- Advanced recording ---

puts '=== Advanced Recording ==='
advanced = SignalWire::Swaig::FunctionResult.new('Starting advanced call recording')
                                            .record_call(
                                              control_id: 'support_call_001',
                                              stereo: true,
                                              format: 'mp3',
                                              direction: 'both',
                                              beep: true,
                                              max_length: 600,
                                              status_url: 'https://api.company.com/recording-webhook'
                                            )
                                            .say('This call is being recorded for quality and training purposes')
puts JSON.pretty_generate(advanced.to_h)
puts

# --- Voicemail ---

puts '=== Voicemail Recording ==='
voicemail = SignalWire::Swaig::FunctionResult.new('Please leave your message after the beep')
                                             .record_call(
                                               control_id: 'voicemail_123',
                                               format: 'wav',
                                               direction: 'speak',
                                               beep: true,
                                               initial_timeout: 5.0,
                                               end_silence_timeout: 3.0,
                                               max_length: 120
                                             )
                                             .set_end_of_speech_timeout(2000)
puts JSON.pretty_generate(voicemail.to_h)
puts

# --- Stop recording ---

puts '=== Stop Recording ==='
stop_rec = SignalWire::Swaig::FunctionResult.new('Ending call recording')
                                            .stop_record_call(control_id: 'support_call_001')
                                            .say('Thank you for calling. Your feedback is important to us.')
puts JSON.pretty_generate(stop_rec.to_h)
puts

# --- Customer service workflow ---

puts '=== Customer Service Workflow ==='

start_rec = SignalWire::Swaig::FunctionResult.new('Transferring you to an agent')
                                             .record_call(
                                               control_id: 'cs_transfer_001',
                                               format: 'mp3',
                                               direction: 'both',
                                               beep: false,
                                               max_length: 1800,
                                               status_url: 'https://api.company.com/recording-status'
                                             )
                                             .update_global_data('recording_id' => 'cs_transfer_001')
                                             .say('Please hold while I connect you')

puts 'Start recording:'
puts JSON.pretty_generate(start_rec.to_h)
puts

end_rec = SignalWire::Swaig::FunctionResult.new('Call recording stopped')
                                           .stop_record_call(control_id: 'cs_transfer_001')
                                           .remove_global_data('recording_id')
                                           .say('Thank you for calling. Have a wonderful day!')

puts 'End recording:'
puts JSON.pretty_generate(end_rec.to_h)
