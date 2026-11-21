require "./spec_helper"
require "./support/recording_server"

describe "multilingual glossary dictionary updates" do
  [nil, "renamed glossary"].each do |name|
    it "patches dictionaries with optional name #{name.inspect}" do
      body = %({"glossary_id":"id","name":"updated","creation_time":"2026-01-01T00:00:00Z","dictionaries":[{"source_lang":"en","target_lang":"de","entry_count":1}]})
      server = RecordingServer.new([RecordingServer::ScriptedResponse.new(200, body)])
      begin
        dictionary = DeepL::GlossaryDictionary.new("en", "de", "hello\thallo")
        result = DeepL::Translator.new("test-key", nil, server.url)
          .patch_multilingual_glossary("id", name: name, dictionaries: [dictionary])
        result.glossary_id.should eq("id")
        request = server.requests.first
        request.method.should eq("PATCH")
        request.resource.should eq("/v3/glossaries/id")
        payload = JSON.parse(request.body)
        payload.as_h.has_key?("name").should eq(!name.nil?)
        payload["name"].as_s.should eq(name) if name
        payload["dictionaries"].as_a.size.should eq(1)
        actual = payload["dictionaries"][0]
        actual["source_lang"].as_s.should eq("en")
        actual["target_lang"].as_s.should eq("de")
        actual["entries"].as_s.should eq("hello\thallo")
        actual["entries_format"].as_s.should eq("tsv")
      ensure
        server.close
      end
    end
  end
end
