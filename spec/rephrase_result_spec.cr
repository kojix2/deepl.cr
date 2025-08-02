require "./spec_helper"

describe DeepL::RephraseResult do
  it "can be initialized with detected_source_language and text" do
    detected_source_language = "en"
    text = "This is improved text."
    result = DeepL::RephraseResult.new(detected_source_language, text)

    result.detected_source_language.should eq(detected_source_language)
    result.text.should eq(text)
  end
end
