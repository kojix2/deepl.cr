require "json"

module DeepL
  class RephraseResult
    include JSON::Serializable

    property detected_source_language : String
    property text : String

    def initialize(@detected_source_language : String, @text : String)
    end
  end
end
