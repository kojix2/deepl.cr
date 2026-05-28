require "./spec_helper"

{% unless flag?(:deepl_v2) %}
  describe DeepL::TranslationMemoryList do
    sample_json = %({
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
    })

    it "can be deserialized from JSON" do
      list = DeepL::TranslationMemoryList.from_json(sample_json)

      list.total_count.should eq(1)
      list.translation_memories.size.should eq(1)
      list.translation_memories.first.translation_memory_id.should eq("a74d88fb-ed2a-4943-a664-a4512398b994")
      list.translation_memories.first.target_languages.should eq(["es", "de"])
      list.translation_memories.first.segment_count.should eq(3542)
    end
  end
{% end %}
