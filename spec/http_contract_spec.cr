require "socket"
require "./spec_helper"
require "./support/recording_server"

describe "HTTP transport contracts" do
  it "routes text translation through v2" do
    server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(
        200,
        %({"translations":[{"text":"Hallo","detected_source_language":"EN"}]}),
      ),
    ])

    begin
      translator = DeepL::Translator.new(auth_key: "test-key", server_url: server.url)
      translator.translate_text("hello", "DE").first.text.should eq("Hallo")
      server.requests.map(&.resource).should eq(["/v2/translate"])
    ensure
      server.close
    end
  end

  it "treats mock as a normal API key" do
    server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(
        200,
        %({"translations":[{"text":"Hallo","detected_source_language":"EN"}]}),
      ),
    ])

    begin
      translator = DeepL::Translator.new(auth_key: "mock", server_url: server.url)
      translator.translate_text("hello", "DE").first.text.should eq("Hallo")
      server.requests.map(&.resource).should eq(["/v2/translate"])
    ensure
      server.close
    end
  end

  it "routes rephrase and correct through their distinct write endpoints" do
    responses = Array.new(2) do
      RecordingServer::ScriptedResponse.new(
        200,
        %({"improvements":[{"text":"proton beam","detected_source_language":"en","target_language":"en-US"}]}),
      )
    end
    server = RecordingServer.new(responses)

    begin
      translator = DeepL::Translator.new(auth_key: "test-key", server_url: server.url)
      translator.rephrase_text("input", "en").first.text.should eq("proton beam")
      translator.correct_text("input", "en").first.text.should eq("proton beam")
      server.requests.map(&.resource).should eq([
        "/v2/write/rephrase",
        "/v2/write/correct",
      ])
    ensure
      server.close
    end
  end

  it "replaces a custom trailing API version when routing text translation" do
    server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(
        200,
        %({"translations":[{"text":"Hallo","detected_source_language":"EN"}]}),
      ),
    ])

    begin
      translator = DeepL::Translator.new(
        auth_key: "test-key",
        server_url: "#{server.url}/proxy/v3/",
      )
      translator.translate_text("hello", "DE")
      server.requests.map(&.resource).should eq(["/proxy/v2/translate"])
    ensure
      server.close
    end
  end

  it "routes style rules through v3" do
    server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(200, %({"style_rules":[]})),
    ])

    begin
      translator = DeepL::Translator.new(auth_key: "test-key", server_url: server.url)
      translator.list_style_rule_lists.should be_empty
      server.requests.map(&.resource).should eq(["/v3/style_rules"])
    ensure
      server.close
    end
  end

  it "does not follow redirects for authenticated API requests" do
    server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(
        302,
        headers: {"Location" => "/redirect-target", "X-Trace-ID" => "trace-redirect"},
      ),
      RecordingServer::ScriptedResponse.new(
        200,
        %({"translations":[{"text":"should not be read","detected_source_language":"EN"}]}),
      ),
    ])

    begin
      translator = DeepL::Translator.new(auth_key: "test-key", server_url: server.url)
      error = expect_raises(DeepL::RequestError) do
        translator.translate_text("hello", "DE")
      end

      error.trace_id.should eq("trace-redirect")
      server.requests.map(&.resource).should eq(["/v2/translate"])
    ensure
      server.close
    end
  end

  it "accepts a 204 response for a v2 legacy glossary deletion" do
    server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(204),
    ])

    begin
      translator = DeepL::Translator.new(auth_key: "test-key", server_url: server.url)
      translator.delete_glossary("glossary-id").should be_true
      server.requests.map(&.resource).should eq(["/v2/glossaries/glossary-id"])
    ensure
      server.close
    end
  end

  it "accepts a 204 response for a v3 style rule deletion" do
    server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(204),
    ])

    begin
      translator = DeepL::Translator.new(auth_key: "test-key", server_url: server.url)
      translator.delete_style_rule_list("style-id").should be_nil
      server.requests.map(&.resource).should eq(["/v3/style_rules/style-id"])
    ensure
      server.close
    end
  end

  it "maps API errors, response bodies, and trace IDs" do
    server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(
        401,
        %({"message":"invalid key"}),
        {"X-Trace-ID" => "trace-401"},
      ),
      RecordingServer::ScriptedResponse.new(
        403,
        "forbidden by policy",
        {"X-Trace-ID" => "trace-403"},
      ),
      RecordingServer::ScriptedResponse.new(
        429,
        "",
        {"X-Trace-ID" => "trace-429"},
      ),
      RecordingServer::ScriptedResponse.new(
        456,
        %({"message":"quota exceeded"}),
        {"X-Trace-ID" => "trace-456"},
      ),
      RecordingServer::ScriptedResponse.new(
        500,
        %({"message":"JSON server failure"}),
        {"X-Trace-ID" => "trace-500-json"},
      ),
      RecordingServer::ScriptedResponse.new(
        500,
        %({"error":{"message":"nested JSON server failure"}}),
        {"X-Trace-ID" => "trace-500-nested-json"},
      ),
      RecordingServer::ScriptedResponse.new(
        500,
        "plain server failure",
        {"X-Trace-ID" => "trace-500-plain"},
      ),
      RecordingServer::ScriptedResponse.new(
        500,
        "",
        {"X-Trace-ID" => "trace-500-empty"},
      ),
    ])

    begin
      translator = DeepL::Translator.new(auth_key: "test-key", server_url: server.url)

      authorization_error = expect_raises(DeepL::AuthorizationError) do
        translator.translate_text("hello", "DE")
      end
      authorization_error.trace_id.should eq("trace-401")

      authorization_error = expect_raises(DeepL::AuthorizationError) do
        translator.translate_text("hello", "DE")
      end
      authorization_error.trace_id.should eq("trace-403")

      throttled_error = expect_raises(DeepL::TooManyRequestsError) do
        translator.translate_text("hello", "DE")
      end
      throttled_error.trace_id.should eq("trace-429")

      quota_error = expect_raises(DeepL::QuotaExceededError) do
        translator.translate_text("hello", "DE")
      end
      quota_error.trace_id.should eq("trace-456")

      request_error = expect_raises(DeepL::RequestError) do
        translator.translate_text("hello", "DE")
      end
      request_error.message.should eq("JSON server failure")
      request_error.trace_id.should eq("trace-500-json")

      request_error = expect_raises(DeepL::RequestError) do
        translator.translate_text("hello", "DE")
      end
      request_error.message.should eq("nested JSON server failure")
      request_error.trace_id.should eq("trace-500-nested-json")

      request_error = expect_raises(DeepL::RequestError) do
        translator.translate_text("hello", "DE")
      end
      request_error.message.should eq("plain server failure")
      request_error.trace_id.should eq("trace-500-plain")

      request_error = expect_raises(DeepL::RequestError) do
        translator.translate_text("hello", "DE")
      end
      request_error.message.should eq("Request failed")
      request_error.trace_id.should eq("trace-500-empty")
    ensure
      server.close
    end
  end

  it "wraps connection failures in DeepL::RequestError" do
    listener = TCPServer.new("127.0.0.1", 0)
    port = listener.local_address.as(Socket::IPAddress).port
    listener.close

    translator = DeepL::Translator.new(
      auth_key: "test-key",
      server_url: "http://127.0.0.1:#{port}",
    )
    error = expect_raises(DeepL::RequestError) do
      translator.translate_text("hello", "DE")
    end

    error.message.to_s.should_not be_empty
  end
end
