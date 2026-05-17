module DeepL
  class DocumentStatus
    include JSON::Serializable

    @[JSON::Field(key: "document_id")]
    property id : String
    property status : String
    property seconds_remaining : Int64?
    property billed_characters : Int64?
    property error_message : String?

    # currently not used
    def summary : String
      String.build do |summary|
        summary << "(i) #{id}"
        summary << " (s) #{status}"
        summary << " (r) #{seconds_remaining}" if seconds_remaining
        summary << " (c) #{billed_characters}" if billed_characters
        summary << " (e) #{error_message}" if error_message
      end
    end
  end
end
