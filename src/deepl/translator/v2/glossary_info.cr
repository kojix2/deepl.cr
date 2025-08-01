module DeepL
  class GlossaryInfo
    include JSON::Serializable

    property glossary_id : String
    property name : String
    property ready : Bool
    property source_lang : String
    property target_lang : String
    property creation_time : Time
    property entry_count : Int64

    def initialize(@glossary_id, @name, @ready, @source_lang, @target_lang, @creation_time, @entry_count)
    end
  end
end
