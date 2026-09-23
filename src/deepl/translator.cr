require "json"
require "crest"

module DeepL
  class Translator
    # Note: The default server URL is set during the compilation process.
    # To change the default server URL, you need to recompile the code.
    DEEPL_DEFAULT_SERVER_URL      = "https://api.deepl.com"
    DEEPL_DEFAULT_SERVER_URL_FREE = "https://api-free.deepl.com"
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
      candidate = @server_url || (
        auth_key_is_free_account? ? DEEPL_SERVER_URL_FREE : DEEPL_SERVER_URL
      )
      # Accept legacy custom URLs while exposing one canonical, versionless
      # server URL. Endpoint modules add their own /v2 or /v3 path.
      candidate.sub(/\/v\d+\/?$/, "").sub(/\/+$/, "")
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

    private def api_url(path : String) : String
      raise ArgumentError.new("API paths must begin with '/'.") unless path.starts_with?("/")
      "#{server_url}#{path}"
    end

    private def with_transport_error(&)
      @last_trace_id = nil
      yield
    rescue error : File::Error
      raise error
    rescue error : IO::Error
      request_error = RequestError.new(error)
      request_error.trace_id = @last_trace_id
      raise request_error
    end

    private def handle_response(response : Crest::Response, glossary = false)
      @last_trace_id = response.http_client_res.headers["X-Trace-ID"]?
      status_code = response.status_code.to_i
      return response if 200 <= status_code <= 299

      raise response_error(response, glossary)
    end

    private def response_error(response : Crest::Response, glossary : Bool) : DeepLError
      status_code = response.status_code.to_i
      error = if glossary && status_code == HTTP::Status::NOT_FOUND.to_i
                GlossaryNotFoundError.new
              elsif {HTTP::Status::UNAUTHORIZED.to_i, HTTP::Status::FORBIDDEN.to_i}.includes?(status_code)
                AuthorizationError.new
              elsif status_code == HTTP_STATUS_QUOTA_EXCEEDED
                QuotaExceededError.new
              elsif {HTTP::Status::TOO_MANY_REQUESTS.to_i, HTTP_STATUS_TOO_MANY_REQUESTS}.includes?(status_code)
                TooManyRequestsError.new
              else
                RequestError.new(response_error_message(response))
              end
      error.trace_id = @last_trace_id
      error
    end

    private def response_error_message(response : Crest::Response) : String
      default_message : String = REQUEST_ERROR_MESSAGES[response.status_code.to_i]? || "Request failed"
      raw_body = response.body
      body = raw_body ? raw_body.strip : ""
      return default_message if body.empty?

      parsed = begin
        JSON.parse(body)
      rescue JSON::ParseException
        return body
      end

      if object = parsed.as_h?
        message = object["message"]?.try(&.as_s?)
        return message if message

        if error = object["error"]?
          message = error.as_s? || error.as_h?.try { |nested| nested["message"]?.try(&.as_s?) }
          return message if message
        end
      end

      body
    end

    private def api_url_translate : String
      api_url("/v2/translate")
    end

    private def api_url_document : String
      api_url("/v2/document")
    end

    private def auth_key_is_free_account? : Bool
      auth_key.ends_with?(":fx")
    end

    private def auth_key_is_mock? : Bool
      auth_key == "mock"
    end
  end
end
