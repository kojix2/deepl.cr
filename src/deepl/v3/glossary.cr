require "./multilingual_glossary_info"
require "./glossary_dictionary"
require "./glossary_entries_information"
require "./glossary_language_pair"

module DeepL
  class Translator
    # Create a multilingual glossary
    def create_multilingual_glossary(
      name : String,
      dictionaries : Array(Hash(String, String)),
    ) : MultilingualGlossaryInfo
      url = "#{server_url}/v3/glossaries"

      data = {
        "name"         => name,
        "dictionaries" => dictionaries,
      }

      response = Crest.post(url, json: data, headers: http_headers_json)
      handle_response(response, glossary: true)
      MultilingualGlossaryInfo.from_json(response.body)
    end

    # List all multilingual glossaries
    def list_multilingual_glossaries : Array(MultilingualGlossaryInfo)
      url = "#{server_url}/v3/glossaries"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response, glossary: true)
      glossaries_json = JSON.parse(response.body)["glossaries"].to_json
      Array(MultilingualGlossaryInfo).from_json(glossaries_json)
    end

    # Get multilingual glossary details
    def get_multilingual_glossary(glossary_id : String) : MultilingualGlossaryInfo
      url = "#{server_url}/v3/glossaries/#{glossary_id}"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response, glossary: true)
      MultilingualGlossaryInfo.from_json(response.body)
    end

    # Delete a multilingual glossary
    def delete_multilingual_glossary(glossary_id : String) : Bool
      url = "#{server_url}/v3/glossaries/#{glossary_id}"
      response = Crest.delete(url, headers: http_headers_base)
      handle_response(response, glossary: true)
      true
    end

    # Edit glossary details (PATCH)
    def patch_multilingual_glossary(
      glossary_id : String,
      name : String? = nil,
      dictionaries : Array(Hash(String, String))? = nil,
    ) : MultilingualGlossaryInfo
      url = "#{server_url}/v3/glossaries/#{glossary_id}"

      data = {} of String => JSON::Any::Type
      data["name"] = name if name
      data["dictionaries"] = dictionaries if dictionaries

      response = Crest.patch(url, json: data, headers: http_headers_json)
      handle_response(response, glossary: true)
      MultilingualGlossaryInfo.from_json(response.body)
    end

    # Get glossary entries for specific language pair
    def get_multilingual_glossary_entries(
      glossary_id : String,
      source_lang : String,
      target_lang : String,
    ) : GlossaryDictionary
      url = "#{server_url}/v3/glossaries/#{glossary_id}/entries"
      params = {
        "source_lang" => source_lang,
        "target_lang" => target_lang,
      }

      response = Crest.get(url, params: params, headers: http_headers_base)
      handle_response(response, glossary: true)
      GlossaryDictionary.from_json(response.body)
    end

    # Replace or create a dictionary in the glossary (PUT)
    def put_multilingual_glossary_dictionary(
      glossary_id : String,
      source_lang : String,
      target_lang : String,
      entries : String,
      entries_format : String = "tsv",
    ) : GlossaryEntriesInformation
      url = "#{server_url}/v3/glossaries/#{glossary_id}/dictionaries"

      data = {
        "source_lang"    => source_lang,
        "target_lang"    => target_lang,
        "entries"        => entries,
        "entries_format" => entries_format,
      }

      response = Crest.put(url, json: data, headers: http_headers_json)
      handle_response(response, glossary: true)
      GlossaryEntriesInformation.from_json(response.body)
    end

    # Delete a dictionary from the glossary
    def delete_multilingual_glossary_dictionary(
      glossary_id : String,
      source_lang : String,
      target_lang : String,
    ) : Bool
      url = "#{server_url}/v3/glossaries/#{glossary_id}/dictionaries"
      params = {
        "source_lang" => source_lang,
        "target_lang" => target_lang,
      }

      response = Crest.delete(url, params: params, headers: http_headers_base)
      handle_response(response, glossary: true)
      true
    end

    # Convenience methods with MultilingualGlossaryInfo objects
    def delete_multilingual_glossary(glossary : MultilingualGlossaryInfo) : Bool
      delete_multilingual_glossary(glossary.glossary_id)
    end

    def get_multilingual_glossary_entries(
      glossary : MultilingualGlossaryInfo,
      source_lang : String,
      target_lang : String,
    ) : GlossaryDictionary
      get_multilingual_glossary_entries(glossary.glossary_id, source_lang, target_lang)
    end

    # Find multilingual glossary by name
    def find_multilingual_glossary_by_name(name : String) : MultilingualGlossaryInfo
      glossaries = list_multilingual_glossaries
      glossary = glossaries.find { |g| g.name == name }
      raise GlossaryNameNotFoundError.new(name) unless glossary
      glossary
    end

    # Get multilingual glossaries by name (multiple matches possible)
    def get_multilingual_glossaries_by_name(name : String) : Array(MultilingualGlossaryInfo)
      glossaries = list_multilingual_glossaries
      glossaries.select { |g| g.name == name }
    end
  end
end
