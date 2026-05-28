require "json"

module DeepL
  class TranslationMemory
    include JSON::Serializable

    property translation_memory_id : String
    property name : String
    property source_language : String
    property target_languages : Array(String)
    property segment_count : Int64

    def initialize(
      @translation_memory_id,
      @name,
      @source_language,
      @target_languages,
      @segment_count,
    )
    end
  end

  class TranslationMemoryList
    include JSON::Serializable

    property translation_memories : Array(TranslationMemory)
    property total_count : Int32?

    def initialize(@translation_memories, @total_count = nil)
    end
  end

  class Translator
    def list_translation_memories(
      page : Int32? = nil,
      page_size : Int32? = nil,
    ) : TranslationMemoryList
      url = "#{base_server_url}/v3/translation_memories"
      params = {
        "page"      => page,
        "page_size" => page_size,
      }.compact!

      response = Crest.get(url, params: params, headers: http_headers_base)
      handle_response(response)
      TranslationMemoryList.from_json(response.body)
    end
  end
end
