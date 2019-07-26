# frozen_string_literal: true

module Signalwire::Relay::Messaging
  class Message < Signalwire::Relay::Event
    FIELDS =  %i{body message_id context tags 
                from_number to_number media 
                segments message_state}.freeze
    def message_params
      dig(:params, :params, :params)
    rescue StandardError
      {}
    end

    FIELDS.each do |meth|
      define_method(meth) { message_params[meth] }
    end
  end
end