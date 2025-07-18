module DeepL
  class UsagePro
    include JSON::Serializable

    class Product
      include JSON::Serializable

      property product_type : String
      property api_key_character_count : Int64
      property character_count : Int64

      def initialize(@product_type, @api_key_character_count, @character_count)
      end
    end

    property products : Array(Product)
    property api_key_character_count : Int64
    property api_key_character_limit : Int64
    property start_time : Time
    property end_time : Time
    property character_count : Int64
    property character_limit : Int64

    def initialize(@products, @api_key_character_count, @api_key_character_limit, @start_time, @end_time, @character_count, @character_limit)
    end
  end

  class UsageFree
    include JSON::Serializable

    property character_count : Int64
    property character_limit : Int64

    def initialize(@character_count, @character_limit)
    end
  end
end
