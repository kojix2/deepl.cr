module DeepL
  class DocumentHandle
    include JSON::Serializable

    @[JSON::Field(key: "document_id")]
    property id : String

    @[JSON::Field(key: "document_key")]
    property key : String
  end

  class DocumentStatus
    include JSON::Serializable

    @[JSON::Field(key: "document_id")]
    property id : String
    property status : String
    property seconds_remaining : Int32?
    property billed_characters : UInt64?
    property error_message : String?
  end

  class GlossaryInfo
    include JSON::Serializable

    property glossary_id : String
    property name : String
    property ready : Bool
    property source_lang : String
    property target_lang : String
    property creation_time : String # FIXME
    property entry_count : UInt32

    def initialize(@glossary_id, @name, @ready, @source_lang, @target_lang, @creation_time, @entry_count)
    end
  end
end
