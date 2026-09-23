require "./spec_helper"
require "./support/recording_server"

private def with_document_test_server(
  responses : Array(RecordingServer::ScriptedResponse),
  & : RecordingServer ->
) : Nil
  server = RecordingServer.new(responses)
  begin
    yield server
  ensure
    server.close
  end
end

private def document_test_translator(server : RecordingServer) : DeepL::Translator
  DeepL::Translator.new("document-test-key", nil, server.url)
end

private def document_test_handle : DeepL::DocumentHandle
  DeepL::DocumentHandle.new("document-id", "document-key")
end

private def document_status_response(status : String) : RecordingServer::ScriptedResponse
  RecordingServer::ScriptedResponse.new(
    200,
    body: %({"document_id":"document-id","status":"#{status}"}),
    headers: {"Content-Type" => "application/json"}
  )
end

private class DocumentTransportFailureServer
  getter url : String
  getter connections : Int32

  @listener : TCPServer

  def initialize
    @connections = 0
    @listener = TCPServer.new("127.0.0.1", 0)
    port = @listener.local_address.as(Socket::IPAddress).port
    @url = "http://127.0.0.1:#{port}"

    spawn do
      loop do
        socket = @listener.accept?
        break unless socket

        @connections += 1
        socket.close
      end
    rescue IO::Error
      # Closing the listener stops the accept loop.
    end
  end

  def close : Nil
    @listener.close unless @listener.closed?
  end
end

private def with_document_transport_failure_server(& : DocumentTransportFailureServer ->) : Nil
  server = DocumentTransportFailureServer.new
  begin
    yield server
  ensure
    server.close
  end
end

describe "document translation" do
  it "does not expose the document key in progress callbacks" do
    secret = "document-key-sentinel"
    responses = [
      RecordingServer::ScriptedResponse.new(
        200,
        body: %({"document_id":"document-id","document_key":"#{secret}"}),
        headers: {"Content-Type" => "application/json"}
      ),
      document_status_response("done"),
      RecordingServer::ScriptedResponse.new(200, "translated document"),
    ]
    output_file = File.tempname("deepl-document-spec", ".txt")

    with_document_test_server(responses) do |server|
      messages = [] of String
      begin
        document_test_translator(server).translate_document(
          Path[__DIR__] / "fixtures" / "proton_beams.txt",
          "DE",
          output_file: output_file,
          interval: 0.001
        ) { |message| messages << message }

        messages.join("\n").should_not contain(secret)
        File.read(output_file).should eq("translated document")
      ensure
        File.delete?(output_file)
      end
    end
  end

  it "polls for document status immediately" do
    with_document_test_server([document_status_response("done")]) do |server|
      started_at = Time.instant
      document_test_translator(server).translate_document_wait_until_done(document_test_handle, 1.0)

      (started_at.elapsed < 500.milliseconds).should be_true
      server.requests.map(&.resource).should eq(["/v2/document/document-id"])
    end
  end

  it "validates document polling interval and timeout" do
    translator = DeepL::Translator.new("document-test-key", nil, "http://127.0.0.1:1")
    handle = document_test_handle

    expect_raises(ArgumentError, /interval/) do
      translator.translate_document_wait_until_done(handle, 0)
    end
    expect_raises(ArgumentError, /timeout/) do
      translator.translate_document_wait_until_done(handle, 0.1, timeout: -1.second)
    end
  end

  it "validates polling options before uploading a document" do
    translator = DeepL::Translator.new("document-test-key", nil, "http://127.0.0.1:1")

    expect_raises(ArgumentError, /interval/) do
      translator.translate_document(
        Path[__DIR__] / "fixtures" / "proton_beams.txt",
        "DE",
        interval: 0
      )
    end
  end

  it "times out document polling after a bounded wait" do
    responses = Array.new(100) { document_status_response("translating") }

    with_document_test_server(responses) do |server|
      expect_raises(DeepL::DocumentTranslationError, /timed out/) do
        document_test_translator(server).translate_document_wait_until_done(
          document_test_handle,
          0.001,
          timeout: 20.milliseconds
        )
      end

      (server.requests.size > 0).should be_true
    end
  end

  [429, 503, 529].each do |status_code|
    it "retries transient status #{status_code} while polling" do
      responses = [
        RecordingServer::ScriptedResponse.new(status_code, "temporary failure"),
        document_status_response("done"),
      ]

      with_document_test_server(responses) do |server|
        document_test_translator(server).translate_document_wait_until_done(document_test_handle, 0.001)

        server.requests.size.should eq(2)
      end
    end
  end

  it "limits document status retries to two attempts" do
    responses = Array.new(3) { RecordingServer::ScriptedResponse.new(503, "temporary failure") }

    with_document_test_server(responses) do |server|
      expect_raises(DeepL::RequestError) do
        document_test_translator(server).translate_document_wait_until_done(document_test_handle, 0.001)
      end

      server.requests.size.should eq(3)
    end
  end

  it "retries transport errors only while polling" do
    with_document_transport_failure_server do |server|
      translator = DeepL::Translator.new("document-test-key", nil, server.url)

      expect_raises(DeepL::RequestError) do
        translator.translate_document_wait_until_done(document_test_handle, 0.001)
      end

      server.connections.should eq(3)
    end
  end

  it "does not retry a permanent document status failure" do
    with_document_test_server([RecordingServer::ScriptedResponse.new(400, "bad request")]) do |server|
      expect_raises(DeepL::RequestError) do
        document_test_translator(server).translate_document_wait_until_done(document_test_handle, 0.001)
      end

      server.requests.size.should eq(1)
    end
  end

  it "leaves an existing output file unchanged when download fails" do
    output_file = File.tempname("deepl-document-spec", ".txt")
    File.write(output_file, "existing output")

    with_document_test_server([RecordingServer::ScriptedResponse.new(500, "download failed")]) do |server|
      expect_raises(DeepL::RequestError) do
        document_test_translator(server).translate_document_download(document_test_handle, output_file)
      end

      File.read(output_file).should eq("existing output")
      server.requests.size.should eq(1)
    ensure
      File.delete?(output_file)
    end
  end

  it "does not create an output file when download fails" do
    output_file = File.tempname("deepl-document-spec", ".txt")

    with_document_test_server([RecordingServer::ScriptedResponse.new(500, "download failed")]) do |server|
      expect_raises(DeepL::RequestError) do
        document_test_translator(server).translate_document_download(document_test_handle, output_file)
      end

      File.exists?(output_file).should be_false
      server.requests.size.should eq(1)
    ensure
      File.delete?(output_file)
    end
  end
end
