require "./spec_helper"

describe DeepL::TextResult do
  it "can be initialized with text and detected source language" do
    text = "Hello, world!"
    detected_source_language = "en"
    billed_characters = 13
    result = DeepL::TextResult.new(text, detected_source_language, billed_characters, nil)

    result.text.should eq(text)
    result.detected_source_language.should eq(detected_source_language)
    result.billed_characters.should eq(billed_characters)
  end
end
