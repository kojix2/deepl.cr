module DeepL
  class GlossaryEntriesInformation
    include JSON::Serializable

    property source_lang : String
    property target_lang : String
    property entry_count : Int32

    def initialize(@source_lang, @target_lang, @entry_count)
    end
  end

  class GlossaryEntriesResponse
    include JSON::Serializable

    property dictionaries : Array(GlossaryEntriesInformation)

    def initialize(@dictionaries)
    end
  end
end
