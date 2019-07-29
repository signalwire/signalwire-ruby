module Signalwire::Relay::Calling
  module CallDetectMethods
    def detect(detect:, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      component = Signalwire::Relay::Calling::Detect.new(call: self, detect: detect, timeout: timeout)
      component.wait_for(Relay::CallDetectState::FINISHED, Relay::CallDetectState::ERROR)
      DetectResult.new(component: component)
    end

    def detect!(detect:, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      component = Signalwire::Relay::Calling::Detect.new(call: self, detect: detect, timeout: timeout)
      component.execute
      DetectAction.new(component: component)
    end

    def detect_human(params: {}, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      detect = {
        type: Relay::CallDetectType::MACHINE,
        params: params
      }
      component = Signalwire::Relay::Calling::Detect.new(call: self, detect: detect, timeout: timeout)
      component.wait_for(Relay::CallDetectState::FINISHED, Relay::CallDetectState::ERROR, Relay::CallDetectState::HUMAN)
      DetectResult.new(component: component)
    end

    def detect_human!(params: {}, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      detect = {
        type: Relay::CallDetectType::MACHINE,
        params: params
      }
      component = Signalwire::Relay::Calling::Detect.new(call: self, detect: detect, timeout: timeout)
      component.setup_waiting_events([Relay::CallDetectState::FINISHED, Relay::CallDetectState::ERROR, Relay::CallDetectState::HUMAN])
      component.execute
      DetectAction.new(component: component)
    end

    def detect_machine(params: {}, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      detect = {
        type: Relay::CallDetectType::MACHINE,
        params: params
      }
      component = Signalwire::Relay::Calling::Detect.new(call: self, detect: detect, timeout: timeout)
      component.wait_for(Relay::CallDetectState::FINISHED, Relay::CallDetectState::ERROR, 
                         Relay::CallDetectState::MACHINE, Relay::CallDetectState::READY,
                         Relay::CallDetectState::NOT_READY)
      DetectResult.new(component: component)
    end

    def detect_machine!(params: {}, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      detect = {
        type: Relay::CallDetectType::MACHINE,
        params: params
      }
      component = Signalwire::Relay::Calling::Detect.new(call: self, detect: detect, timeout: timeout)
      component.setup_waiting_events([Relay::CallDetectState::FINISHED, Relay::CallDetectState::ERROR, 
                                      Relay::CallDetectState::MACHINE, Relay::CallDetectState::READY,
                                      Relay::CallDetectState::NOT_READY])
      component.execute
      DetectAction.new(component: component)                                
    end

    def detect_fax(tone: nil, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      detect, events = prepare_fax_arguments(tone)

      component = Signalwire::Relay::Calling::Detect.new(call: self, detect: detect, timeout: timeout)
      component.wait_for(*events)
      DetectResult.new(component: component)
    end

    def detect_fax!(tone: nil, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      detect, events = prepare_fax_arguments(tone)
      component = Signalwire::Relay::Calling::Detect.new(call: self, detect: detect, timeout: timeout)
      component.setup_waiting_events(events)
      component.execute
      DetectAction.new(component: component)     
    end

    def detect_digit(digits: nil, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      detect = {
        type: Relay::CallDetectType::DIGIT,
        params: {}
      }
      detect[:params][:digits] = digits if digits
      detect(detect: detect, timeout: timeout)
    end

    def detect_digit!(digits: nil, timeout: Relay::DEFAULT_CALL_TIMEOUT)
      detect = {
        type: Relay::CallDetectType::DIGIT,
        params: {}
      }
      detect[:params][:digits] = digits if digits
      detect!(detect: detect, timeout: timeout)
    end

    def prepare_fax_arguments(tone)
      fax_events = [Relay::CallDetectState::CED, Relay::CallDetectState::CNG]
      events = [Relay::CallDetectState::FINISHED, Relay::CallDetectState::ERROR]
      detect = { type: Relay::CallDetectType::FAX, params: {} }

      if fax_events.include?(tone)
        detect[:params] = { tone: tone }
        events << tone
      else
        events = events + fax_events
      end

      [detect, events]
    end
  end
end