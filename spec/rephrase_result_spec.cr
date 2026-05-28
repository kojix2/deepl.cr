require "./spec_helper"

describe DeepL::RephraseResult do
  it "can be initialized with detected_source_language and text" do
    detected_source_language = "en"
    text = "This is improved text."
    result = DeepL::RephraseResult.new(detected_source_language, text)

    result.detected_source_language.should eq(detected_source_language)
    result.text.should eq(text)
    result.target_language.should be_nil
  end

  it "can be deserialized with target language" do
    result = DeepL::RephraseResult.from_json(<<-JSON)
      {
        "detected_source_language": "en",
        "target_language": "en-US",
        "text": "This is improved text."
      }
      JSON

    result.target_language.should eq("en-US")
  end
end
