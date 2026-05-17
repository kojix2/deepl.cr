require "./spec_helper"

{% unless flag?(:deepl_v2) %}
  describe DeepL::VoiceStreamingResponse do
    it "can be deserialized from JSON" do
      json = %({
        "streaming_url": "wss://api.deepl.com/v3/voice/realtime/connect",
        "token": "VGhpcyBpcyBhIGZha2UgdG9rZW4K",
        "session_id": "4f911080-cfe2-41d4-8269-0e6ec15a0354"
      })

      response = DeepL::VoiceStreamingResponse.from_json(json)

      response.streaming_url.should eq("wss://api.deepl.com/v3/voice/realtime/connect")
      response.token.should eq("VGhpcyBpcyBhIGZha2UgdG9rZW4K")
      response.session_id.should eq("4f911080-cfe2-41d4-8269-0e6ec15a0354")
    end

    it "can be initialized without session id" do
      response = DeepL::VoiceStreamingResponse.new(
        "wss://api.deepl.com/v3/voice/realtime/connect",
        "VGhpcyBpcyBhIGZha2UgdG9rZW4K"
      )

      response.streaming_url.should eq("wss://api.deepl.com/v3/voice/realtime/connect")
      response.token.should eq("VGhpcyBpcyBhIGZha2UgdG9rZW4K")
      response.session_id.should be_nil
    end
  end

  describe DeepL::Translator do
    it "exposes voice realtime API methods" do
      translator = DeepL::Translator.new(auth_key: "dummy")

      translator.responds_to?(:get_voice_streaming_url).should be_true
      translator.responds_to?(:request_reconnection).should be_true
    end
  end
{% end %}
