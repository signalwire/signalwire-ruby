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
      @component.execute_subcommand '.pause', Signalwire::Relay::Calling::PlayPauseResult
    end

    def pause
      @component.execute_subcommand '.resume', Signalwire::Relay::Calling::PlayResumeResult
    end
  end
end
