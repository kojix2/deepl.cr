module DeepL
  class VoiceStreamingResponse
    include JSON::Serializable

    property streaming_url : String
    property token : String
    property session_id : String?

    def initialize(@streaming_url, @token, @session_id = nil)
    end
  end
end
