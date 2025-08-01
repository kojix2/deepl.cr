module DeepL
  class DocumentHandle
    include JSON::Serializable

    @[JSON::Field(key: "document_id")]
    property id : String

    @[JSON::Field(key: "document_key")]
    property key : String

    def initialize(@id, @key)
    end
  end
end
