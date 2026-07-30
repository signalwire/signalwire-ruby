# frozen_string_literal: true

# Example: Room joining and SIP REFER via FunctionResult helpers.
#
# Demonstrates join_room for multi-party rooms, sip_refer for SIP
# transfers, and join_conference for ad-hoc conferences.

require 'signalwire'
require 'json'

# --- Basic room join ---

puts '=== Basic Room Join ==='
room = SignalWire::Swaig::FunctionResult.new('Joining the support team room')
                                        .join_room('support_team_room')
                                        .say('Welcome to the support team collaboration room')
puts JSON.pretty_generate(room.to_h)
puts

# --- Conference room with metadata ---

puts '=== Conference Room ==='
conf_room = SignalWire::Swaig::FunctionResult.new('Setting up daily standup meeting')
                                             .join_room('daily_standup_room')
                                             .set_metadata(
                                               'meeting_type' => 'daily_standup',
                                               'participant_id' => 'user_123',
                                               'role' => 'scrum_master'
                                             )
                                             .update_global_data('meeting_active' => true, 'room_name' => 'daily_standup_room')
                                             .say('You have joined the daily standup meeting')
puts JSON.pretty_generate(conf_room.to_h)
puts

# --- SIP REFER transfer ---

puts '=== SIP REFER ==='
sip = SignalWire::Swaig::FunctionResult.new('Transferring to support')
                                       .say('Please hold while I transfer you')
                                       .sip_refer('sip:support@company.com')
puts JSON.pretty_generate(sip.to_h)
puts

# --- Join conference ---

puts '=== Join Conference ==='
conference = SignalWire::Swaig::FunctionResult.new('Joining team conference')
                                              .join_conference('daily_standup')
                                              .say('Welcome to the daily standup conference')
puts JSON.pretty_generate(conference.to_h)
puts

# --- Advanced conference with recording ---

puts '=== Advanced Conference ==='
adv_conf = SignalWire::Swaig::FunctionResult.new('Setting up recorded conference')
                                            .join_conference(
                                              'customer_training_session',
                                              record: 'record-from-start',
                                              max_participants: 50,
                                              status_callback: 'https://api.company.com/conference-events',
                                              status_callback_event: 'start end join leave'
                                            )
                                            .set_metadata('session_type' => 'customer_training', 'facilitator' => 'training_team')
puts JSON.pretty_generate(adv_conf.to_h)
