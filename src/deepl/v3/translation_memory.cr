require "json"

module DeepL
  class TranslationMemory
    include JSON::Serializable

    property translation_memory_id : String
    property name : String
    property source_language : String
    property target_languages : Array(String)
    property segment_count : Int64
    property creation_time : Time?
    property updated_time : Time?

    def initialize(
      @translation_memory_id,
      @name,
      @source_language,
      @target_languages,
      @segment_count,
      @creation_time = nil,
      @updated_time = nil,
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

  class TranslationMemoryTargetSegment
    include JSON::Serializable

    property target_segment_id : String
    property target_language : String
    property target_text : String
    property creation_time : Time?
    property updated_time : Time?
    property last_used_time : Time?

    def initialize(
      @target_segment_id,
      @target_language,
      @target_text,
      @creation_time = nil,
      @updated_time = nil,
      @last_used_time = nil,
    )
    end
  end

  class TranslationMemorySegment
    include JSON::Serializable

    property source_segment_id : String
    property source_text : String
    property targets : Array(TranslationMemoryTargetSegment)
    property creation_time : Time?
    property updated_time : Time?
    property last_used_time : Time?

    def initialize(
      @source_segment_id,
      @source_text,
      @targets,
      @creation_time = nil,
      @updated_time = nil,
      @last_used_time = nil,
    )
    end
  end

  class TranslationMemorySegmentList
    include JSON::Serializable

    property segments : Array(TranslationMemorySegment)
    property segment_count : Int64
    property next_page_cursor : String?

    def initialize(@segments, @segment_count, @next_page_cursor = nil)
    end
  end

  class Translator
    def list_translation_memories(
      page : Int32? = nil,
      page_size : Int32? = nil,
    ) : TranslationMemoryList
      url = api_url("/v3/translation_memories")
      params = {
        "page"      => page,
        "page_size" => page_size,
      }.compact!

      response = with_transport_error do
        Crest.get(
          url,
          params: params,
          headers: http_headers_base,
          handle_errors: false,
          max_redirects: 0,
        )
      end
      handle_response(response)
      TranslationMemoryList.from_json(response.body)
    end

    def get_translation_memory(translation_memory_id : String) : TranslationMemory
      url = api_url("/v3/translation_memories/#{translation_memory_id}")
      response = with_transport_error do
        Crest.get(
          url,
          headers: http_headers_base,
          handle_errors: false,
          max_redirects: 0,
        )
      end
      handle_response(response)
      TranslationMemory.from_json(response.body)
    end

    def list_translation_memory_segments(
      translation_memory_id : String,
      page_size : Int32? = nil,
      page_cursor : String? = nil,
      filter_text : String? = nil,
      filter_case_sensitive : Bool? = nil,
    ) : TranslationMemorySegmentList
      url = api_url("/v3/translation_memories/#{translation_memory_id}/segments")
      params = {
        "page_size"             => page_size,
        "page_cursor"           => page_cursor,
        "filter_text"           => filter_text,
        "filter_case_sensitive" => filter_case_sensitive,
      }.compact!

      response = with_transport_error do
        Crest.get(
          url,
          params: params,
          headers: http_headers_base,
          handle_errors: false,
          max_redirects: 0,
        )
      end
      handle_response(response)
      TranslationMemorySegmentList.from_json(response.body)
    end
  end
end
