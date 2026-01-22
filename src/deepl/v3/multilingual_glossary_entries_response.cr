module DeepL
  class MultilingualGlossaryEntriesResponse
    include JSON::Serializable

    property dictionaries : Array(GlossaryDictionary)

    def initialize(@dictionaries)
    end
  end
end
