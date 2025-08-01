module DeepL
  class Translator
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
      entry_format = "tsv",
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

    def delete_glossary(glossary : GlossaryInfo) : Bool
      delete_glossary(glossary.glossary_id)
    end

    def delete_glossary(glossary_id : String) : Bool
      url = "#{server_url}/glossaries/#{glossary_id}"
      response = Crest.delete(url, headers: http_headers_base)
      handle_response(response, glossary: true)
      true
    end

    def delete_glossary_by_name(name : String) : Bool
      glossary_id = find_glossary_info_by_name(name).glossary_id
      delete_glossary(glossary_id)
      true
    end

    def get_glossary_info(glossary_id : String) : GlossaryInfo
      url = "#{server_url}/glossaries/#{glossary_id}"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response, glossary: true)
      GlossaryInfo.from_json(response.body)
    end

    # NOTE:
    # If multiple glossaries have the same name, the ID of the first matching
    # glossary is returned. (Expected to match the last glossary created,
    # but depends on DeepL API behavior)

    def find_glossary_info_by_name(name : String) : GlossaryInfo
      glossaries = list_glossaries
      glossary_info = glossaries.find { |g| g.name == name }
      raise GlossaryNameNotFoundError.new(name) unless glossary_info
      glossary_info
    end

    def get_glossary_info_by_name(name : String) : Array(GlossaryInfo)
      glossaries = list_glossaries
      glossaries.select { |g| g.name == name }
    end

    def list_glossaries : Array(GlossaryInfo)
      url = "#{server_url}/glossaries"
      response = Crest.get(url, headers: http_headers_base)
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
      url = "#{server_url}/glossaries/#{glossary_id}/entries"
      response = Crest.get(url, headers: header)
      handle_response(response, glossary: true)
      response.body # Do not parse because it is a TSV
    end

    def get_glossary_entries_by_name(name : String) : String
      glossary_id = find_glossary_info_by_name(name).glossary_id
      get_glossary_entries(glossary_id)
    end
  end
end
