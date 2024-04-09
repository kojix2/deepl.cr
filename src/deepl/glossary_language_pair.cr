module DeepL
  class GlossaryLanguagePair
    include JSON::Serializable

    property source_lang : String
    property target_lang : String
  end
end
