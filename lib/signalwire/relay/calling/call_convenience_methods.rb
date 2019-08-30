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

    def play_tts(text_p=nil, language_p=Relay::DEFAULT_LANGUAGE, gender_p=Relay::DEFAULT_GENDER, text: nil, language: Relay::DEFAULT_LANGUAGE, gender: Relay::DEFAULT_GENDER)
      set_parameters(binding, %i{text language gender}, %i{text})

      play tts_payload(text, language, gender)
    end

    def play_tts!(text_p=nil, language_p=Relay::DEFAULT_LANGUAGE, gender_p=Relay::DEFAULT_GENDER, text: nil, language: Relay::DEFAULT_LANGUAGE, gender: Relay::DEFAULT_GENDER)
      set_parameters(binding, %i{text language gender}, %i{text})
      play! tts_payload(text, language, gender)
    end

    def prompt_audio(collect_p = nil, url_p = nil, **args)
      collect = args.delete(:collect)
      url = args.delete(:url)
      collect = compile_collect_arguments(args) if collect.nil? && collect_p.nil?
      set_parameters(binding, %i{collect url}, %i{collect url})

      prompt(collect: collect, play: audio_payload(url))
    end

    def prompt_audio!(collect_p = nil, url_p = nil, **args)
      collect = args.delete(:collect)
      url = args.delete(:url)
      collect = compile_collect_arguments(args) if collect.nil? && collect_p.nil?
      set_parameters(binding, %i{collect url}, %i{collect url})

      prompt!(collect: collect, play: audio_payload(url))
    end

    def prompt_silence(collect_p = nil, duration_p = nil, **args)
      collect = args.delete(:collect)
      duration = args.delete(:duration)
      collect = compile_collect_arguments(args) if collect.nil? && collect_p.nil?
      set_parameters(binding, %i{collect duration}, %i{collect duration})

      prompt(collect: collect, play: silence_payload(duration))
    end

    def prompt_silence!(collect_p = nil, duration_p = nil, **args)
      collect = args.delete(:collect)
      duration = args.delete(:duration)
      collect = compile_collect_arguments(args) if collect.nil? && collect_p.nil?
      set_parameters(binding, %i{collect duration}, %i{collect duration})

      prompt!(collect: collect, play: silence_payload(duration))
    end

    def prompt_tts(collect_p = nil, text_p = nil, language_p=Relay::DEFAULT_LANGUAGE, gender_p=Relay::DEFAULT_GENDER, **args)
      collect = args.delete(:collect)
      text = args.delete(:text)
      language = args.delete(:language) || Relay::DEFAULT_LANGUAGE
      gender = args.delete(:gender) || Relay::DEFAULT_GENDER
      collect = compile_collect_arguments(args) if collect.nil? && collect_p.nil?

      set_parameters(binding, %i{collect text language gender}, %i{collect text})

      prompt(collect: collect, play: tts_payload(text, language, gender))
    end

    def prompt_tts!(collect_p = nil, text_p = nil, language_p=Relay::DEFAULT_LANGUAGE, gender_p=Relay::DEFAULT_GENDER, **args)
      collect = args.delete(:collect)
      text = args.delete(:text)
      language = args.delete(:language) || Relay::DEFAULT_LANGUAGE
      gender = args.delete(:gender) || Relay::DEFAULT_GENDER
      collect = compile_collect_arguments(args) if collect.nil? && collect_p.nil?

      set_parameters(binding, %i{collect text language gender}, %i{collect text})

      prompt!(collect: collect, play: tts_payload(text, language, gender))
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

    def tts_payload(text, language=Relay::DEFAULT_LANGUAGE, gender=Relay::DEFAULT_GENDER)
      [{ "type": 'tts', "params": { "text": text, "language": language, "gender": gender } }]
    end
  end
end