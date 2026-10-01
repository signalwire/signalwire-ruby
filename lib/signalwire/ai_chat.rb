# frozen_string_literal: true

# Copyright (c) 2026 SignalWire
#
# This file is part of the SignalWire SDK.
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

# Public entry point for the SignalWire AI Chat client:
#
#   require 'signalwire/ai_chat'
#   client = SignalWire::AIChatClient.new(space: 'myspace')
#
# Loads the client, its typed error family (SignalWire::AIChat::AIChatError and
# subclasses), its response models (ConversationInfo/ChatResponse/ChatLog), and
# the browser-facing half: SignalWire::AIChat::ChatGateway (with its
# GatewayRejection) and SignalWire::AIChat::HandoffRouter (with its NonceEntry).
require_relative 'ai_chat/client'
require_relative 'ai_chat/gateway'
require_relative 'ai_chat/handoff'
