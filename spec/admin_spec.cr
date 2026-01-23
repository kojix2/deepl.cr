require "./spec_helper"

describe DeepL::ApiKey do
  sample_json = %({
    "key_id": "ca7d5694-96eb-4263-a9a4-7f7e4211529e:20c2abcf-4c3c-4cd6-8ae8-8bd2a7d4da38",
    "label": "developer key prod",
    "creation_time": "2025-07-08T08:15:29.362Z",
    "deactivated_time": null,
    "is_deactivated": false,
    "usage_limits": {
      "characters": 5000
    }
  })

  it "can be deserialized from JSON" do
    api_key = DeepL::ApiKey.from_json(sample_json)

    api_key.key_id.should eq("ca7d5694-96eb-4263-a9a4-7f7e4211529e:20c2abcf-4c3c-4cd6-8ae8-8bd2a7d4da38")
    api_key.label.should eq("developer key prod")
    api_key.creation_time.should eq(Time.parse_iso8601("2025-07-08T08:15:29.362Z"))
    api_key.deactivated_time.should be_nil
    api_key.is_deactivated.should be_false
    api_key.usage_limits.not_nil!.characters.should eq(5000)
  end
end

describe DeepL::AdminUsageReport do
  sample_json = %({
    "usage_report": {
      "total_usage": {
        "total_characters": 9619,
        "text_translation_characters": 4892,
        "document_translation_characters": 0,
        "text_improvement_characters": 4727,
        "speech_to_text_milliseconds": 1800000
      },
      "group_by": "key_and_day",
      "start_date": "2025-09-29T00:00:00Z",
      "end_date": "2025-10-01T00:00:00Z",
      "key_and_day_usages": [
        {
          "api_key": "dc88****3a2c",
          "api_key_label": "Staging API Key",
          "usage_date": "2025-09-29T00:00:00Z",
          "usage": {
            "total_characters": 315,
            "text_translation_characters": 159,
            "document_translation_characters": 0,
            "text_improvement_characters": 156,
            "speech_to_text_milliseconds": 1800000
          }
        }
      ]
    }
  })

  it "can be deserialized from JSON" do
    report = DeepL::AdminUsageReport.from_json(sample_json)

    report.usage_report.group_by.should eq("key_and_day")
    report.usage_report.total_usage.total_characters.should eq(9619)
    report.usage_report.key_and_day_usages.not_nil!.size.should eq(1)
    report.usage_report.key_and_day_usages.not_nil!.first.api_key.should eq("dc88****3a2c")
    report.usage_report.key_and_day_usages.not_nil!.first.usage.total_characters.should eq(315)
  end
end
