require "json"

module DeepL
  class ApiKeyUsageLimits
    include JSON::Serializable

    property characters : Float64?

    def initialize(@characters = nil)
    end
  end

  class ApiKey
    include JSON::Serializable

    property key_id : String
    property label : String
    property creation_time : Time
    property deactivated_time : Time?
    property is_deactivated : Bool
    property usage_limits : ApiKeyUsageLimits?

    def initialize(
      @key_id,
      @label,
      @creation_time,
      @deactivated_time = nil,
      @is_deactivated = false,
      @usage_limits = nil,
    )
    end
  end

  class UsageBreakdown
    include JSON::Serializable

    property total_characters : Int64
    property text_translation_characters : Int64?
    property document_translation_characters : Int64?
    property text_improvement_characters : Int64?
    property speech_to_text_milliseconds : Int64?

    def initialize(
      @total_characters,
      @text_translation_characters = nil,
      @document_translation_characters = nil,
      @text_improvement_characters = nil,
      @speech_to_text_milliseconds = nil,
    )
    end
  end

  class KeyUsageItem
    include JSON::Serializable

    property api_key : String
    property api_key_label : String
    property usage : UsageBreakdown

    def initialize(@api_key, @api_key_label, @usage)
    end
  end

  class KeyAndDayUsageItem
    include JSON::Serializable

    property api_key : String
    property api_key_label : String
    property usage_date : Time
    property usage : UsageBreakdown

    def initialize(@api_key, @api_key_label, @usage_date, @usage)
    end
  end

  class AdminUsageReportData
    include JSON::Serializable

    property total_usage : UsageBreakdown
    property start_date : Time
    property end_date : Time
    property group_by : String?
    property key_usages : Array(KeyUsageItem)?
    property key_and_day_usages : Array(KeyAndDayUsageItem)?

    def initialize(
      @total_usage,
      @start_date,
      @end_date,
      @group_by = nil,
      @key_usages = nil,
      @key_and_day_usages = nil,
    )
    end
  end

  class AdminUsageReport
    include JSON::Serializable

    property usage_report : AdminUsageReportData

    def initialize(@usage_report)
    end
  end

  class Translator
    # Create a developer key as an admin
    def admin_create_developer_key(label : String? = nil) : ApiKey
      url = "#{server_url}/admin/developer-keys"
      data = {
        "label" => label,
      }.compact!

      response = Crest.post(url, form: data, json: true, headers: http_headers_json)
      handle_response(response)
      ApiKey.from_json(response.body)
    end

    # Get all developer keys as an admin
    def admin_get_developer_keys : Array(ApiKey)
      url = "#{server_url}/admin/developer-keys"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response)
      Array(ApiKey).from_json(response.body)
    end

    # Deactivate a developer key as an admin
    def admin_deactivate_developer_key(key_id : String) : ApiKey
      url = "#{server_url}/admin/developer-keys/deactivate"
      data = {
        "key_id" => key_id,
      }

      response = Crest.put(url, form: data, json: true, headers: http_headers_json)
      handle_response(response)
      ApiKey.from_json(response.body)
    end

    # Rename a developer key as an admin
    def admin_rename_developer_key(key_id : String, label : String) : ApiKey
      url = "#{server_url}/admin/developer-keys/label"
      data = {
        "key_id" => key_id,
        "label"  => label,
      }

      response = Crest.put(url, form: data, json: true, headers: http_headers_json)
      handle_response(response)
      ApiKey.from_json(response.body)
    end

    # Set developer key usage limits as an admin
    def admin_set_developer_key_usage_limits(key_id : String, characters : Float64? = nil) : ApiKey
      url = "#{server_url}/admin/developer-keys/limits"
      data = {
        "key_id"     => key_id,
        "characters" => characters,
      }.compact!

      response = Crest.put(url, form: data, json: true, headers: http_headers_json)
      handle_response(response)
      ApiKey.from_json(response.body)
    end

    # Get usage statistics as an admin
    def admin_get_analytics(start_date : String, end_date : String, group_by : String? = nil) : AdminUsageReport
      url = "#{server_url}/admin/analytics"
      params = {
        "start_date" => start_date,
        "end_date"   => end_date,
        "group_by"   => group_by,
      }.compact!

      response = Crest.get(url, params: params, headers: http_headers_base)
      handle_response(response)
      AdminUsageReport.from_json(response.body)
    end
  end
end
