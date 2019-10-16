# frozen_string_literal: true

require 'forwardable'

module Signalwire::Relay::Calling
  class PlayAction < Action
    def result
      PlayResult.new(@component)
    end

    def stop
      @component.stop
    end

    def pause
      @component.pause
    end

    def resume
      @component.resume
    end

    def volume(setting)
      @component.volume setting
    end
  end
end
