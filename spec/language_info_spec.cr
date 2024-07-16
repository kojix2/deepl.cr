require "./spec_helper"

describe DeepL::LanguageInfo do
  it "can be serialized to JSON" do
    info = DeepL::LanguageInfo.new("en", "English", true)
    json = info.to_json
    json.should eq(%({"language":"en","name":"English","supports_formality":true}))
  end

  it "can be deserialized from JSON" do
    json = %({"language":"en","name":"English","supports_formality":true})
    info = DeepL::LanguageInfo.from_json(json)
    info.language.should eq("en")
    info.name.should eq("English")
    info.supports_formality.should eq(true)
    info.to_json.should eq(json)
  end
end
