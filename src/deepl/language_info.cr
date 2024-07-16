module DeepL
  class LanguageInfo
    include JSON::Serializable

    property language : String
    property name : String
    property supports_formality : Bool?

    def initialize(@language, @name, @supports_formality)
    end
  end
end
