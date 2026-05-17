require "json"
require "crest"

module DeepL
  class Translator
    # Note: The default server URL is set during the compilation process.
    # To change the default server URL, you need to recompile the code.
    DEEPL_DEFAULT_SERVER_URL      = "https://api.deepl.com"
    DEEPL_DEFAULT_SERVER_URL_FREE = "https://api-free.deepl.com"
    DEEPL_API_VERSION             = {{ env("DEEPL_API_VERSION") || "v2" }}
    DEEPL_SERVER_URL              = {{ env("DEEPL_SERVER_URL") || DEEPL_DEFAULT_SERVER_URL }}
    DEEPL_SERVER_URL_FREE         = {{ env("DEEPL_SERVER_URL_FREE") || DEEPL_DEFAULT_SERVER_URL_FREE }}
    HTTP_STATUS_QUOTA_EXCEEDED    = 456
    HTTP_STATUS_TOO_MANY_REQUESTS = 529
    REQUEST_ERROR_MESSAGES        = {
      HTTP::Status::NOT_FOUND.to_i              => "Not found",
      HTTP::Status::BAD_REQUEST.to_i            => "Bad request",
      HTTP::Status::PAYLOAD_TOO_LARGE.to_i      => "Payload too large",
      HTTP::Status::UNSUPPORTED_MEDIA_TYPE.to_i => "Unsupported media type",
      HTTP::Status::SERVICE_UNAVAILABLE.to_i    => "Service unavailable or Document not ready",
      HTTP::Status::GATEWAY_TIMEOUT.to_i        => "Gateway timeout",
    }

    setter auth_key : String?
    setter user_agent : String?
    setter server_url : String?
    getter last_trace_id : String?

    # Create a new DeepL::Translator instance
    # @param auth_key [String | Nil] DeepL API key
    # @param user_agent [String | Nil] User-Agent
    # @return [DeepL::Translator]
    # @note If `auth_key` is not given, it will be read from the environment variable `DEEPL_AUTH_KEY` at runtime.

    def initialize(auth_key = nil, user_agent = nil, server_url = nil)
      @auth_key = auth_key
      @user_agent = user_agent
      # Flexibility for testing or future changes
      @server_url = server_url
    end

    def server_url : String
      @server_url ||
        if auth_key_is_free_account?
          "#{DEEPL_SERVER_URL_FREE}/#{DEEPL_API_VERSION}"
        else
          "#{DEEPL_SERVER_URL}/#{DEEPL_API_VERSION}"
        end
    end

    # Return the base API server URL without any version suffix.
    # Examples:
    # - https://api.deepl.com/v2 -> https://api.deepl.com
    # - https://api.free.deepl.com -> https://api.free.deepl.com
    # - custom provided server_url (with or without /vN) -> stripped of /vN
    def base_server_url : String
      candidate = @server_url || (
        auth_key_is_free_account? ? DEEPL_SERVER_URL_FREE : DEEPL_SERVER_URL
      )
      # Strip a trailing "/v<number>" (optionally followed by a slash)
      candidate.sub(/\/v\d+(\/)?$/, "")
    end

    def auth_key : String
      @auth_key || ENV["DEEPL_AUTH_KEY"]? || raise ApiKeyNotFoundError.new
    end

    def user_agent : String
      @user_agent || ENV["DEEPL_USER_AGENT"]? || "deepl.cr/#{VERSION}"
    end

    private def http_headers_base
      {
        "Authorization" => "DeepL-Auth-Key #{auth_key}",
        "User-Agent"    => user_agent,
      }
    end

    private def http_headers_json
      http_headers_base.merge({"Content-Type" => "application/json"})
    end

    private def handle_response(response, glossary = false)
      trace_header = response.headers["X-Trace-ID"]?
      @last_trace_id = trace_header.is_a?(Array) ? trace_header.first? : trace_header
      status_code = response.status_code.to_i
      return response if 200 <= status_code <= 399

      raise response_error(status_code, glossary)
    end

    private def response_error(status_code : Int, glossary : Bool) : DeepLError
      return GlossaryNotFoundError.new if glossary && status_code == HTTP::Status::NOT_FOUND.to_i
      return AuthorizationError.new if {HTTP::Status::UNAUTHORIZED.to_i, HTTP::Status::FORBIDDEN.to_i}.includes?(status_code)
      return QuotaExceededError.new if status_code == HTTP_STATUS_QUOTA_EXCEEDED
      return TooManyRequestsError.new if {HTTP::Status::TOO_MANY_REQUESTS.to_i, HTTP_STATUS_TOO_MANY_REQUESTS}.includes?(status_code)

      RequestError.new(REQUEST_ERROR_MESSAGES[status_code]? || "Unknown error")
    end

    private def api_url_translate : String
      "#{server_url}/translate"
    end

    private def api_url_document : String
      "#{server_url}/document"
    end

    private def auth_key_is_free_account? : Bool
      auth_key.ends_with?(":fx")
    end

    private def auth_key_is_mock? : Bool
      auth_key == "mock"
    end
  end
end
