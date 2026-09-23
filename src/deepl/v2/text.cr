require "./text_result"

module DeepL
  class Translator
    def translate_text(
      text : (String | Array(String)),
      target_lang,
      source_lang = nil,
      context = nil,
      enable_beta_languages : Bool? = nil,
      custom_instructions : Array(String)? = nil,
      show_billed_characters : Bool? = nil,
      split_sentences = nil,
      preserve_formatting : Bool? = nil,
      formality = nil,
      glossary_id = nil,
      glossary_name = nil, # original option of deepl.cr
      tag_handling = nil,
      outline_detection : Bool? = nil,
      non_splitting_tags : Array(String)? = nil,
      splitting_tags : Array(String)? = nil,
      ignore_tags : Array(String)? = nil,
      model_type = nil,
      style_id = nil,
      tag_handling_version = nil,
      translation_memory_id = nil,
      translation_memory_threshold : Int32? = nil,
      glossary_ids : Array(String)? = nil,
    ) : Array(TextResult)
      validate_text_glossary_ids(glossary_ids, source_lang, glossary_id, glossary_name)
      return mock_translate_text_response if auth_key_is_mock?

      if glossary_name
        glossary_id ||= find_multilingual_glossary_by_name(glossary_name).glossary_id
      end

      text = [text] if text.is_a?(String)

      params = {
        "text"                         => text,
        "target_lang"                  => target_lang,
        "source_lang"                  => source_lang,
        "formality"                    => formality,
        "glossary_id"                  => glossary_id,
        "glossary_ids"                 => glossary_ids,
        "context"                      => context,
        "enable_beta_languages"        => enable_beta_languages,
        "custom_instructions"          => custom_instructions,
        "show_billed_characters"       => show_billed_characters,
        "split_sentences"              => split_sentences,
        "preserve_formatting"          => preserve_formatting,
        "tag_handling"                 => tag_handling,
        "outline_detection"            => outline_detection,
        "non_splitting_tags"           => non_splitting_tags,
        "splitting_tags"               => splitting_tags,
        "ignore_tags"                  => ignore_tags,
        "model_type"                   => model_type,
        "style_id"                     => style_id,
        "tag_handling_version"         => tag_handling_version,
        "translation_memory_id"        => translation_memory_id,
        "translation_memory_threshold" => translation_memory_threshold,
      }.compact!

      response = with_transport_error do
        Crest.post(
          api_url_translate,
          form: params,
          headers: http_headers_json,
          json: true,
          handle_errors: false,
          max_redirects: 0,
        )
      end

      handle_response(response)
      parse_translate_text_response(response)
    end

    private def mock_translate_text_response : Array(TextResult)
      [TextResult.new("Protonenstrahl", "EN", nil, nil)]
    end

    private def validate_text_glossary_ids(
      glossary_ids : Array(String)?,
      source_lang,
      glossary_id,
      glossary_name,
    ) : Nil
      return unless glossary_ids

      raise ArgumentError.new("glossary_ids accepts at most 5 glossary IDs.") if glossary_ids.size > 5
      raise ArgumentError.new("source_lang is required when using glossary_ids.") unless source_lang
      if glossary_id || glossary_name
        raise ArgumentError.new("glossary_ids cannot be used with glossary_id or glossary_name.")
      end
    end

    private def parse_translate_text_response(response) : Array(TextResult)
      parsed_response = JSON.parse(response.body)
      parsed_response["translations"].as_a.map do |translation|
        TextResult.new(
          text: translation["text"].as_s,
          detected_source_language: translation["detected_source_language"].as_s,
          billed_characters: translation["billed_characters"]?.try &.as_i64,
          model_type_used: translation["model_type_used"]?.try &.as_s
        )
      end
    end
  end
end
