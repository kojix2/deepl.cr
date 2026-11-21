require "./spec_helper"
require "./support/recording_server"

describe "multilingual glossary entry language pairs" do
  it "finds the requested pair regardless of case or response ordering" do
    body = %({"dictionaries":[{"source_lang":"en","target_lang":"ja","entries":"wrong"},{"source_lang":"de","target_lang":"FR","entries":"richtig\\tcorrect"}]})
    server = RecordingServer.new([RecordingServer::ScriptedResponse.new(200, body)])
    begin
      result = DeepL::Translator.new("test-key", nil, server.url)
        .get_multilingual_glossary_entries("id", "DE", "fr")
      result.entries.should eq("richtig\tcorrect")
    ensure
      server.close
    end
  end

  ["[]", %([{"source_lang":"en","target_lang":"ja","entries":"wrong"}])].each do |dictionaries|
    it "rejects an absent pair in #{dictionaries}" do
      server = RecordingServer.new([
        RecordingServer::ScriptedResponse.new(200, %({"dictionaries":#{dictionaries}}), {"X-Trace-ID" => "pair-trace"}),
      ])
      begin
        error = expect_raises(DeepL::RequestError, /de -> fr/) do
          DeepL::Translator.new("test-key", nil, server.url).get_multilingual_glossary_entries("id", "de", "fr")
        end
        error.trace_id.should eq("pair-trace")
      ensure
        server.close
      end
    end
  end
end
