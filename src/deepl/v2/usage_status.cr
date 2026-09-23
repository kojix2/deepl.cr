module DeepL
  abstract class Usage
    include JSON::Serializable

    property character_count : Int64?
    property character_limit : Int64?
    property document_count : Int64?
    property document_limit : Int64?
    property team_document_count : Int64?
    property team_document_limit : Int64?
  end

  class UsagePro < Usage
    class Product
      include JSON::Serializable

      property product_type : String?
      property api_key_character_count : Int64?
      property character_count : Int64?
      property billing_unit : String?
      property api_key_unit_count : Int64?
      property account_unit_count : Int64?

      def initialize(
        @product_type = nil,
        @api_key_character_count = nil,
        @character_count = nil,
        @billing_unit = nil,
        @api_key_unit_count = nil,
        @account_unit_count = nil,
      )
      end
    end

    property products : Array(Product) = [] of Product
    property api_key_character_count : Int64?
    property api_key_character_limit : Int64?
    property speech_to_text_milliseconds_count : Int64?
    property speech_to_text_milliseconds_limit : Int64?
    property speech_to_text_minutes_count : Int64?
    property speech_to_text_minutes_limit : Int64?
    property speech_to_speech_minutes_count : Int64?
    property speech_to_speech_minutes_limit : Int64?
    property start_time : Time?
    property end_time : Time?

    def initialize(
      @products,
      @api_key_character_count,
      @api_key_character_limit,
      @start_time,
      @end_time,
      @character_count,
      @character_limit,
      @speech_to_text_milliseconds_count = nil,
      @speech_to_text_milliseconds_limit = nil,
      @document_count = nil,
      @document_limit = nil,
      @team_document_count = nil,
      @team_document_limit = nil,
      @speech_to_text_minutes_count = nil,
      @speech_to_text_minutes_limit = nil,
      @speech_to_speech_minutes_count = nil,
      @speech_to_speech_minutes_limit = nil,
    )
    end
  end

  class UsageFree < Usage
    def initialize(
      @character_count,
      @character_limit,
      @document_count = nil,
      @document_limit = nil,
      @team_document_count = nil,
      @team_document_limit = nil,
    )
    end
  end
end
