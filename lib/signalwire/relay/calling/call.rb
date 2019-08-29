# frozen_string_literal: true

require 'forwardable'

module Signalwire::Relay::Calling
  class Call
    include Signalwire::Logger
    include Signalwire::Common
    include Signalwire::Blade::EventHandler
    include Signalwire::Relay::Calling::CallConvenienceMethods
    include Signalwire::Relay::Calling::CallDetectMethods
    extend Forwardable

    attr_reader :device, :type, :node_id, :context, :from, :to,
                :timeout, :tag, :client, :state, :previous_state, :components,
                :busy, :failed, :peer_call
    def_delegators :@client, :relay_execute

    def self.from_event(client, event)
      new(client, event.call_params)
    end

    def initialize(client, call_options)
      @client = client

      @id = call_options[:call_id]
      setup_call_options(call_options)
      @type = @device[:type]

      @from = @device[:params][:from_number]
      @to = @device[:params][:to_number]
      @timeout = @device[:params][:timeout] || 30
      @tag = SecureRandom.uuid

      @components = []

      setup_call_event_handlers
    end

    def setup_call_event_handlers
      @client.on(:event, proc { |evt| call_match_event(evt) }) do |event|
        case event.event_type
        when 'calling.call.connect'
          change_connect_state(event.call_params[:connect_state])
        when 'calling.call.state'
          change_call_state(event.event_params)
        end

        update_call_fields(event.call_params)
        broadcast :event, event
        broadcast :state_change, event
      end
    end

    def change_call_state(event_params)
      call_state = event_params[:params]
      @previous_state = @state
      @state = call_state[:call_state]
      broadcast :call_state_change, previous_state: @previous_state, state: @state
      broadcast @state.to_sym, previous_state: @previous_state, state: @state
      finish_call(event_params) if @state == Relay::CallState::ENDED
    end

    def update_call_fields(call_state)
      @id = call_state[:call_id] if call_state[:call_id]
      @node_id = call_state[:node_id] if call_state[:node_id]
      @peer_call = call_state[:peer] if call_state[:peer]
    end

    def change_connect_state(new_connect_state)
      @previous_connect_state = @connect_state
      @connect_state = new_connect_state
      broadcast :connect_state_change, previous_state: @previous_connect_state, state: @connect_state
    end

    def call_match_event(event)
      event.event_type.match(/calling\.call/) &&
        !event.event_type.match(/receive/) &&
        (event.call_id == id || event.call_params[:tag] == tag)
    end

    def id
      @id ||= SecureRandom.uuid
    end

    def answered?
      @state == 'answered'
    end

    def ended?
      @state == 'ending' || @state == 'ended'
    end

    def active?
      !ended?
    end

    def peer
      @client.calling.find_call_by_id(@peer_call[:call_id]) if @peer_call && @peer_call[:call_id]
    end

    def answer
      answer_component = Signalwire::Relay::Calling::Answer.new(call: self)
      answer_component.wait_for(Relay::CallState::ANSWERED, Relay::CallState::ENDING, Relay::CallState::ENDED)
      AnswerResult.new(component: answer_component)
    end

    def play(play_object)
      play_component = Signalwire::Relay::Calling::Play.new(call: self, play: play_object)
      play_component.wait_for(Relay::CallPlayState::FINISHED, Relay::CallPlayState::ERROR)
      PlayResult.new(component: play_component)
    end

    def play!(play_object)
      play_component = Signalwire::Relay::Calling::Play.new(call: self, play: play_object)
      play_component.execute
      PlayAction.new(component: play_component)
    end

    def prompt(collect_p = nil, play_p = nil, **args)

      collect = args.delete(:collect)
      play = args.delete(:play)

      collect = compile_collect_arguments(args) if collect.nil? && collect_p.nil?
      set_parameters(binding, %i{collect play}, %i{collect play})

      component = Prompt.new(call: self, collect: collect, play: play)
      component.wait_for(Relay::CallPromptState::ERROR, Relay::CallPromptState::NO_INPUT, 
                         Relay::CallPromptState::NO_MATCH, Relay::CallPromptState::DIGIT,
                         Relay::CallPromptState::SPEECH)
      PromptResult.new(component: component)
    end

    def prompt!(collect_p = nil, play_p = nil, **args)
      collect = compile_collect_arguments(args) if collect.nil? && collect_p.nil?
      set_parameters(binding, %i{collect play}, %i{collect play})

      component = Prompt,new(call: self, collect: collect, play: play)
      component.execute
      PromptAction.new(component: component)
    end

    def connect(devices_object)
      component = Connect.new(call: self, devices: devices_object)
      component.wait_for(Relay::CallConnectState::CONNECTED, Relay::CallConnectState::FAILED)
      ConnectResult.new(component: component)
    end

    def connect!(devices_object)
      component = Connect.new(call: self, devices: devices_object)
      component.execute
      ConnectAction.new(component: component)
    end

    def record(audio: nil, type: 'audio', beep: false, format: 'mp3', stereo: false, direction: 'speak', initial_timeout: 5, end_silence_timeout: 1, terminators: "#*")
      if audio.nil?
        record_object = {
          "#{type}": 
          { 
            beep: beep,
            format: format,
            stereo: stereo,
            direction: direction,
            initial_timeout: initial_timeout,
            end_silence_timeout: end_silence_timeout,
            terminators: terminators
          } 
        }
      else
        record_object = { "#{type}": audio }
      end

      component = Record.new(call: self, record: record_object)
      component.wait_for(Relay::CallRecordState::NO_INPUT, Relay::CallRecordState::FINISHED)
      RecordResult.new(component: component)
    end

    def record!(audio: nil, type: 'audio', beep: false, format: 'mp3', stereo: false, direction: 'speak', initial_timeout: 5, end_silence_timeout: 1, terminators: "#*")
      if audio.nil?
        record_object = {
          "#{type}": 
          { 
            beep: beep,
            format: format,
            stereo: stereo,
            direction: direction,
            initial_timeout: initial_timeout,
            end_silence_timeout: end_silence_timeout,
            terminators: terminators
          } 
        }
      else
        record_object = { "#{type}": audio }
      end

      component = Record.new(call: self, record: record_object)
      component.execute
      RecordAction.new(component: component)
    end

    def hangup(reason = 'hangup')
      hangup_component = Signalwire::Relay::Calling::Hangup.new(call: self, reason: reason)
      hangup_component.wait_for(Relay::CallState::ENDED)
      HangupResult.new(component: hangup_component)
    end

    def dial
      dial_component = Signalwire::Relay::Calling::Dial.new(call: self)
      dial_component.wait_for(Relay::CallState::ANSWERED, Relay::CallState::ENDING, Relay::CallState::ENDED)
      DialResult.new(component: dial_component)
    end

    def fax_receive
      component = Signalwire::Relay::Calling::FaxReceive.new(call: self)
      component.wait_for(Relay::CallFaxState::ERROR, Relay::CallFaxState::FINISHED)
      FaxResult.new(component: component)
    end

    def fax_receive!
      component = Signalwire::Relay::Calling::FaxReceive.new(call: self)
      component.execute
      FaxAction.new(component: component)
    end

    def fax_send(document:, identity: nil, header: nil)
      component = Signalwire::Relay::Calling::FaxSend.new(call: self, document: document, identity: identity, header: header)
      component.wait_for(Relay::CallFaxState::ERROR, Relay::CallFaxState::FINISHED)
      FaxResult.new(component: component)
    end

    def fax_send!(document:, identity: nil, header: nil)
      component = Signalwire::Relay::Calling::FaxSend.new(call: self, document: document, identity: identity, header: header)
      component.execute
      FaxAction.new(component: component)
    end

    def tap_media(**args)
      tap = args.delete(:tap)
      device = args.delete(:device)

      tap = compile_tap_arguments(args) if tap.nil?
      device = compile_tap_device_arguments(args) if device.nil?

      component = Signalwire::Relay::Calling::Tap.new(call: self, tap: tap, device: device)
      component.wait_for(Relay::CallTapState::FINISHED)
      TapResult.new(component: component)
    end

    def tap_media!(tap:, device:)
      tap = args.delete(:tap)
      device = args.delete(:device)

      tap = compile_tap_arguments(args) if tap.nil?
      device = compile_tap_device_arguments(args) if device.nil?
      
      component = Signalwire::Relay::Calling::Tap.new(call: self, tap: tap, device: device)
      component.execute
      TapAction.new(component: component)
    end

    def wait_for(*events)
      events = [Relay::CallState::ENDED] if events.empty?
      
      current_state_index = Relay::CALL_STATES.find_index(@state)
      max_index = events.map { |evt| Relay::CALL_STATES.find_index(evt) }.max

      return true if current_state_index >= max_index

      component = Await.new(call: self)
      component.wait_for(*events)
      component.successful
    end

    def register_component(component)
      @components << component
    end

    def terminate_components(params = {})
      @components.each do |comp|
        comp.terminate(params) unless component.completed
      end
    end

    def finish_call(params)
      terminate_components(params)
      client.calling.end_call(id)
      @busy = true if params[:reason] == Relay::DisconnectReason::BUSY
      @failed = true if params[:reason] == Relay::DisconnectReason::FAILED
      broadcast :ended, previous_state: @previous_state, state: @state
    end

  private

    def setup_call_options(call_options)
      @node_id = call_options[:node_id]
      @context = call_options[:context]
      @previous_state = nil
      @state = call_options[:call_state]
      @previous_connect_state = nil
      @connect_state = call_options[:connect_state]
      @device = call_options[:device]
      @busy = false
      @failed = false
    end

    def set_parameters(passed_binding, keys, mandatory_keys)
      keys.each do |x| 
        passed_binding.local_variable_set(x, passed_binding.local_variable_get(x) || passed_binding.local_variable_get("#{x}_p"))
      end
      mandatory_keys.each do |x|
        raise ArgumentError, "The #{x} argument must be provided" if passed_binding.local_variable_get(x).nil?
      end
    end

    def compile_tap_arguments(args)
      tap = { params: {} }
      tap[:type] = args[:media_type] || 'audio'
      tap[:params][:direction] = args[:audio_direction] if args[:audio_direction]
      tap[:params][:rate] = args[:rate] if args[:rate]
      tap[:params][:codec] = args[:codec] if args[:codec]
      tap
    end

    def compile_tap_device_arguments(args)
      device = { params: {} }
      device[:type] = args[:target_type] || 'rtp'
      device[:params][:addr] = args[:target_addr] if args[:target_addr]
      device[:params][:port] = args[:target_port] if args[:target_port]
      device[:params][:ptime] = args[:target_ptime] if args[:target_ptime]
      device[:params][:uri] = args[:target_uri] if args[:target_uri]
      device
    end

    def compile_collect_arguments(args)
      generic_fields = %i{initial_timeout partial_results}
      digit_fields = %i{digits_max digits_terminators digits_timeout}
      speech_fields = %i{speech_timeout speech_language speech_hints end_silence_timeout}
      has_digits = (digit_fields & args.keys).any?
      has_speech = (speech_fields & args.keys).any?

      collect = {}
      generic_fields.each { |gf| collect[gf] = args[gf] if args[gf] }

      if has_digits
        digits_obj = {}
        digits_obj[:max] = args[:digits_max] if args[:digits_max]
        digits_obj[:terminators] = args[:digits_terminators] if args[:digits_terminators]
        digits_obj[:digit_timeout] = args[:digits_timeout] if args[:digits_timeout]
        collect[:digits] = digits_obj
      end

      if has_speech
        speech_obj = {}
        speech_obj[:timeout] = args[:speech_timeout] if args[:speech_timeout]
        speech_obj[:language] = args[:speech_language] if args[:speech_language]
        speech_obj[:hints] = args[:speech_hints] if args[:speech_hints]
        speech_obj[:end_silence_timeout] = args[:end_silence_timeout] if args[:end_silence_timeout]
        collect[:digits] = digits_obj
      end

      collect
    end
  end
end
