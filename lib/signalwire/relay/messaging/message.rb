# frozen_string_literal: true

module Signalwire::Relay::Messaging
  class Message < Signalwire::Relay::Event
    alias_method :blade_id, :id

    FIELDS =  %i{body message_id context tags 
                from_number to_number media 
                segments message_state}.freeze
    def message_params
      dig(:params, :params, :params)
    rescue StandardError
      {}
    end

    FIELDS.each do |meth|
      defined_method = case meth
      when :to_number
        :to
      when :from_number
        :from
      when :message_state
        :state
      when :message_id
        :id
      else
        meth
      end
      define_method(defined_method) { message_params[meth] }
    end
  end
end