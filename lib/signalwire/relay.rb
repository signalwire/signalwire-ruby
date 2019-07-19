# frozen_string_literal: true

module Signalwire::Relay
end

require 'signalwire/relay/constants'
require 'signalwire/relay/client'
require 'signalwire/relay/request'
require 'signalwire/relay/event'
require 'signalwire/relay/consumer'

require 'signalwire/relay/calling'
require 'signalwire/relay/calling/call_convenience_methods'
require 'signalwire/relay/calling/call'

require 'signalwire/relay/task'

require 'signalwire/relay/calling/action'
require 'signalwire/relay/calling/action/connect_action'
require 'signalwire/relay/calling/action/play_action'
require 'signalwire/relay/calling/action/prompt_action'
require 'signalwire/relay/calling/action/record_action'
require 'signalwire/relay/calling/action/fax_action'

require 'signalwire/relay/calling/result'
require 'signalwire/relay/calling/result/answer_result'
require 'signalwire/relay/calling/result/connect_result'
require 'signalwire/relay/calling/result/dial_result'
require 'signalwire/relay/calling/result/hangup_result'
require 'signalwire/relay/calling/result/play_result'
require 'signalwire/relay/calling/result/prompt_result'
require 'signalwire/relay/calling/result/record_result'
require 'signalwire/relay/calling/result/fax_result'

require 'signalwire/relay/calling/component'
require 'signalwire/relay/calling/control_component'
require 'signalwire/relay/calling/component/answer'
require 'signalwire/relay/calling/component/connect'
require 'signalwire/relay/calling/component/dial'
require 'signalwire/relay/calling/component/hangup'
require 'signalwire/relay/calling/component/play'
require 'signalwire/relay/calling/component/prompt'
require 'signalwire/relay/calling/component/record'
require 'signalwire/relay/calling/component/await'
require 'signalwire/relay/calling/component/base_fax'
require 'signalwire/relay/calling/component/fax_send'
require 'signalwire/relay/calling/component/fax_receive'
