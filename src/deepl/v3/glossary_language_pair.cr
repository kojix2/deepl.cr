module DeepL
  class GlossaryLanguagePair
    include JSON::Serializable

    property source_lang : String
    property target_lang : String

    def initialize(@source_lang, @target_lang)
    end
  end
end
