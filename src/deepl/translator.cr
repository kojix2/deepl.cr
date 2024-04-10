require "json"
require "crest"
require "./exceptions"
require "./version"

# API Data

require "./text_result"
require "./document_handle"
require "./document_status"
require "./glossary_info"
require "./glossary_language_pair"
require "./language_info"

module DeepL
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

    private def api_url_translate : String
      "#{server_url}/translate"
    end

    private def api_url_document : String
      "#{server_url}/document"
    end

    def auth_key : String
      @auth_key || ENV["DEEPL_AUTH_KEY"]? || raise ApiKeyError.new
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
      text, target_lang,
      source_lang = nil,
      context = nil,
      split_sentences = nil,
      formality = nil,
      glossary_id = nil,
      glossary_name = nil # original option of deepl.cr
    ) : TextResult
      response = request_translate_text(
        text: text,
        target_lang: target_lang,
        source_lang: source_lang,
        context: context,
        split_sentences: split_sentences,
        formality: formality,
        glossary_id: glossary_id,
        glossary_name: glossary_name
      )

      parse_translate_text_response(response)
    end

    def translate_xml(
      text,
      target_lang,
      source_lang = nil,
      context = nil,
      split_sentences = nil,
      formality = nil,
      glossary_id = nil,
      glossary_name = nil # original option of deepl.cr
    ) : Array(TextResult)
      response = request_translate_text(
        text: text,
        target_lang: target_lang,
        source_lang: source_lang,
        context: context,
        split_sentences: split_sentences,
        formality: formality,
        glossary_id: glossary_id,
        glossary_name: glossary_name
      )

      parse_translate_xml_response(response)
    end

    private def request_translate_text(
      text,
      target_lang,
      source_lang = nil,
      context = nil,
      split_sentences = nil,
      formality = nil,
      glossary_id = nil,
      glossary_name = nil # original option of deepl.cr
    )
      if glossary_name
        glossary_id ||= convert_glossary_name_to_id(glossary_name)
      end
      params = {
        "text"            => [text],
        "target_lang"     => target_lang,
        "source_lang"     => source_lang,
        "formality"       => formality,
        "glossary_id"     => glossary_id,
        "context"         => context,
        "split_sentences" => split_sentences,
      }.compact!

      response = Crest.post(
        api_url_translate, form: params, headers: http_headers_json, json: true
      )
      handle_response(response)
    end

    private def parse_translate_text_response(response) : TextResult
      parse_translate_xml_response(response).first # FIXME
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
      path,
      target_lang,
      source_lang = nil,
      formality = nil,
      glossary_id = nil,
      glossary_name = nil, # original option of deepl.cr
      output_format = nil,
      output_file = nil,
      interval = 5.0,
      &block : (String ->)
    )
      translate_document(
        path: path,
        target_lang: target_lang,
        source_lang: source_lang,
        formality: formality,
        glossary_id: glossary_id,
        glossary_name: glossary_name,
        output_format: output_format,
        output_file: output_file,
        interval: interval,
        block: block
      )
    end

    def translate_document(
      path,
      target_lang,
      source_lang = nil,
      formality = nil,
      glossary_id = nil,
      glossary_name = nil,
      output_format = nil,
      output_file = nil,
      interval = 5.0,
      block : (String ->)? = nil
    )
      source_path = Path[path]

      document_handle = translate_document_upload(
        path: source_path,
        target_lang: target_lang,
        source_lang: source_lang,
        formality: formality,
        glossary_id: glossary_id,
        glossary_name: glossary_name,
        output_format: output_format
      )
      block.try &.call "[deepl.cr] (i) id (k) key (s) status (t) seconds_remaining (c) billed_characters (e) error_message"
      block.try &.call "[deepl.cr] Uploaded #{source_path} (i) #{document_handle.id} (k) #{document_handle.key}"

      translate_document_wait_until_done(document_handle, interval) do |document_status|
        block.try &.call("[deepl.cr] #{document_status.summary}")
      end

      output_file ||= generate_output_file(source_path, target_lang, output_format)

      translate_document_download(output_file, document_handle)
      block.try &.call "[deepl.cr] Saved #{output_file}"
    end

    private def generate_output_file(source_path : Path, target_lang, output_format) : Path
      output_base_name = "#{source_path.stem}_#{target_lang}"
      output_extension = output_format ? ".#{output_format.downcase}" : source_path.extension
      output_file = source_path.parent / (output_base_name + output_extension)
      ensure_unique_output_file(output_file)
    end

    private def ensure_unique_output_file(output_file : Path) : Path
      return output_file unless File.exists?(output_file)
      output_base_name = "#{output_file.stem}_#{Time.utc.to_unix}"
      output_extension = output_file.extension
      output_file = output_file.parent / (output_base_name + output_extension)
    end

    def translate_document_upload(
      path : Path | String,
      target_lang,
      source_lang = nil,
      formality = nil,
      glossary_id = nil,
      glossary_name = nil, # original option of deepl.cr
      output_format = nil
    ) : DocumentHandle
      path = Path[path] if path.is_a?(String)
      if glossary_name
        glossary_id ||= convert_glossary_name_to_id(glossary_name)
      end
      params = {
        "source_lang"   => source_lang,
        "formality"     => formality,
        "target_lang"   => target_lang,
        "glossary_id"   => glossary_id,
        "output_format" => output_format,
      }.compact!
      file = File.open(path)
      params = params.merge({"file" => file})

      response = Crest.post(api_url_document, form: params, headers: http_headers_base)
      handle_response(response)

      DocumentHandle.from_json(response.body)
    end

    def translate_document_wait_until_done(
      handle : DocumentHandle,
      interval = 5.0,
      &block : (DocumentStatus ->)
    )
      translate_document_wait_until_done(
        handle: handle,
        interval: interval,
        block: block
      )
    end

    def translate_document_wait_until_done(
      handle : DocumentHandle,
      interval = 5.0,
      block : (DocumentStatus ->)? = nil
    )
      loop do
        sleep interval
        document_status = translate_document_get_status(handle)

        block.try &.call(document_status)

        case document_status.status
        when "done"  then break
        when "error" then raise DocumentTranslationError.new(document_status.error_message)
        end
      end
    end

    def translate_document_get_status(handle : DocumentHandle) : DocumentStatus
      url = "#{api_url_document}/#{handle.id}"
      data = {"document_key" => handle.key}
      response = Crest.post(url, form: data, headers: http_headers_json)
      handle_response(response)
      DocumentStatus.from_json(response.body)
    end

    def translate_document_download(output_file, handle : DocumentHandle)
      data = {"document_key" => handle.key}
      url = "#{api_url_document}/#{handle.id}/result"
      Crest.post(url, form: data, headers: http_headers_json) do |response|
        raise DocumentTranslationError.new unless response.success?
        File.open(output_file, "wb") do |file|
          IO.copy(response.body_io, file)
        end
      end
    end

    private def request_languages(type)
      data = {"type" => type}
      url = "#{server_url}/languages"
      response = Crest.get(url, params: data, headers: http_headers_base)
      handle_response(response)
    end

    def get_target_languages : Array(LanguageInfo)
      response = request_languages("target")
      Array(LanguageInfo).from_json(response.body)
    end

    def get_source_languages : Array(LanguageInfo)
      response = request_languages("source")
      Array(LanguageInfo).from_json(response.body)
    end

    def get_glossary_language_pairs : Array(GlossaryLanguagePair)
      url = "#{server_url}/glossary-language-pairs"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response, glossary: true)
      Array(GlossaryLanguagePair).from_json(
        JSON.parse(response.body)["supported_languages"].to_json
      )
    end

    def create_glossary(
      name,
      source_lang,
      target_lang,
      entries,
      entry_format = "tsv"
    ) : GlossaryInfo
      url = "#{server_url}/glossaries"
      data = {
        "name"           => name,
        "source_lang"    => source_lang,
        "target_lang"    => target_lang,
        "entries"        => entries,
        "entries_format" => entry_format,
      }
      response = Crest.post(url, form: data, headers: http_headers_json)
      handle_response(response, glossary: true)
      GlossaryInfo.from_json(response.body)
    end

    def delete_glossary(glossary_id : String)
      url = "#{server_url}/glossaries/#{glossary_id}"
      response = Crest.delete(url, headers: http_headers_base)
      handle_response(response, glossary: true)
      # FIXME: Return value
    end

    def delete_glossary_by_name(name : String)
      glossary_id = convert_glossary_name_to_id(name)
      delete_glossary(glossary_id)
    end

    def list_glossaries : Array(GlossaryInfo)
      url = "#{server_url}/glossaries"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response, glossary: true)
      glossaries_json = JSON.parse(response.body)["glossaries"].to_json
      Array(GlossaryInfo).from_json(glossaries_json)
    end

    def get_glossary_entries(glossary_id : String) : String
      header = http_headers_base
      header["Accept"] = "text/tab-separated-values"
      url = "#{server_url}/glossaries/#{glossary_id}/entries"
      response = Crest.get(url, headers: header)
      handle_response(response, glossary: true)
      response.body # Do not parse because it is a TSV
    end

    def get_glossary_entries_by_name(name : String) : String
      glossary_id = convert_glossary_name_to_id(name)
      get_glossary_entries(glossary_id)
    end

    def convert_glossary_name_to_id(name : String) : String
      glossaries = list_glossaries
      glossary = glossaries.find { |g| g.name == name }
      raise GlossaryNotFoundError.new unless glossary
      glossary.glossary_id
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

    private def auth_key_is_free_account? : Bool
      auth_key.ends_with?(":fx")
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
