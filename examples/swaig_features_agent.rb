# frozen_string_literal: true

# Example: FunctionResult actions showcase.
#
# Demonstrates various FunctionResult helper methods including
# connect, hangup, hold, say, update_global_data, set_metadata,
# switch_context, toggle_functions, and more.

require 'signalwire'
require 'json'

puts '=== Call Control ==='

# Transfer a call
transfer = SignalWire::Swaig::FunctionResult.new('Transferring you now.')
  .connect('+15559876543')
puts "Transfer: #{JSON.pretty_generate(transfer.to_h)}"
puts

# Hang up
hangup = SignalWire::Swaig::FunctionResult.new('Goodbye!')
  .hangup
puts "Hangup: #{JSON.pretty_generate(hangup.to_h)}"
puts

# Hold
hold = SignalWire::Swaig::FunctionResult.new('Placing you on hold.')
  .hold(120)
puts "Hold: #{JSON.pretty_generate(hold.to_h)}"
puts

puts '=== State & Data ==='

# Update global data
state = SignalWire::Swaig::FunctionResult.new('Preferences saved.')
  .update_global_data('delivery_window' => 'morning', 'sms_updates' => true)
puts "Global data: #{JSON.pretty_generate(state.to_h)}"
puts

# Set metadata
meta = SignalWire::Swaig::FunctionResult.new('Session tracked.')
  .set_metadata('interaction_type' => 'support', 'priority' => 'high')
puts "Metadata: #{JSON.pretty_generate(meta.to_h)}"
puts

puts '=== Media Control ==='

# Say
speak = SignalWire::Swaig::FunctionResult.new('Done.')
  .say('Here is an important announcement.')
puts "Say: #{JSON.pretty_generate(speak.to_h)}"
puts

# Play background file
bg = SignalWire::Swaig::FunctionResult.new('Playing hold music.')
  .play_background_file('https://cdn.example.com/hold-music.mp3')
puts "Background play: #{JSON.pretty_generate(bg.to_h)}"
puts

puts '=== Context & Step ==='

# Switch context
ctx_switch = SignalWire::Swaig::FunctionResult.new('Switching context.')
  .switch_context(system_prompt: 'You are now a billing assistant.')
puts "Context switch: #{JSON.pretty_generate(ctx_switch.to_h)}"
puts

# Change step
step = SignalWire::Swaig::FunctionResult.new('Moving to next step.')
  .swml_change_step('review')
puts "Change step: #{JSON.pretty_generate(step.to_h)}"
puts

puts '=== Advanced ==='

# Toggle functions
toggle = SignalWire::Swaig::FunctionResult.new('Functions updated.')
  .toggle_functions([
    { 'function' => 'get_weather', 'active' => false },
    { 'function' => 'get_time',    'active' => true }
  ])
puts "Toggle functions: #{JSON.pretty_generate(toggle.to_h)}"
puts

# Send SMS
sms = SignalWire::Swaig::FunctionResult.new('SMS sent.')
  .send_sms(
    to_number:   '+15551234567',
    from_number: '+15559876543',
    body:        'Your appointment is confirmed for tomorrow at 10 AM.'
  )
puts "Send SMS: #{JSON.pretty_generate(sms.to_h)}"
puts

# Method chaining
chained = SignalWire::Swaig::FunctionResult.new('Processing complete.')
  .say('Let me transfer you now.')
  .update_global_data('transfer_initiated' => true)
  .connect('+15551112222')
puts "Chained: #{JSON.pretty_generate(chained.to_h)}"
