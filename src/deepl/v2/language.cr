require "./language_info"

module DeepL
  class Translator
    private def request_languages(type)
      data = {"type" => type}
      url = api_url("/v2/languages")
      response = with_transport_error do
        Crest.get(
          url,
          params: data,
          headers: http_headers_base,
          handle_errors: false,
          max_redirects: 0,
        )
      end
      handle_response(response)
    end

    # ameba:disable Naming/AccessorMethodName
    def get_target_languages : Array(LanguageInfo)
      response = request_languages("target")
      Array(LanguageInfo).from_json(response.body)
    end

    # ameba:disable Naming/AccessorMethodName
    def get_source_languages : Array(LanguageInfo)
      response = request_languages("source")
      Array(LanguageInfo).from_json(response.body)
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
        "EN"
      {% end %}
    end
  end
end
