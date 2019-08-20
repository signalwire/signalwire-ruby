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

    def play_tts(sentence_p=nil, language_p=Relay::DEFAULT_LANGUAGE, gender_p=Relay::DEFAULT_GENDER, sentence: nil, language: Relay::DEFAULT_LANGUAGE, gender: Relay::DEFAULT_GENDER)
      set_parameters(binding, %i{sentence language gender}, %i{sentence})

      play tts_payload(sentence, language, gender)
    end

    def play_tts!(sentence_p=nil, language_p=Relay::DEFAULT_LANGUAGE, gender_p=Relay::DEFAULT_GENDER, sentence: nil, language: Relay::DEFAULT_LANGUAGE, gender: Relay::DEFAULT_GENDER)
      set_parameters(binding, %i{sentence language gender}, %i{sentence})
      play! tts_payload(sentence, language, gender)
    end

    def prompt_audio(collect_p = nil, url_p = nil, collect: nil, url: nil)
      set_parameters(binding, %i{collect url}, %i{collect url})

      prompt(collect, audio_payload(url))
    end

    def prompt_audio!(collect_p = nil, url_p = nil, collect: nil, url: nil)
      set_parameters(binding, %i{collect url}, %i{collect url})

      prompt!(collect, audio_payload(url))
    end

    def prompt_silence(collect_p = nil, duration_p = nil, collect: nil, duration: nil)
      set_parameters(binding, %i{collect duration}, %i{collect duration})

      prompt(collect, silence_payload(duration))
    end

    def prompt_silence!(collect_p = nil, duration_p = nil, collect: nil, duration: nil)
      set_parameters(binding, %i{collect duration}, %i{collect duration})

      prompt!(collect, silence_payload(duration))
    end

    def prompt_tts(collect_p = nil, sentence_p = nil, language_p=Relay::DEFAULT_LANGUAGE, gender_p=Relay::DEFAULT_GENDER, collect: nil, sentence: nil, language: Relay::DEFAULT_LANGUAGE, gender: Relay::DEFAULT_GENDER)
      set_parameters(binding, %i{collect sentence language gender}, %i{collect sentence})
      prompt(collect, tts_payload(sentence, language, gender))
    end

    def prompt_tts!(collect_p = nil, sentence_p = nil, language_p=Relay::DEFAULT_LANGUAGE, gender_p=Relay::DEFAULT_GENDER, collect: nil, sentence: nil, language: Relay::DEFAULT_LANGUAGE, gender: Relay::DEFAULT_GENDER)
      set_parameters(binding, %i{collect sentence language gender}, %i{collect sentence})

      prompt!(collect, tts_payload(sentence, language, gender))
    end

    def wait_for_ringing
      wait_for(Relay::CallState::RINGING)
    end

    def wait_for_answered
      wait_for(Relay::CallState::ANSWERED)
    end

    def wait_for_ending
      wait_for(Relay::CallState::ENDING)
    end

    def wait_for_ended
      wait_for(Relay::CallState::ENDED)
    end

    private 

    def audio_payload(url)
      [{ type: "audio", params: { url: url } }]
    end

    def silence_payload(duration)
      [{ type: "silence", params: { duration: duration } }]
    end

    def tts_payload(sentence, language=Relay::DEFAULT_LANGUAGE, gender=Relay::DEFAULT_GENDER)
      [{ "type": 'tts', "params": { "text": sentence, "language": language, "gender": gender } }]
    end
  end
end