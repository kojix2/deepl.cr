require "./spec_helper"
require "./support/recording_server"

describe DeepL::VoiceStreamingResponse do
  it "can be deserialized from JSON" do
    json = <<-JSON
      {
        "streaming_url": "wss://api.deepl.com/v3/voice/realtime/connect",
        "token": "VGhpcyBpcyBhIGZha2UgdG9rZW4K",
        "session_id": "4f911080-cfe2-41d4-8269-0e6ec15a0354"
      }
      JSON

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

  it "sends Voice glossary IDs in priority order with a reporting tag" do
    server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(
        200,
        %({"streaming_url":"wss://example.test/connect","token":"token"}),
      ),
    ])

    begin
      translator = DeepL::Translator.new(auth_key: "test-key", server_url: server.url)
      translator.get_voice_streaming_url(
        source_media_content_type: "audio/ogg; codecs=opus",
        glossary_ids: ["highest-priority", "next-priority"],
        reporting_tag: "voice-team",
      ).token.should eq("token")

      request = server.requests.first
      request.resource.should eq("/v3/voice/realtime")
      JSON.parse(request.body)["glossary_ids"].as_a.map(&.as_s).should eq([
        "highest-priority",
        "next-priority",
      ])
      request.headers["X-DeepL-Reporting-Tag"].should eq("voice-team")
    ensure
      server.close
    end
  end

  it "validates Voice glossary IDs before creating a session" do
    translator = DeepL::Translator.new(auth_key: "dummy")

    expect_raises(ArgumentError, /glossary_id/) do
      translator.get_voice_streaming_url(
        source_media_content_type: "audio/ogg; codecs=opus",
        glossary_id: "legacy",
        glossary_ids: ["new"],
      )
    end
    expect_raises(ArgumentError, /duplicate/) do
      translator.get_voice_streaming_url(
        source_media_content_type: "audio/ogg; codecs=opus",
        glossary_ids: ["same", "same"],
      )
    end
  end
end
