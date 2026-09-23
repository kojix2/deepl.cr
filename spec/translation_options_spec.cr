require "json"
require "./spec_helper"
require "./support/recording_server"

private def with_translation_options_server(
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

private def translation_options_translator(server : RecordingServer) : DeepL::Translator
  DeepL::Translator.new("translation-options-test-key", nil, server.url)
end

private def translation_options_text_response : RecordingServer::ScriptedResponse
  RecordingServer::ScriptedResponse.new(
    200,
    %({"translations":[{"text":"Hallo","detected_source_language":"EN"}]}),
    {"Content-Type" => "application/json"}
  )
end

private def translation_options_document_response : RecordingServer::ScriptedResponse
  RecordingServer::ScriptedResponse.new(
    200,
    %({"document_id":"document-id","document_key":"document-key"}),
    {"Content-Type" => "application/json"}
  )
end

private def translation_options_document_status_response : RecordingServer::ScriptedResponse
  RecordingServer::ScriptedResponse.new(
    200,
    %({"document_id":"document-id","status":"done"}),
    {"Content-Type" => "application/json"}
  )
end

describe "translation options" do
  it "sends text glossary_ids as a JSON array" do
    with_translation_options_server([translation_options_text_response]) do |server|
      result = translation_options_translator(server).translate_text(
        "hello",
        "DE",
        "EN",
        glossary_ids: ["glossary-one", "glossary-two"],
      )

      result.first.text.should eq("Hallo")
      request = server.requests.first
      request.resource.should eq("/v2/translate")
      JSON.parse(request.body)["glossary_ids"].as_a.map(&.as_s).should eq(["glossary-one", "glossary-two"])
    end
  end

  it "sends document plural glossary IDs and document options as multipart fields" do
    responses = [
      translation_options_document_response,
      translation_options_document_status_response,
      RecordingServer::ScriptedResponse.new(200, "translated document"),
    ]
    output_file = File.tempname("deepl-translation-options", ".txt")

    with_translation_options_server(responses) do |server|
      translation_options_translator(server).translate_document(
        Path[__DIR__] / "fixtures" / "proton_beams.txt",
        "DE",
        "EN",
        glossary_ids: ["glossary-one", "glossary-two"],
        style_id: "style-id",
        translation_memory_id: "translation-memory-id",
        translation_memory_threshold: 75,
        output_file: output_file,
        interval: 0.001,
      ) { |_| }

      File.read(output_file).should eq("translated document")
      request = server.requests.first
      request.resource.should eq("/v2/document")
      request.body.should contain(%(name="glossary_ids"))
      request.body.should contain("glossary-one,glossary-two")
      request.body.should_not contain("glossary_ids[]")
      request.body.should contain(%(name="style_id"))
      request.body.should contain("style-id")
      request.body.should contain(%(name="translation_memory_id"))
      request.body.should contain("translation-memory-id")
      request.body.should contain(%(name="translation_memory_threshold"))
      request.body.should contain("75")
    ensure
      File.delete?(output_file)
    end
  end

  it "keeps document translation's existing positional options before appended options" do
    responses = [
      translation_options_document_response,
      translation_options_document_status_response,
      RecordingServer::ScriptedResponse.new(200, "translated document"),
    ]
    output_file = File.tempname("deepl-translation-options", ".txt")

    with_translation_options_server(responses) do |server|
      translation_options_translator(server).translate_document(
        Path[__DIR__] / "fixtures" / "proton_beams.txt",
        "DE",
        "EN",
        nil,
        nil,
        nil,
        "txt",
        output_file,
        "legacy-name.txt",
        0.001,
        "",
        nil,
      )

      File.read(output_file).should eq("translated document")
      request = server.requests.first
      request.body.should contain(%(name="output_format"))
      request.body.should contain("txt")
      request.body.should contain(%(name="filename"))
      request.body.should contain("legacy-name.txt")
    ensure
      File.delete?(output_file)
    end
  end

  it "validates text plural glossary constraints before sending a request" do
    translator = DeepL::Translator.new("translation-options-test-key", nil, "http://127.0.0.1:1")

    expect_raises(ArgumentError, /at most 5/) do
      translator.translate_text("hello", "DE", "EN", glossary_ids: ["1", "2", "3", "4", "5", "6"])
    end
    expect_raises(ArgumentError, /source_lang/) do
      translator.translate_text("hello", "DE", glossary_ids: ["glossary-id"])
    end
    expect_raises(ArgumentError, /glossary_id/) do
      translator.translate_text("hello", "DE", "EN", glossary_id: "glossary-id", glossary_ids: ["other-id"])
    end
    expect_raises(ArgumentError, /glossary_name/) do
      translator.translate_text("hello", "DE", "EN", glossary_name: "Glossary", glossary_ids: ["glossary-id"])
    end
  end

  it "validates document plural glossary constraints before uploading" do
    translator = DeepL::Translator.new("translation-options-test-key", nil, "http://127.0.0.1:1")
    path = Path[__DIR__] / "fixtures" / "proton_beams.txt"

    expect_raises(ArgumentError, /at most 5/) do
      translator.translate_document_upload(path, "DE", "EN", glossary_ids: ["1", "2", "3", "4", "5", "6"])
    end
    expect_raises(ArgumentError, /source_lang/) do
      translator.translate_document_upload(path, "DE", glossary_ids: ["glossary-id"])
    end
    expect_raises(ArgumentError, /glossary_id/) do
      translator.translate_document_upload(path, "DE", "EN", glossary_id: "glossary-id", glossary_ids: ["other-id"])
    end
    expect_raises(ArgumentError, /glossary_name/) do
      translator.translate_document_upload(path, "DE", "EN", glossary_name: "Glossary", glossary_ids: ["glossary-id"])
    end
  end
end
