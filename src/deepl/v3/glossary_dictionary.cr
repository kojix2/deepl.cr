module DeepL
  class GlossaryDictionary
    include JSON::Serializable

    property source_lang : String
    property target_lang : String
    property entries : String?
    property entries_format : String?
    property entry_count : Int32?
    property creation_time : Time?

    def initialize(@source_lang, @target_lang, @entries = nil, @entries_format = nil, @entry_count = nil, @creation_time = nil)
    end
  end
end
