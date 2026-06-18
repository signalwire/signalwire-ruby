# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # REST call control -- all 37 commands dispatched via single POST endpoint.
      class CallingNamespace < BaseResource
        def initialize(http)
          super(http, '/api/calling/calls')
        end

        # Call lifecycle
        def dial(**params)       = _execute('dial', **params)
        def update(**params)     = _execute('update', **params)

        def end_call(call_id, **params) = _execute('calling.end', call_id: call_id, **params)
        def transfer(call_id, **params) = _execute('calling.transfer', call_id: call_id, **params)
        def disconnect(call_id, **params) = _execute('calling.disconnect', call_id: call_id, **params)

        # Play
        def play(call_id, **params) = _execute('calling.play', call_id: call_id, **params)
        def play_pause(call_id, **params) = _execute('calling.play.pause', call_id: call_id, **params)
        def play_resume(call_id, **params) = _execute('calling.play.resume', call_id: call_id, **params)
        def play_stop(call_id, **params) = _execute('calling.play.stop', call_id: call_id, **params)
        def play_volume(call_id, **params) = _execute('calling.play.volume', call_id: call_id, **params)

        # Record
        def record(call_id, **params) = _execute('calling.record', call_id: call_id, **params)
        def record_pause(call_id, **params) = _execute('calling.record.pause', call_id: call_id, **params)
        def record_resume(call_id, **params) = _execute('calling.record.resume', call_id: call_id, **params)
        def record_stop(call_id, **params) = _execute('calling.record.stop', call_id: call_id, **params)

        # Collect
        def collect(call_id, **params) = _execute('calling.collect', call_id: call_id, **params)
        def collect_stop(call_id, **params) = _execute('calling.collect.stop', call_id: call_id, **params)

        def collect_start_input_timers(call_id, **params)
          _execute('calling.collect.start_input_timers', call_id: call_id, **params)
        end

        # Detect
        def detect(call_id, **params) = _execute('calling.detect', call_id: call_id, **params)
        def detect_stop(call_id, **params) = _execute('calling.detect.stop', call_id: call_id, **params)

        # Tap
        def tap(call_id, **params) = _execute('calling.tap', call_id: call_id, **params)
        def tap_stop(call_id, **params) = _execute('calling.tap.stop', call_id: call_id, **params)

        # Stream
        def stream(call_id, **params) = _execute('calling.stream', call_id: call_id, **params)
        def stream_stop(call_id, **params) = _execute('calling.stream.stop', call_id: call_id, **params)

        # Denoise
        def denoise(call_id, **params) = _execute('calling.denoise', call_id: call_id, **params)
        def denoise_stop(call_id, **params) = _execute('calling.denoise.stop', call_id: call_id, **params)

        # Transcribe
        def transcribe(call_id, **params) = _execute('calling.transcribe', call_id: call_id, **params)
        def transcribe_stop(call_id, **params) = _execute('calling.transcribe.stop', call_id: call_id, **params)

        # AI
        def ai_message(call_id, **params) = _execute('calling.ai_message', call_id: call_id, **params)
        def ai_hold(call_id, **params) = _execute('calling.ai_hold', call_id: call_id, **params)
        def ai_unhold(call_id, **params) = _execute('calling.ai_unhold', call_id: call_id, **params)
        def ai_stop(call_id, **params) = _execute('calling.ai.stop', call_id: call_id, **params)

        # Live transcribe / translate
        def live_transcribe(call_id, **params) = _execute('calling.live_transcribe', call_id: call_id, **params)
        def live_translate(call_id, **params) = _execute('calling.live_translate', call_id: call_id, **params)

        # Fax
        def send_fax_stop(call_id, **params) = _execute('calling.send_fax.stop', call_id: call_id, **params)
        def receive_fax_stop(call_id, **params) = _execute('calling.receive_fax.stop', call_id: call_id, **params)

        # SIP
        def refer(call_id, **params) = _execute('calling.refer', call_id: call_id, **params)

        # Custom events
        def user_event(call_id, **params) = _execute('calling.user_event', call_id: call_id, **params)

        private

        def _execute(command, call_id: nil, **params)
          body = { 'command' => command, 'params' => params.transform_keys(&:to_s) }
          body['id'] = call_id if call_id
          @http.post(@base_path, body)
        end
      end
    end
  end
end
