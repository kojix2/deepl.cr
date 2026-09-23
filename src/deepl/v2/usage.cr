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
      auth_key_is_free_account? ? get_usage_free : get_usage_pro
    end

    private def request_get_usage
      url = api_url("/v2/usage")
      response = with_transport_error do
        Crest.get(
          url,
          headers: http_headers_base,
          handle_errors: false,
          max_redirects: 0,
        )
      end
      handle_response(response)
    end
  end
end
