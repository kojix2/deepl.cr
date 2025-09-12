require "./multilingual_glossary_info"
require "./glossary_dictionary"
require "./glossary_entries_information"
require "./multilingual_glossary_language_pair"

module DeepL
  class Translator
    # Get supported language pairs for multilingual glossaries
    def get_multilingual_glossary_language_pairs : Array(MultilingualGlossaryLanguagePair)
      url = "#{base_server_url}/v3/glossary-language-pairs"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response, glossary: true)
      Array(MultilingualGlossaryLanguagePair).from_json(
        JSON.parse(response.body)["supported_languages"].to_json
      )
    end

    # Create a multilingual glossary with specified name and dictionaries
    def create_multilingual_glossary(
      name : String,
      dictionaries : Array(GlossaryDictionary),
    ) : MultilingualGlossaryInfo
      url = "#{base_server_url}/v3/glossaries"

      # Convert GlossaryDictionary objects to the expected API format
      dict_data = dictionaries.map do |dict|
        {
          "source_lang"    => dict.source_lang,
          "target_lang"    => dict.target_lang,
          "entries"        => dict.entries,
          "entries_format" => dict.entries_format || "tsv",
        }
      end

      data = {
        "name"         => name,
        "dictionaries" => dict_data,
      }

      response = Crest.post(url, json: data, headers: http_headers_json)
      handle_response(response, glossary: true)
      MultilingualGlossaryInfo.from_json(response.body)
    end

    # List all multilingual glossaries and their meta-information
    def list_multilingual_glossaries : Array(MultilingualGlossaryInfo)
      url = "#{base_server_url}/v3/glossaries"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response, glossary: true)
      glossaries_json = JSON.parse(response.body)["glossaries"].to_json
      Array(MultilingualGlossaryInfo).from_json(glossaries_json)
    end

    # Get multilingual glossary details by ID
    def get_multilingual_glossary(glossary_id : String) : MultilingualGlossaryInfo
      url = "#{base_server_url}/v3/glossaries/#{glossary_id}"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response, glossary: true)
      MultilingualGlossaryInfo.from_json(response.body)
    end

    # Delete a multilingual glossary by ID
    def delete_multilingual_glossary(glossary_id : String) : Bool
      url = "#{base_server_url}/v3/glossaries/#{glossary_id}"
      response = Crest.delete(url, headers: http_headers_base)
      handle_response(response, glossary: true)
      true
    end

    # Edit glossary details (name or dictionaries)
    def patch_multilingual_glossary(
      glossary_id : String,
      name : String? = nil,
      dictionaries : Array(GlossaryDictionary)? = nil,
    ) : MultilingualGlossaryInfo
      url = "#{base_server_url}/v3/glossaries/#{glossary_id}"

      data = {} of String => JSON::Any::Type
      data["name"] = name if name

      if dictionaries
        # Convert GlossaryDictionary objects to the expected API format
        dict_data = dictionaries.map do |dict|
          {
            "source_lang"    => dict.source_lang,
            "target_lang"    => dict.target_lang,
            "entries"        => dict.entries,
            "entries_format" => dict.entries_format || "tsv",
          }
        end
        data["dictionaries"] = dict_data
      end

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
      url = "#{base_server_url}/v3/glossaries/#{glossary_id}/entries"
      params = {
        "source_lang" => source_lang,
        "target_lang" => target_lang,
      }

      response = Crest.get(url, params: params, headers: http_headers_base)
      handle_response(response, glossary: true)
      GlossaryDictionary.from_json(response.body)
    end

    # Replace or create a dictionary in the glossary
    def put_multilingual_glossary_dictionary(
      glossary_id : String,
      source_lang : String,
      target_lang : String,
      entries : String,
      entries_format : String = "tsv",
    ) : GlossaryEntriesInformation
      url = "#{base_server_url}/v3/glossaries/#{glossary_id}/dictionaries"

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
      url = "#{base_server_url}/v3/glossaries/#{glossary_id}/dictionaries"
      params = {
        "source_lang" => source_lang,
        "target_lang" => target_lang,
      }

      response = Crest.delete(url, params: params, headers: http_headers_base)
      handle_response(response, glossary: true)
      true
    end

    # Delete a multilingual glossary (convenience method)
    def delete_multilingual_glossary(glossary : MultilingualGlossaryInfo) : Bool
      delete_multilingual_glossary(glossary.glossary_id)
    end

    # Get glossary entries (convenience method)
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
