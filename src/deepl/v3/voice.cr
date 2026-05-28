require "./voice_streaming_response"

module DeepL
  class Translator
    def get_voice_streaming_url(
      source_media_content_type : String,
      source_language : String? = nil,
      source_language_mode : String? = nil,
      target_languages : Array(String)? = nil,
      message_format : String? = nil,
      target_media_languages : Array(String)? = nil,
      target_media_content_type : String? = nil,
      target_media_voice : String? = nil,
      spoken_terms_id : String? = nil,
      glossary_id : String? = nil,
      formality : String? = nil,
    ) : VoiceStreamingResponse
      url = "#{base_server_url}/v3/voice/realtime"
      data = {
        "source_media_content_type" => source_media_content_type,
        "source_language"           => source_language,
        "source_language_mode"      => source_language_mode,
        "target_languages"          => target_languages,
        "message_format"            => message_format,
        "target_media_languages"    => target_media_languages,
        "target_media_content_type" => target_media_content_type,
        "target_media_voice"        => target_media_voice,
        "spoken_terms_id"           => spoken_terms_id,
        "glossary_id"               => glossary_id,
        "formality"                 => formality,
      }.compact!

      response = Crest.post(url, form: data, json: true, headers: http_headers_json)
      handle_response(response)
      VoiceStreamingResponse.from_json(response.body)
    end

    def request_reconnection(token : String) : VoiceStreamingResponse
      url = "#{base_server_url}/v3/voice/realtime"
      params = {"token" => token}

      response = Crest.get(url, params: params, headers: http_headers_base)
      handle_response(response)
      VoiceStreamingResponse.from_json(response.body)
    end
  end
end
