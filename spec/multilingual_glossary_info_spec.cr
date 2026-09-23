require "./spec_helper"

describe DeepL::MultilingualGlossaryInfo do
  it "can be initialized with basic properties" do
    dictionaries = [
      DeepL::GlossaryDictionary.new("en", "de", "Hello\tHallo", "tsv", 1),
    ]
    creation_time = Time.utc
    glossary = DeepL::MultilingualGlossaryInfo.new(
      "test-id",
      "Test Glossary",
      dictionaries,
      creation_time
    )

    glossary.glossary_id.should eq("test-id")
    glossary.name.should eq("Test Glossary")
    glossary.dictionaries.size.should eq(1)
    glossary.creation_time.should eq(creation_time)
  end
end

describe DeepL::GlossaryDictionary do
  it "can be initialized with required properties" do
    dictionary = DeepL::GlossaryDictionary.new("en", "de")

    dictionary.source_lang.should eq("en")
    dictionary.target_lang.should eq("de")
    dictionary.entries.should be_nil
    dictionary.entries_format.should be_nil
    dictionary.entry_count.should be_nil
  end

  it "can be initialized with all properties" do
    creation_time = Time.utc
    dictionary = DeepL::GlossaryDictionary.new(
      "en", "de", "Hello\tHallo", "tsv", 1, creation_time
    )

    dictionary.source_lang.should eq("en")
    dictionary.target_lang.should eq("de")
    dictionary.entries.should eq("Hello\tHallo")
    dictionary.entries_format.should eq("tsv")
    dictionary.entry_count.should eq(1)
    dictionary.creation_time.should eq(creation_time)
  end
end

describe DeepL::GlossaryEntriesInformation do
  it "can be initialized with entry information" do
    info = DeepL::GlossaryEntriesInformation.new("en", "de", 5)

    info.source_lang.should eq("en")
    info.target_lang.should eq("de")
    info.entry_count.should eq(5)
  end
end
