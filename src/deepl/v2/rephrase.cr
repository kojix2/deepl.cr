require "./rephrase_result"

module DeepL
  class Translator
    def rephrase_text(
      text : (String | Array(String)),
      target_lang = nil,
      writing_style = nil,
      tone = nil,
    ) : Array(RephraseResult)
      text = [text] if text.is_a?(String)

      params = Hash(String, String | Array(String)).new
      params["text"] = text
      params["target_lang"] = target_lang if target_lang
      params["writing_style"] = writing_style if writing_style
      params["tone"] = tone if tone

      response = Crest.post(
        api_url_rephrase, form: params, headers: http_headers_json, json: true
      )

      handle_response(response)
      parse_rephrase_response(response)
    end

    private def api_url_rephrase : String
      "#{server_url}/write/rephrase"
    end

    private def parse_rephrase_response(response) : Array(RephraseResult)
      parsed_response = JSON.parse(response.body)
      parsed_response["improvements"].as_a.map do |improvement|
        RephraseResult.new(
          detected_source_language: improvement["detected_source_language"].as_s,
          text: improvement["text"].as_s
        )
      end
    end
  end
end
