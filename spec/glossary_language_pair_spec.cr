require "./spec_helper"

describe DeepL::GlossaryLanguagePair do
  it "can be serialized to JSON" do
    pair = DeepL::GlossaryLanguagePair.new("en", "fr")
    json = pair.to_json
    json.should eq(%({"source_lang":"en","target_lang":"fr"}))
  end

  it "can be deserialized from JSON" do
    json = %({"source_lang":"en","target_lang":"fr"})
    pair = DeepL::GlossaryLanguagePair.from_json(json)
    pair.source_lang.should eq("en")
    pair.target_lang.should eq("fr")
  end
end
