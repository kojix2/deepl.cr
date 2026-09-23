require "./spec_helper"
require "./support/recording_server"

private def with_glossary_name_server(
  glossaries : Array(String),
  & : RecordingServer ->
) : Nil
  response = RecordingServer::ScriptedResponse.new(
    200,
    %({"glossaries":[#{glossaries.join(",")}]}),
    {"Content-Type" => "application/json"},
  )
  server = RecordingServer.new([response])
  begin
    yield server
  ensure
    server.close
  end
end

private def glossary_name_test_translator(server : RecordingServer) : DeepL::Translator
  DeepL::Translator.new(auth_key: "test-key", server_url: server.url)
end

private def glossary_record(id : String, name : String) : String
  {% if flag?(:deepl_v2) || env("DEEPL_API_VERSION") == "v2" %}
    %({"glossary_id":"#{id}","name":"#{name}","ready":true,"source_lang":"EN","target_lang":"DE","creation_time":"2025-01-01T00:00:00Z","entry_count":1})
  {% else %}
    %({"glossary_id":"#{id}","name":"#{name}","dictionaries":[{"source_lang":"EN","target_lang":"DE","entry_count":1}],"creation_time":"2025-01-01T00:00:00Z"})
  {% end %}
end

private def glossary_list_path : String
  {% if flag?(:deepl_v2) || env("DEEPL_API_VERSION") == "v2" %}
    "/v2/glossaries"
  {% else %}
    "/v3/glossaries"
  {% end %}
end

private def resolve_glossary_name(translator : DeepL::Translator, name : String)
  {% if flag?(:deepl_v2) || env("DEEPL_API_VERSION") == "v2" %}
    translator.find_glossary_info_by_name(name)
  {% else %}
    translator.find_multilingual_glossary_by_name(name)
  {% end %}
end

private def glossaries_named(translator : DeepL::Translator, name : String)
  {% if flag?(:deepl_v2) || env("DEEPL_API_VERSION") == "v2" %}
    translator.get_glossary_info_by_name(name)
  {% else %}
    translator.get_multilingual_glossaries_by_name(name)
  {% end %}
end

describe "glossary name resolution" do
  it "raises GlossaryNameNotFoundError when no glossary has the requested name" do
    with_glossary_name_server([] of String) do |server|
      translator = glossary_name_test_translator(server)

      expect_raises(DeepL::GlossaryNameNotFoundError) do
        resolve_glossary_name(translator, "missing")
      end

      server.requests.map(&.resource).should eq([glossary_list_path])
    end
  end

  it "resolves a name when exactly one glossary matches" do
    with_glossary_name_server([glossary_record("only-id", "only")]) do |server|
      glossary = resolve_glossary_name(glossary_name_test_translator(server), "only")

      glossary.glossary_id.should eq("only-id")
      server.requests.map(&.resource).should eq([glossary_list_path])
    end
  end

  it "raises AmbiguousGlossaryNameError when multiple glossaries have the requested name" do
    duplicate_glossaries = [
      glossary_record("first-id", "duplicate"),
      glossary_record("second-id", "duplicate"),
    ]

    with_glossary_name_server(duplicate_glossaries) do |server|
      error = expect_raises(DeepL::AmbiguousGlossaryNameError) do
        resolve_glossary_name(glossary_name_test_translator(server), "duplicate")
      end

      error.message.should eq("Multiple glossaries with the name 'duplicate' were found. Use a glossary ID instead.")
      server.requests.map(&.resource).should eq([glossary_list_path])
    end
  end

  it "keeps the name-based enumeration API available for duplicate names" do
    duplicate_glossaries = [
      glossary_record("first-id", "duplicate"),
      glossary_record("second-id", "duplicate"),
    ]

    with_glossary_name_server(duplicate_glossaries) do |server|
      glossaries = glossaries_named(glossary_name_test_translator(server), "duplicate")

      glossaries.map(&.glossary_id).should eq(["first-id", "second-id"])
      server.requests.map(&.resource).should eq([glossary_list_path])
    end
  end

  it "rejects an ambiguous glossary name before text translation" do
    duplicate_glossaries = [
      glossary_record("first-id", "duplicate"),
      glossary_record("second-id", "duplicate"),
    ]

    with_glossary_name_server(duplicate_glossaries) do |server|
      expect_raises(DeepL::AmbiguousGlossaryNameError) do
        glossary_name_test_translator(server).translate_text(
          "hello",
          "DE",
          glossary_name: "duplicate",
        )
      end

      server.requests.map(&.resource).should eq([glossary_list_path])
    end
  end

  it "rejects an ambiguous glossary name before document translation" do
    duplicate_glossaries = [
      glossary_record("first-id", "duplicate"),
      glossary_record("second-id", "duplicate"),
    ]

    with_glossary_name_server(duplicate_glossaries) do |server|
      expect_raises(DeepL::AmbiguousGlossaryNameError) do
        glossary_name_test_translator(server).translate_document(
          Path[__DIR__] / "fixtures" / "proton_beams.txt",
          "DE",
          glossary_name: "duplicate",
        )
      end

      server.requests.map(&.resource).should eq([glossary_list_path])
    end
  end
end
