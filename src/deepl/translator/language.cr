module DeepL
  class Translator
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
