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

    setter auth_key : String?
    setter user_agent : String?
    setter server_url : String?

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
      case response.status_code
      when 200..399
        return response
      when HTTP::Status::FORBIDDEN
        raise AuthorizationError.new
      when HTTP_STATUS_QUOTA_EXCEEDED
        raise QuotaExceededError.new
      when glossary && HTTP::Status::NOT_FOUND
        raise GlossaryNotFoundError.new
      when HTTP::Status::NOT_FOUND
        raise RequestError.new("Not found")
      when HTTP::Status::BAD_REQUEST
        raise RequestError.new("Bad request")
      when HTTP::Status::TOO_MANY_REQUESTS
        raise TooManyRequestsError.new
      when HTTP::Status::SERVICE_UNAVAILABLE
        raise RequestError.new("Service unavailable or Document not ready")
      else
        raise RequestError.new("Unknown error")
      end
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
