require "./glossary_info"
require "./glossary_language_pair"

module DeepL
  @[Deprecated("Use V3 MultilingualGlossaryInfo instead")]
  class Translator
    # ameba:disable Naming/AccessorMethodName
    def get_glossary_language_pairs : Array(GlossaryLanguagePair)
      url = api_url("/v2/glossary-language-pairs")
      response = with_transport_error do
        Crest.get(
          url,
          headers: http_headers_base,
          handle_errors: false,
          max_redirects: 0,
        )
      end
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
      entry_format = "tsv",
    ) : GlossaryInfo
      url = api_url("/v2/glossaries")
      data = {
        "name"           => name,
        "source_lang"    => source_lang,
        "target_lang"    => target_lang,
        "entries"        => entries,
        "entries_format" => entry_format,
      }
      response = with_transport_error do
        Crest.post(
          url,
          form: data,
          headers: http_headers_json,
          handle_errors: false,
          max_redirects: 0,
        )
      end
      handle_response(response, glossary: true)
      GlossaryInfo.from_json(response.body)
    end

    def delete_glossary(glossary : GlossaryInfo) : Bool
      delete_glossary(glossary.glossary_id)
    end

    def delete_glossary(glossary_id : String) : Bool
      url = api_url("/v2/glossaries/#{glossary_id}")
      response = with_transport_error do
        Crest.delete(
          url,
          headers: http_headers_base,
          handle_errors: false,
          max_redirects: 0,
        )
      end
      handle_response(response, glossary: true)
      true
    end

    def delete_glossary_by_name(name : String) : Bool
      glossary_id = find_glossary_info_by_name(name).glossary_id
      delete_glossary(glossary_id)
      true
    end

    def get_glossary_info(glossary_id : String) : GlossaryInfo
      url = api_url("/v2/glossaries/#{glossary_id}")
      response = with_transport_error do
        Crest.get(
          url,
          headers: http_headers_base,
          handle_errors: false,
          max_redirects: 0,
        )
      end
      handle_response(response, glossary: true)
      GlossaryInfo.from_json(response.body)
    end

    # Resolve a glossary name only when it identifies exactly one glossary.
    def find_glossary_info_by_name(name : String) : GlossaryInfo
      glossaries = get_glossary_info_by_name(name)
      case glossaries.size
      when 0
        raise GlossaryNameNotFoundError.new(name)
      when 1
        glossaries.first
      else
        raise AmbiguousGlossaryNameError.new(name)
      end
    end

    def get_glossary_info_by_name(name : String) : Array(GlossaryInfo)
      glossaries = list_glossaries
      glossaries.select { |glossary| glossary.name == name }
    end

    def list_glossaries : Array(GlossaryInfo)
      url = api_url("/v2/glossaries")
      response = with_transport_error do
        Crest.get(
          url,
          headers: http_headers_base,
          handle_errors: false,
          max_redirects: 0,
        )
      end
      handle_response(response, glossary: true)
      glossaries_json = JSON.parse(response.body)["glossaries"].to_json
      Array(GlossaryInfo).from_json(glossaries_json)
    end

    def get_glossary_entries(glossary : GlossaryInfo) : String
      get_glossary_entries(glossary.glossary_id)
    end

    def get_glossary_entries(glossary_id : String) : String
      header = http_headers_base
      header["Accept"] = "text/tab-separated-values"
      url = api_url("/v2/glossaries/#{glossary_id}/entries")
      response = with_transport_error do
        Crest.get(
          url,
          headers: header,
          handle_errors: false,
          max_redirects: 0,
        )
      end
      handle_response(response, glossary: true)
      response.body # Do not parse because it is a TSV
    end

    def get_glossary_entries_by_name(name : String) : String
      glossary_id = find_glossary_info_by_name(name).glossary_id
      get_glossary_entries(glossary_id)
    end
  end
end
