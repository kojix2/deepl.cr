require "./spec_helper"
require "./support/recording_server"

describe DeepL::TranslationMemoryList do
  sample_json = <<-JSON
    {
      "translation_memories": [
        {
          "translation_memory_id": "a74d88fb-ed2a-4943-a664-a4512398b994",
          "name": "Legal",
          "source_language": "en",
          "target_languages": ["es", "de"],
          "segment_count": 3542
        }
      ],
      "total_count": 1
    }
    JSON

  it "can be deserialized from JSON" do
    list = DeepL::TranslationMemoryList.from_json(sample_json)

    list.total_count.should eq(1)
    list.translation_memories.size.should eq(1)
    list.translation_memories.first.translation_memory_id.should eq("a74d88fb-ed2a-4943-a664-a4512398b994")
    list.translation_memories.first.target_languages.should eq(["es", "de"])
    list.translation_memories.first.segment_count.should eq(3542)
  end
end

describe "translation memory endpoints" do
  it "retrieves a translation memory" do
    body = <<-JSON
      {
        "translation_memory_id": "memory-id",
        "name": "Legal",
        "source_language": "en",
        "target_languages": ["de"],
        "segment_count": 12,
        "creation_time": "2026-04-01T16:34:25.223Z",
        "updated_time": "2026-08-06T09:12:44.108Z"
      }
      JSON
    server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(
        200,
        body: body,
        headers: {"Content-Type" => "application/json"}
      ),
    ])

    begin
      translator = DeepL::Translator.new("translation-memory-test-key", nil, server.url)
      memory = translator.get_translation_memory("memory-id")

      memory.name.should eq("Legal")
      memory.segment_count.should eq(12)
      memory.creation_time.should eq(Time.parse_iso8601("2026-04-01T16:34:25.223Z"))
      memory.updated_time.should eq(Time.parse_iso8601("2026-08-06T09:12:44.108Z"))
      server.requests.map(&.resource).should eq(["/v3/translation_memories/memory-id"])
    ensure
      server.close
    end
  end

  it "lists cursor-paginated translation memory segments" do
    body = <<-JSON
      {
        "segments": [
          {
            "source_segment_id": "source-id",
            "source_text": "This agreement applies.",
            "creation_time": "2026-04-01T16:34:25.223Z",
            "updated_time": "2026-04-02T16:34:25.223Z",
            "last_used_time": "2026-08-05T11:02:18.771Z",
            "targets": [
              {
                "target_segment_id": "target-id",
                "target_language": "de",
                "target_text": "Diese Vereinbarung gilt.",
                "creation_time": "2026-04-01T16:34:25.223Z",
                "updated_time": "2026-04-02T16:34:25.223Z",
                "last_used_time": "2026-08-05T11:02:18.771Z"
              }
            ]
          }
        ],
        "segment_count": 3542,
        "next_page_cursor": "next-cursor"
      }
      JSON
    server = RecordingServer.new([
      RecordingServer::ScriptedResponse.new(
        200,
        body: body,
        headers: {"Content-Type" => "application/json"}
      ),
    ])

    begin
      translator = DeepL::Translator.new("translation-memory-test-key", nil, server.url)
      result = translator.list_translation_memory_segments(
        "memory-id",
        page_size: 25,
        page_cursor: "previous-cursor",
        filter_text: "agreement",
        filter_case_sensitive: true,
      )

      result.segment_count.should eq(3542)
      result.next_page_cursor.should eq("next-cursor")
      result.segments.first.source_text.should eq("This agreement applies.")
      result.segments.first.last_used_time.should eq(Time.parse_iso8601("2026-08-05T11:02:18.771Z"))
      target = result.segments.first.targets.first
      target.target_language.should eq("de")
      target.target_text.should eq("Diese Vereinbarung gilt.")
      target.last_used_time.should eq(Time.parse_iso8601("2026-08-05T11:02:18.771Z"))
      server.requests.map(&.resource).should eq([
        "/v3/translation_memories/memory-id/segments?page_size=25&page_cursor=previous-cursor&filter_text=agreement&filter_case_sensitive=true",
      ])
    ensure
      server.close
    end
  end
end
