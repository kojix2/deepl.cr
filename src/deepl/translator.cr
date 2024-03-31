require "json"
require "crest"
require "./exceptions"
require "./version"

module DeepL
  class Translator
    API_URL_BASE_PRO  = "https://api.deepl.com/v2"
    API_URL_BASE_FREE = "https://api-free.deepl.com/v2"

    setter auth_key : String?
    setter user_agent : String?
    setter api_url_base : String?

    record DocumentHandle, key : String, id : String

    # Create a new DeepL::Translator instance
    # @param auth_key [String | Nil] DeepL API key
    # @param user_agent [String | Nil] User-Agent
    # @return [DeepL::Translator]
    # @note If `auth_key` is not given, it will be read from the environment variable `DEEPL_AUTH_KEY` at runtime.

    def initialize(auth_key = nil, user_agent = nil, api_url_base = nil)
      @auth_key = auth_key
      @user_agent = user_agent
      # Fexibility for testing or future changes
      @api_url_base = api_url_base
    end

    def api_url_base : String
      @api_url_base ||
        auth_key_is_free_account? ? API_URL_BASE_FREE : API_URL_BASE_PRO
    end

    def api_url_translate : String
      "#{api_url_base}/translate"
    end

    def api_url_document : String
      "#{api_url_base}/document"
    end

    def auth_key : String
      @auth_key || ENV["DEEPL_AUTH_KEY"]? || ENV["DEEPL_API_KEY"]? || raise ApiKeyError.new
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

    private def handle_response(response)
      case response.status_code
      when 456
        raise QuotaExceededError.new
      when HTTP::Status::FORBIDDEN
        raise AuthorizationError.new
      when HTTP::Status::NOT_FOUND
        raise RequestError.new("Not found")
      when HTTP::Status::BAD_REQUEST
        raise RequestError.new("Bad request")
      when HTTP::Status::TOO_MANY_REQUESTS
        raise TooManyRequestsError.new
      when HTTP::Status::SERVICE_UNAVAILABLE
        raise RequestError.new("Service unavailable")
      end
      response
    end

    def translate_text(
      text, target_lang, source_lang = nil, context = nil, split_sentences = nil,
      formality = nil, glossary_id = nil
    )
      params = Hash(String, String | Array(String)).new
      params["text"] = [text] # Multiple Sentences
      params["target_lang"] = target_lang
      params["source_lang"] = source_lang if source_lang
      params["formality"] = formality if formality
      params["glossary_id"] = glossary_id if glossary_id
      # experimental feature
      params["context"] = context if context
      params["split_sentences"] = split_sentences if split_sentences

      response = Crest.post(api_url_translate, form: params, headers: http_headers_json, json: true)

      parsed_response = JSON.parse(response.body)
      parsed_response.dig("translations", 0, "text")
    end

    def translate_document(
      path, target_lang, source_lang = nil,
      formality = nil, glossary_id = nil, output_format = nil,
      output_path = nil
    )
      params = Hash(String, (String | File)).new
      params["source_lang"] = source_lang if source_lang
      params["formality"] = formality if formality
      params["target_lang"] = target_lang if target_lang
      params["glossary_id"] = glossary_id if glossary_id
      params["output_format"] = output_format if output_format

      document_handle = upload_document(path, params)

      check_status_of_document(document_handle)

      output_base_name = "#{path.stem}_#{target_lang}"
      output_extension = output_format ? ".#{output_format.downcase}" : path.extension

      output_path ||= path.parent / (output_base_name + output_extension)

      # Do not overwrite the original file
      if File.exists?(output_path)
        output_path = path.parent / (output_base_name + "_#{Time.utc.to_unix}" + output_extension)
      end

      download_document(output_path, document_handle)
      # rescue ex
      #   raise DocumentTranslationError.new
    end

    def upload_document(path, params) : DocumentHandle
      file = File.open(path)
      params["file"] = file

      response = Crest.post(api_url_document, form: params, headers: http_headers_base)
      handle_response(response)

      parsed_response = JSON.parse(response.body)
      document_handle = DocumentHandle.new(
        key: parsed_response.dig("document_key").to_s,
        id: parsed_response.dig("document_id").to_s
      )

      STDERR.puts(
        avoid_spinner(
          "[deepl.cr] Uploaded #{path} : #{parsed_response}"
        )
      )

      document_handle
    end

    def check_status_of_document(document_handle)
      check_status_of_document(document_handle.id, document_handle.key)
    end

    def check_status_of_document(document_id, document_key, interval = 10)
      url = "#{api_url_document}/#{document_id}"
      data = {"document_key" => document_key}

      loop do
        sleep interval
        response = Crest.post(url, form: data, headers: http_headers_json)
        handle_response(response)
        parsed_response = JSON.parse(response.body)

        STDERR.puts(
          avoid_spinner(
            "[deepl.cr] Status of document : #{parsed_response}"
          )
        )

        status = parsed_response.dig("status")
        break if status == "done"
        raise DocumentTranslationError.new if status == "error"
      end
    end

    def download_document(output_path, document_handle)
      download_document(output_path, document_handle.id, document_handle.key)
    end

    def download_document(output_path, document_id, document_key)
      data = {"document_key" => document_key}
      url = "#{api_url_document}/#{document_id}/result"
      Crest.post(url, form: data, headers: http_headers_json) do |response|
        raise DocumentTranslationError.new unless response.success?
        File.open(output_path, "wb") do |file|
          IO.copy(response.body_io, file)
        end
      end

      STDERR.puts(
        avoid_spinner(
          "[deepl.cr] Saved #{output_path}"
        )
      )
    end

    def request_languages(type)
      data = {"type" => type}
      url = "#{api_url_base}/languages"
      response = Crest.get(url, params: data, headers: http_headers_base)
      handle_response(response)
    end

    def target_languages
      response = request_languages("target")
      parse_languages_response(response)
    end

    def source_languages
      response = request_languages("source")
      parse_languages_response(response)
    end

    private def parse_languages_response(response)
      (Array(Hash(String, (String | Bool)))).from_json(response.body)
    end

    def glossary_language_pairs
      url = "#{api_url_base}/glossary-language-pairs"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response)
      parse_glossary_language_pairs_response(response)
    end

    private def parse_glossary_language_pairs_response(response)
      Hash(String, Array(Hash(String, String)))
        .from_json(response.body)["supported_languages"]
    end

    def create_glossary(name, source_lang, target_lang, entries, entry_format = "tsv")
      data = {
        "name"           => name,
        "source_lang"    => source_lang,
        "target_lang"    => target_lang,
        "entries"        => entries,
        "entries_format" => entry_format,
      }
      url = "#{api_url_base}/glossaries"
      response = Crest.post(url, form: data, headers: http_headers_json)
      handle_response(response)
      parse_create_glossary_response(response)
    end

    private def parse_create_glossary_response(response)
      JSON.parse(response.body)
    end

    def delete_glossary(glossary_id : String)
      url = "#{api_url_base}/glossaries/#{glossary_id}"
      response = Crest.delete(url, headers: http_headers_base)
      handle_response(response)
    end

    def glossary_list
      url = "#{api_url_base}/glossaries"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response)
      parse_glossary_list_response(response)
    end

    private def parse_glossary_list_response(response)
      # JSON.parse(response.body)["glossaries"]
      Hash(String, Array(Hash(String, (String | Bool | Int32))))
        .from_json(response.body)["glossaries"]
    end

    def glossary_entries_from_id(glossary_id : String)
      header = http_headers_base
      header["Accept"] = "text/tab-separated-values"
      url = "#{api_url_base}/glossaries/#{glossary_id}/entries"
      response = Crest.get(url, headers: header)
      handle_response(response)
      response.body # Do not parse
    end

    def glossary_entries_from_name(glossary_name : String)
      glossaries = glossary_list
      glossary = glossaries.find { |g| g["name"] == glossary_name }
      raise DeepLError.new("Glossary not found") unless glossary
      glossary_entries_from_id(glossary["glossary_id"].to_s)
    end

    def usage
      response = request_usage
      parse_usage_response(response)
    end

    private def request_usage
      url = "#{api_url_base}/usage"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response)
    end

    private def parse_usage_response(response)
      Hash(String, UInt64).from_json(response.body)
    end

    private def auth_key_is_free_account?
      auth_key.ends_with?(":fx")
    end

    # FIXME: Refactoring required
    def avoid_spinner(str)
      return str unless STDERR.tty?
      "#{"\e[2K\r" if STDERR.tty?}" + str
    end

    def guess_target_language : String
      tl = ENV["DEEPL_TARGET_LANGUAGE"]?
      return tl if tl
      # The language of the current locale
      # If the locale is de_DE.UTF-8, then the target language is DE
      {% if flag?(:darwin) || flag?(:unix) %}
        ENV["LANG"]?.try &.split("_").try &.first.upcase || "EN"
      {% elsif flag?(:windows) %}
        l = `powershell -Command "[System.Globalization.CultureInfo]::CurrentCulture.TwoLetterISOLanguageName"`
        l.empty? ? "EN" : l.strip.upcase
      {% else %}
        # From official deepl documentation, EN is deprecated.
        # EN-US or EN-GB is recommended.
        "EN"
      {% end %}
    end
  end
end
