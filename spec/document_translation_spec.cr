require "./spec_helper"
require "./support/recording_server"
require "./support/raw_http_server"
require "file_utils"

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

private class FailingDocumentSaveTranslator < DeepL::Translator
  private def finalize_document_result(temporary_path : String, output_path : Path) : Nil
    raise File::Error.new("simulated rename failure", file: output_path)
  end
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
  it "does not overwrite existing automatically named translations" do
    dir = File.tempname("deepl-document-spec")
    Dir.mkdir(dir, 0o700)
    begin
      input = Path[dir] / "input.txt"
      File.write(input, "source")
      File.write(Path[dir] / "input_DE.txt", "existing")
      responses = [] of RecordingServer::ScriptedResponse
      3.times do
        responses << RecordingServer::ScriptedResponse.new(200, %({"document_id":"id","document_key":"key"}))
        responses << document_status_response("done")
        responses << RecordingServer::ScriptedResponse.new(200, "translated")
      end
      with_document_test_server(responses) do |server|
        translator = document_test_translator(server)
        3.times { translator.translate_document(input, "DE", interval: 0.001) }
      end
      File.read(Path[dir] / "input_DE.txt").should eq("existing")
      outputs = Dir.children(dir).select(&.starts_with?("input_DE_"))
      outputs.size.should eq(3)
      outputs.each { |name| File.read(Path[dir] / name).should eq("translated") }
    ensure
      FileUtils.rm_r(dir)
    end
  end

  it "checks the output directory before requesting the one-time download" do
    with_document_test_server([] of RecordingServer::ScriptedResponse) do |server|
      missing = Path[File.tempname("deepl-missing-directory")] / "output.txt"
      expect_raises(File::Error) do
        document_test_translator(server).translate_document_download(document_test_handle, missing)
      end
      server.requests.should be_empty
    end
  end

  it "rejects a directory as the download destination without making a request" do
    with_document_test_server([] of RecordingServer::ScriptedResponse) do |server|
      expect_raises(ArgumentError, /directory/) do
        document_test_translator(server).translate_document_download(document_test_handle, Dir.tempdir)
      end
      server.requests.should be_empty
    end
  end

  it "preserves a partial response when the download connection closes early" do
    server = RawHTTPServer.new do |socket|
      socket << "HTTP/1.1 200 OK\r\nContent-Length: 1000\r\n\r\npartial translation"
      socket.flush
    end
    output = File.tempname("deepl-document-partial")
    begin
      error = expect_raises(DeepL::DocumentDownloadError) do
        DeepL::Translator.new("test-key", nil, server.url).translate_document_download(document_test_handle, output)
      end
      File.read(error.recovery_path).should eq("partial translation")
      error.message.to_s.should contain(error.recovery_path)
      File.exists?(output).should be_false
      server.requests.should eq(1)
    ensure
      server.close
      File.delete?(error.recovery_path) if error
      File.delete?(output)
    end
  end

  it "streams multipart document uploads with the original fields and file content" do
    source = File.tempfile("deepl-upload", ".txt")
    content = "document contents\n" * 100_000
    source.print(content)
    source.close
    responses = [RecordingServer::ScriptedResponse.new(200, %({"document_id":"id","document_key":"key"}))]
    with_document_test_server(responses) do |server|
      document_test_translator(server).translate_document_upload(source.path, "DE", source_lang: "EN")
      request = server.requests.first
      request.headers["Transfer-Encoding"].should eq("chunked")
      request.headers.has_key?("Content-Length").should be_false
      request.body.should contain("name=\"target_lang\"\r\n\r\nDE\r\n")
      request.body.should contain("name=\"source_lang\"\r\n\r\nEN\r\n")
      request.body.should contain(content)
    end
  ensure
    File.delete?(source.path) if source
  end

  [false, true].each do |with_progress|
    it "exposes the handle before polling fails (progress callback: #{with_progress})" do
      responses = [RecordingServer::ScriptedResponse.new(200, %({"document_id":"id","document_key":"key"}))]
      with_document_test_server(responses) do |server|
        handles = [] of DeepL::DocumentHandle
        uploaded = ->(handle : DeepL::DocumentHandle) { handles << handle; nil }
        translator = document_test_translator(server)
        source = Path[__DIR__] / "fixtures" / "proton_beams.txt"
        expect_raises(DeepL::DocumentTranslationError, /timed out/) do
          if with_progress
            translator.translate_document(source, "DE", timeout: Time::Span.zero, on_uploaded: uploaded) { |_message| }
          else
            translator.translate_document(source, "DE", timeout: Time::Span.zero, on_uploaded: uploaded)
          end
        end
        handles.size.should eq(1)
        handles.first.id.should eq("id")
        handles.first.key.should eq("key")
        server.requests.size.should eq(1)
      end
    end
  end

  it "finishes a streaming upload's producer when the connection fails" do
    source = File.tempfile("deepl-upload-failure", ".txt")
    source.print("large document\n" * 100_000)
    source.close
    with_document_transport_failure_server do |server|
      translator = DeepL::Translator.new("test-key", nil, server.url)
      expect_raises(DeepL::RequestError) do
        translator.translate_document_upload(source.path, "DE")
      end
      server.connections.should eq(1)
      # Let any multipart writer finish; it must not read a closed source file.
      Fiber.yield
    end
  ensure
    File.delete?(source.path) if source
  end

  it "exposes the uploaded handle while retaining the original polling exception type" do
    responses = [
      RecordingServer::ScriptedResponse.new(200, %({"document_id":"id","document_key":"key"})),
      RecordingServer::ScriptedResponse.new(400, "invalid status request"),
    ]
    with_document_test_server(responses) do |server|
      handle : DeepL::DocumentHandle? = nil
      on_uploaded = ->(uploaded : DeepL::DocumentHandle) { handle = uploaded; nil }
      expect_raises(DeepL::RequestError) do
        document_test_translator(server).translate_document(
          Path[__DIR__] / "fixtures" / "proton_beams.txt", "DE", on_uploaded: on_uploaded)
      end
      handle.try(&.key).should eq("key")
      server.requests.size.should eq(2)
    end
  end

  it "preserves downloaded data when the final move fails" do
    with_document_test_server([RecordingServer::ScriptedResponse.new(200, "translated document")]) do |server|
      translator = FailingDocumentSaveTranslator.new("test-key", nil, server.url)
      output = File.tempname("deepl-output")
      error = expect_raises(DeepL::DocumentDownloadError) do
        translator.translate_document_download(document_test_handle, output)
      end
      begin
        File.read(error.recovery_path).should eq("translated document")
        File.exists?(output).should be_false
      ensure
        File.delete?(error.recovery_path)
        File.delete?(output)
      end
    end
  end

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
    [Float64::INFINITY, Float64::NAN].each do |interval|
      expect_raises(ArgumentError, /interval/) do
        translator.translate_document_wait_until_done(handle, interval)
      end
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
