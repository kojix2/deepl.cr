require "./usage_status"

module DeepL
  class Translator
    # ameba:disable Naming/AccessorMethodName
    def get_usage_pro : UsagePro
      UsagePro.from_json(request_get_usage.body)
    end

    # ameba:disable Naming/AccessorMethodName
    def get_usage_free : UsageFree
      UsageFree.from_json(request_get_usage.body)
    end

    # ameba:disable Naming/AccessorMethodName
    def get_usage : Usage
      if auth_key_is_mock? # Workaround for testing
        get_usage_free
      elsif auth_key_is_free_account?
        get_usage_free
      else
        get_usage_pro
      end
    end

    private def request_get_usage
      url = "#{server_url}/usage"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response)
    end
  end
end
