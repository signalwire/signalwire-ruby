module Signalwire::Relay::Calling
  module CallDetectMethods

    def detect(type:, **args)
      component = build_detect_component(type, args)
      component.wait_for(Relay::CallDetectState::MACHINE, Relay::CallDetectState::HUMAN,
        Relay::CallDetectState::UNKNOWN, Relay::CallDetectState::CED, Relay::CallDetectState::CNG)
      DetectResult.new(component: component)
    end

    def detect!(type:, **args)
      component = build_detect_component(type, args)
      component.execute
      DetectAction.new(component: component)
    end

    def detect_answering_machine(**args)
      detect(type: :machine, **args)
    end

    def detect_answering_machine!(**args)
      detect!(type: :machine, **args)
    end

    def amd(**args)
      detect(type: :machine, **args)
    end

    def amd!(**args)
      detect!(type: :machine, **args)
    end

    # deprecated since version 2.2. Will be deleted in version 3.0.
    def detect_human(params: {}, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      detect = {
        type: Relay::CallDetectType::MACHINE,
        params: params
      }
      component = Signalwire::Relay::Calling::Detect.new(call: self, detect: detect, timeout: timeout)
      component.wait_for(Relay::CallDetectState::MACHINE, Relay::CallDetectState::UNKNOWN, Relay::CallDetectState::HUMAN)
      DetectResult.new(component: component)
    end

    # deprecated since version 2.2. Will be deleted in version 3.0.
    def detect_human!(params: {}, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      detect = {
        type: Relay::CallDetectType::MACHINE,
        params: params
      }
      component = Signalwire::Relay::Calling::Detect.new(call: self, detect: detect, timeout: timeout)
      component.setup_waiting_events([Relay::CallDetectState::MACHINE, Relay::CallDetectState::UNKNOWN, Relay::CallDetectState::HUMAN])
      component.execute
      DetectAction.new(component: component)
    end

    # deprecated since version 2.2. Will be deleted in version 3.0.
    def detect_machine(params: {}, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      detect = {
        type: Relay::CallDetectType::MACHINE,
        params: params
      }
      component = Signalwire::Relay::Calling::Detect.new(call: self, detect: detect, timeout: timeout)
      component.wait_for(Relay::CallDetectState::MACHINE, Relay::CallDetectState::UNKNOWN, Relay::CallDetectState::HUMAN)
      DetectResult.new(component: component)
    end

    # deprecated since version 2.2. Will be deleted in version 3.0.
    def detect_machine!(params: {}, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      detect = {
        type: Relay::CallDetectType::MACHINE,
        params: params
      }
      component = Signalwire::Relay::Calling::Detect.new(call: self, detect: detect, timeout: timeout)
      component.setup_waiting_events([Relay::CallDetectState::MACHINE, Relay::CallDetectState::UNKNOWN, Relay::CallDetectState::HUMAN])
      component.execute
      DetectAction.new(component: component)                                
    end

    def detect_fax(tone: nil, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      detect(type: :fax, tone: tone, timeout: timeout)
    end

    def detect_fax!(tone: nil, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      detect!(type: :fax, tone: tone, timeout: timeout)    
    end

    def detect_digit(digits: nil, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      detect(type: :digit, digits: digits, timeout: timeout)
    end

    def detect_digit!(digits: nil, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      detect!(type: :digit, digits: digits, timeout: timeout)
    end

    private 

    def build_detect_component(type, args)
      detect = args.delete(:detect)
      timeout = args.delete(:timeout) || Relay::DEFAULT_CALL_TIMEOUT
      wait_for_beep = args.delete(:wait_for_beep)

      if detect.nil?
        detect = { params: {} }
        detect[:type] = type.to_sym || :machine
        
        if detect[:type] == :machine
          %i{initial_timeout end_silence_timeout machine_voice_threshold machine_words_threshold}.each do |key|
            detect[:params][key] = args[key] if args[key]
          end
        elsif detect[:type] == :fax
          detect[:params][:tone] = args[:tone]
        elsif detect[:type] == :digit
          detect[:params][:digits] = args[:digits]
        end
      end

      component = Signalwire::Relay::Calling::Detect.new(call: self, detect: detect, wait_for_beep: wait_for_beep, timeout: timeout)
    end
  end
end