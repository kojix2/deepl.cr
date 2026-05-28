require "json"

module DeepL
  class CustomInstruction
    include JSON::Serializable

    property id : String?
    property label : String?
    property prompt : String?
    property source_language : String?

    def initialize(@label = nil, @prompt = nil, @source_language = nil, @id = nil)
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
      @custom_instructions = nil,
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
        "page"      => page,
        "page_size" => page_size,
        "detailed"  => detailed,
      }.compact!

      response = Crest.get(url, params: params, headers: http_headers_base)
      handle_response(response)

      style_rules_json = JSON.parse(response.body)["style_rules"].to_json
      Array(StyleRuleList).from_json(style_rules_json)
    end

    def create_style_rule_list(
      name : String,
      language : String,
      configured_rules : JSON::Any? = nil,
      custom_instructions : Array(CustomInstruction)? = nil,
    ) : StyleRuleList
      url = "#{base_server_url}/v3/style_rules"
      data = {
        "name"                => name,
        "language"            => language,
        "configured_rules"    => configured_rules,
        "custom_instructions" => custom_instructions,
      }.compact!

      response = Crest.post(url, form: data, headers: http_headers_json, json: true)
      handle_response(response)
      StyleRuleList.from_json(response.body)
    end

    def get_style_rule_list(style_id : String) : StyleRuleList
      url = "#{base_server_url}/v3/style_rules/#{style_id}"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response)
      StyleRuleList.from_json(response.body)
    end

    def update_style_rule_list(style_id : String, name : String) : StyleRuleList
      url = "#{base_server_url}/v3/style_rules/#{style_id}"
      data = {"name" => name}

      response = Crest.patch(url, form: data, headers: http_headers_json, json: true)
      handle_response(response)
      StyleRuleList.from_json(response.body)
    end

    def delete_style_rule_list(style_id : String) : Nil
      url = "#{base_server_url}/v3/style_rules/#{style_id}"
      response = Crest.delete(url, headers: http_headers_base)
      handle_response(response)
      nil
    end

    def update_style_rule_configured_rules(
      style_id : String,
      configured_rules : JSON::Any,
    ) : StyleRuleList
      url = "#{base_server_url}/v3/style_rules/#{style_id}/configured_rules"

      response = Crest.put(url, form: configured_rules.to_json, headers: http_headers_json)
      handle_response(response)
      StyleRuleList.from_json(response.body)
    end

    def create_custom_instruction(
      style_id : String,
      label : String,
      prompt : String,
      source_language : String? = nil,
    ) : CustomInstruction
      url = "#{base_server_url}/v3/style_rules/#{style_id}/custom_instructions"
      data = {
        "label"           => label,
        "prompt"          => prompt,
        "source_language" => source_language,
      }.compact!

      response = Crest.post(url, form: data, headers: http_headers_json, json: true)
      handle_response(response)
      CustomInstruction.from_json(response.body)
    end

    def get_custom_instruction(style_id : String, instruction_id : String) : CustomInstruction
      url = "#{base_server_url}/v3/style_rules/#{style_id}/custom_instructions/#{instruction_id}"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response)
      CustomInstruction.from_json(response.body)
    end

    def update_custom_instruction(
      style_id : String,
      instruction_id : String,
      label : String,
      prompt : String,
      source_language : String? = nil,
    ) : CustomInstruction
      url = "#{base_server_url}/v3/style_rules/#{style_id}/custom_instructions/#{instruction_id}"
      data = {
        "label"           => label,
        "prompt"          => prompt,
        "source_language" => source_language,
      }.compact!

      response = Crest.put(url, form: data, headers: http_headers_json, json: true)
      handle_response(response)
      CustomInstruction.from_json(response.body)
    end

    def delete_custom_instruction(style_id : String, instruction_id : String) : Nil
      url = "#{base_server_url}/v3/style_rules/#{style_id}/custom_instructions/#{instruction_id}"
      response = Crest.delete(url, headers: http_headers_base)
      handle_response(response)
      nil
    end
  end
end
