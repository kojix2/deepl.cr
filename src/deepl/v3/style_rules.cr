require "json"

module DeepL
  class CustomInstruction
    include JSON::Serializable

    property label : String?
    property prompt : String?
    property source_language : String?

    def initialize(@label = nil, @prompt = nil, @source_language = nil)
    end
  end

  class StyleRuleList
    include JSON::Serializable

    property style_id : String
    property name : String
    property creation_time : Time
    property updated_time : Time
    property language : String
    property version : Int32
    property configured_rules : Array(JSON::Any)?
    property custom_instructions : Array(CustomInstruction)?

    def initialize(
      @style_id,
      @name,
      @creation_time,
      @updated_time,
      @language,
      @version,
      @configured_rules = nil,
      @custom_instructions = nil
    )
    end
  end

  class Translator
    # List style rule lists
    def list_style_rule_lists(
      page : Int32? = nil,
      page_size : Int32? = nil,
      detailed : Bool? = nil,
    ) : Array(StyleRuleList)
      url = "#{base_server_url}/v3/style_rules"

      params = {
        "page" => page,
        "page_size" => page_size,
        "detailed" => detailed,
      }.compact!

      response = Crest.get(url, params: params, headers: http_headers_base)
      handle_response(response)

      style_rules_json = JSON.parse(response.body)["style_rules"].to_json
      Array(StyleRuleList).from_json(style_rules_json)
    end
  end
end
