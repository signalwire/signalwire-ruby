module Signalwire::Relay::Calling
  module CallConvenienceMethods
    def play_audio(url)
      play audio_payload(url)
    end

    def play_audio!(url)
      play! audio_payload(url)
    end

    def play_silence(duration)
      play silence_payload(duration)
    end

    def play_silence!(duration)
      play! silence_payload(duration)
    end

    def play_tts(sentence, language='en-US', gender='male')
      play tts_payload(sentence, language, gender)
    end

    def play_tts!(sentence, language='en-US', gender='male')
      play! tts_payload(sentence, language, gender)
    end

    def prompt_audio(collect, url)
      prompt(collect, audio_payload(url))
    end

    def prompt_audio!(collect, url)
      prompt!(collect, audio_payload(url))
    end

    def prompt_silence(collect, duration)
      prompt(collect, silence_payload(duration))
    end

    def prompt_silence!(collect, url)
      prompt!(collect, silence_payload(duration))
    end

    def prompt_tts(collect, language='en-US', gender='male')
      prompt(collect, tts_payload(sentence, language, gender))
    end

    def prompt_tts!(collect, language='en-US', gender='male')
      prompt!(collect, tts_payload(sentence, language, gender))
    end

    def audio_payload(url)
      [{ type: "audio", params: { url: url } }]
    end

    def silence_payload(duration)
      [{ type: "silence", params: { duration: duration } }]
    end

    def tts_payload(sentence, language='en-US', gender='male')
      [{ "type": 'tts', "params": { "text": sentence, "language": language, "gender": gender } }]
    end
  end
end