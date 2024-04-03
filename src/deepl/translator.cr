require "json"
require "crest"
require "./exceptions"
require "./version"

module DeepL
  record TextResult, text : String, detected_source_language : String
  record DocumentHandle, key : String, id : String

  class Translator
    DEEPL_SERVER_URL           = "https://api.deepl.com/v2"
    DEEPL_SERVER_URL_FREE      = "https://api-free.deepl.com/v2"
    HTTP_STATUS_QUOTA_EXCEEDED = 456

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
        auth_key_is_free_account? ? DEEPL_SERVER_URL_FREE : DEEPL_SERVER_URL
    end

    def api_url_translate : String
      "#{server_url}/translate"
    end

    def api_url_document : String
      "#{server_url}/document"
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

    def translate_text(
      text, target_lang, source_lang = nil, context = nil, split_sentences = nil,
      formality = nil, glossary_id = nil
    ) : TextResult
      response = request_translate_text(
        text: text, target_lang: target_lang, source_lang: source_lang,
        context: context, split_sentences: split_sentences,
        formality: formality, glossary_id: glossary_id
      )

      parse_translate_text_response(response)
    end

    def translate_xml(
      text, target_lang, source_lang = nil, context = nil, split_sentences = nil,
      formality = nil, glossary_id = nil
    ) : Array(TextResult)
      response = request_translate_text(
        text: text, target_lang: target_lang, source_lang: source_lang,
        context: context, split_sentences: split_sentences,
        formality: formality, glossary_id: glossary_id
      )

      parse_translate_xml_response(response)
    end

    private def request_translate_text(
      text, target_lang, source_lang = nil, context = nil, split_sentences = nil,
      formality = nil, glossary_id = nil
    )
      params = {
        "text"            => [text],
        "target_lang"     => target_lang,
        "source_lang"     => source_lang,
        "formality"       => formality,
        "glossary_id"     => glossary_id,
        "context"         => context,
        "split_sentences" => split_sentences,
      }.compact!

      response = Crest.post(api_url_translate, form: params, headers: http_headers_json, json: true)
      handle_response(response)
    end

    private def parse_translate_text_response(response) : TextResult
      parse_translate_xml_response(response).first
    end

    private def parse_translate_xml_response(response) : Array(TextResult)
      parsed_response = JSON.parse(response.body)
      parsed_response["translations"].as_a.map do |t|
        TextResult.new(
          text: t["text"].as_s,
          detected_source_language: t["detected_source_language"].as_s
        )
      end
    end

    def translate_document(
      path, target_lang, source_lang = nil,
      formality = nil, glossary_id = nil, output_format = nil,
      output_path = nil
    )
      params = {
        "source_lang"   => source_lang,
        "formality"     => formality,
        "target_lang"   => target_lang,
        "glossary_id"   => glossary_id,
        "output_format" => output_format,
      }.compact!

      document_handle = translate_document_upload(path, params)

      translate_document_wait_until_done(document_handle)

      output_base_name = "#{path.stem}_#{target_lang}"
      output_extension = output_format ? ".#{output_format.downcase}" : path.extension

      output_path ||= path.parent / (output_base_name + output_extension)

      # Do not overwrite the original file
      if File.exists?(output_path)
        output_path = path.parent / (output_base_name + "_#{Time.utc.to_unix}" + output_extension)
      end

      translate_document_download(output_path, document_handle)
      # rescue ex
      #   raise DocumentTranslationError.new
    end

    def translate_document_upload(path, params) : DocumentHandle
      file = File.open(path)
      params = params.merge({"file" => file})

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

    def translate_document_wait_until_done(document_handle)
      translate_document_wait_until_done(document_handle.id, document_handle.key)
    end

    def translate_document_wait_until_done(document_id, document_key, interval = 10)
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

    def translate_document_download(output_path, document_handle)
      translate_document_download(output_path, document_handle.id, document_handle.key)
    end

    def translate_document_download(output_path, document_id, document_key)
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
      url = "#{server_url}/languages"
      response = Crest.get(url, params: data, headers: http_headers_base)
      handle_response(response)
    end

    def get_target_languages
      response = request_languages("target")
      parse_languages_response(response)
    end

    def get_source_languages
      response = request_languages("source")
      parse_languages_response(response)
    end

    private def parse_languages_response(response)
      (Array(Hash(String, (String | Bool)))).from_json(response.body)
    end

    def get_glossary_language_pairs
      url = "#{server_url}/glossary-language-pairs"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response, glossary: true)
      parse_get_glossary_language_pairs_response(response)
    end

    private def parse_get_glossary_language_pairs_response(response)
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
      url = "#{server_url}/glossaries"
      response = Crest.post(url, form: data, headers: http_headers_json)
      handle_response(response, glossary: true)
      parse_create_glossary_response(response)
    end

    private def parse_create_glossary_response(response)
      JSON.parse(response.body)
    end

    def delete_glossary(glossary_id : String)
      url = "#{server_url}/glossaries/#{glossary_id}"
      response = Crest.delete(url, headers: http_headers_base)
      handle_response(response, glossary: true)
    end

    def list_glossaries
      url = "#{server_url}/glossaries"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response, glossary: true)
      parse_list_glossaries_response(response)
    end

    private def parse_list_glossaries_response(response)
      # JSON.parse(response.body)["glossaries"]
      Hash(String, Array(Hash(String, (String | Bool | Int32))))
        .from_json(response.body)["glossaries"]
    end

    def get_glossary_entries_from_id(glossary_id : String)
      header = http_headers_base
      header["Accept"] = "text/tab-separated-values"
      url = "#{server_url}/glossaries/#{glossary_id}/entries"
      response = Crest.get(url, headers: header)
      handle_response(response, glossary: true)
      response.body # Do not parse
    end

    def get_glossary_entries_from_name(glossary_name : String)
      glossaries = list_glossaries
      glossary = glossaries.find { |g| g["name"] == glossary_name }
      raise DeepLError.new("Glossary not found") unless glossary
      get_glossary_entries_from_id(glossary["glossary_id"].to_s)
    end

    def get_usage
      response = request_get_usage
      parse_get_usage_response(response)
    end

    private def request_get_usage
      url = "#{server_url}/usage"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response)
    end

    private def parse_get_usage_response(response)
      Hash(String, UInt64).from_json(response.body)
    end

    private def auth_key_is_free_account?
      auth_key.ends_with?(":fx")
    end

    # FIXME: Refactoring required
    private def avoid_spinner(str)
      return str unless STDERR.tty?
      "#{"\e[2K\r" if STDERR.tty?}" + str
    end

    def guess_target_language : String
      tl = ENV["DEEPL_TARGET_LANG"]?
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
