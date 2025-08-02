module DeepL
  class MultilingualGlossaryInfo
    include JSON::Serializable

    property glossary_id : String
    property name : String
    property dictionaries : Array(GlossaryDictionary)
    property creation_time : Time

    def initialize(@glossary_id, @name, @dictionaries, @creation_time)
    end
  end
end
