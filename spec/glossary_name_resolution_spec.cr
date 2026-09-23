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

private def v2_glossary_record(id : String, name : String) : String
  %({"glossary_id":"#{id}","name":"#{name}","ready":true,"source_lang":"EN","target_lang":"DE","creation_time":"2025-01-01T00:00:00Z","entry_count":1})
end

private def v3_glossary_record(id : String, name : String) : String
  %({"glossary_id":"#{id}","name":"#{name}","dictionaries":[{"source_lang":"EN","target_lang":"DE","entry_count":1}],"creation_time":"2025-01-01T00:00:00Z"})
end

describe "glossary name resolution" do
  describe "v3 multilingual glossaries" do
    it "raises GlossaryNameNotFoundError when no glossary has the requested name" do
      with_glossary_name_server([] of String) do |server|
        translator = glossary_name_test_translator(server)

        expect_raises(DeepL::GlossaryNameNotFoundError) do
          translator.find_multilingual_glossary_by_name("missing")
        end

        server.requests.map(&.resource).should eq(["/v3/glossaries"])
      end
    end

    it "resolves a name when exactly one glossary matches" do
      with_glossary_name_server([v3_glossary_record("only-id", "only")]) do |server|
        glossary = glossary_name_test_translator(server).find_multilingual_glossary_by_name("only")

        glossary.glossary_id.should eq("only-id")
        server.requests.map(&.resource).should eq(["/v3/glossaries"])
      end
    end

    it "raises AmbiguousGlossaryNameError when multiple glossaries have the requested name" do
      duplicate_glossaries = [
        v3_glossary_record("first-id", "duplicate"),
        v3_glossary_record("second-id", "duplicate"),
      ]

      with_glossary_name_server(duplicate_glossaries) do |server|
        error = expect_raises(DeepL::AmbiguousGlossaryNameError) do
          glossary_name_test_translator(server).find_multilingual_glossary_by_name("duplicate")
        end

        error.message.should eq("Multiple glossaries with the name 'duplicate' were found. Use a glossary ID instead.")
        server.requests.map(&.resource).should eq(["/v3/glossaries"])
      end
    end

    it "keeps the name-based enumeration API available for duplicate names" do
      duplicate_glossaries = [
        v3_glossary_record("first-id", "duplicate"),
        v3_glossary_record("second-id", "duplicate"),
      ]

      with_glossary_name_server(duplicate_glossaries) do |server|
        glossaries = glossary_name_test_translator(server).get_multilingual_glossaries_by_name("duplicate")

        glossaries.map(&.glossary_id).should eq(["first-id", "second-id"])
        server.requests.map(&.resource).should eq(["/v3/glossaries"])
      end
    end
  end

  describe "v2 legacy glossaries" do
    it "resolves a name through the v2 endpoint" do
      with_glossary_name_server([v2_glossary_record("legacy-id", "legacy")]) do |server|
        glossary = glossary_name_test_translator(server).find_glossary_info_by_name("legacy")

        glossary.glossary_id.should eq("legacy-id")
        server.requests.map(&.resource).should eq(["/v2/glossaries"])
      end
    end

    it "keeps its ambiguous-name protection independent from v3" do
      duplicate_glossaries = [
        v2_glossary_record("first-id", "duplicate"),
        v2_glossary_record("second-id", "duplicate"),
      ]

      with_glossary_name_server(duplicate_glossaries) do |server|
        expect_raises(DeepL::AmbiguousGlossaryNameError) do
          glossary_name_test_translator(server).find_glossary_info_by_name("duplicate")
        end

        server.requests.map(&.resource).should eq(["/v2/glossaries"])
      end
    end
  end

  describe "glossary_name options" do
    it "rejects an ambiguous v3 glossary name before text translation" do
      duplicate_glossaries = [
        v3_glossary_record("first-id", "duplicate"),
        v3_glossary_record("second-id", "duplicate"),
      ]

      with_glossary_name_server(duplicate_glossaries) do |server|
        expect_raises(DeepL::AmbiguousGlossaryNameError) do
          glossary_name_test_translator(server).translate_text(
            "hello",
            "DE",
            glossary_name: "duplicate",
          )
        end

        server.requests.map(&.resource).should eq(["/v3/glossaries"])
      end
    end

    it "rejects an ambiguous v3 glossary name before document translation" do
      duplicate_glossaries = [
        v3_glossary_record("first-id", "duplicate"),
        v3_glossary_record("second-id", "duplicate"),
      ]

      with_glossary_name_server(duplicate_glossaries) do |server|
        expect_raises(DeepL::AmbiguousGlossaryNameError) do
          glossary_name_test_translator(server).translate_document(
            Path[__DIR__] / "fixtures" / "proton_beams.txt",
            "DE",
            glossary_name: "duplicate",
          )
        end

        server.requests.map(&.resource).should eq(["/v3/glossaries"])
      end
    end
  end
end
