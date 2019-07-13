# frozen_string_literal: true

module Signalwire::Relay::Calling
  class Prompt < ControlComponent
    attr_reader :type, :input, :terminator
    def initialize(call:, collect:, play:)
      super(call: call)
      @play = play
      @collect = collect
    end

    def method
      Relay::ComponentMethod::PROMPT
    end

    def event_type
      Relay::CallNotification::COLLECT
    end

    def inner_params
      {
        node_id: @call.node_id,
        call_id: @call.id,
        control_id: control_id,
        play: @play,
        collect: @collect
      }
    end

    def notification_handler(event)
      @completed = true
      result = event.call_params[:result]
      @type = result[:type]
      @state = @type

      if @type == Relay::CallPromptState::DIGIT
        digit_event(result)
      elsif type == Relay::CallPromptState::SPEECH
        speech_event(result)
      else
        @state = @type
        @successful = false
      end

      check_for_waiting_events
    end

  private

    def digit_event(result)
      @successful = true
      @input = result.dig(:params, :digits)
      @terminator = result.dig(:params, :terminator)
    end

    def speech_event(result)
      @successful = true
      @input = result.dig(:params, :text)
      @confidence = result.dig(:params, :confidence)
    end
  end
end
