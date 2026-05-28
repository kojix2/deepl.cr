require "./spec_helper"

describe DeepL::ApiKey do
  sample_json = %({
    "key_id": "ca7d5694-96eb-4263-a9a4-7f7e4211529e:20c2abcf-4c3c-4cd6-8ae8-8bd2a7d4da38",
    "label": "developer key prod",
    "creation_time": "2025-07-08T08:15:29.362Z",
    "deactivated_time": null,
    "is_deactivated": false,
    "usage_limits": {
      "characters": 5000,
      "speech_to_text_milliseconds": 3600000
    }
  })

  it "can be deserialized from JSON" do
    api_key = DeepL::ApiKey.from_json(sample_json)

    api_key.key_id.should eq("ca7d5694-96eb-4263-a9a4-7f7e4211529e:20c2abcf-4c3c-4cd6-8ae8-8bd2a7d4da38")
    api_key.label.should eq("developer key prod")
    api_key.creation_time.should eq(Time.parse_iso8601("2025-07-08T08:15:29.362Z"))
    api_key.deactivated_time.should be_nil
    api_key.is_deactivated.should be_false
    if usage_limits = api_key.usage_limits
      usage_limits.characters.should eq(5000)
      usage_limits.speech_to_text_milliseconds.should eq(3600000)
    else
      fail "expected usage limits"
    end
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
        "speech_to_text_minutes": 107.46
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
            "speech_to_text_minutes": 11.94
          }
        }
      ]
    }
  })

  it "can be deserialized from JSON" do
    report = DeepL::AdminUsageReport.from_json(sample_json)

    report.usage_report.group_by.should eq("key_and_day")
    report.usage_report.total_usage.total_characters.should eq(9619)
    report.usage_report.total_usage.speech_to_text_minutes.should eq(107.46)
    if key_and_day_usages = report.usage_report.key_and_day_usages
      key_and_day_usages.size.should eq(1)
      key_and_day_usages.first.api_key.should eq("dc88****3a2c")
      key_and_day_usages.first.usage.total_characters.should eq(315)
      key_and_day_usages.first.usage.speech_to_text_minutes.should eq(11.94)
    else
      fail "expected key and day usages"
    end
  end
end

describe DeepL::CustomTagUsageReport do
  sample_json = %({
    "custom_tag_usage_report": {
      "aggregate_by": "day",
      "start_date": "2026-05-03T00:00:00Z",
      "end_date": "2026-05-05T00:00:00Z",
      "next_page": null,
      "usage": [
        {
          "custom_tag": "example-custom-tag",
          "usage_date": "2026-05-04T00:00:00Z",
          "breakdown": {
            "total_characters": 380,
            "text_translation_characters": 380,
            "text_improvement_characters": 0
          }
        }
      ]
    }
  })

  it "can be deserialized from JSON" do
    report = DeepL::CustomTagUsageReport.from_json(sample_json)

    report.custom_tag_usage_report.aggregate_by.should eq("day")
    report.custom_tag_usage_report.usage.size.should eq(1)
    report.custom_tag_usage_report.usage.first.custom_tag.should eq("example-custom-tag")
    report.custom_tag_usage_report.usage.first.breakdown.total_characters.should eq(380)
  end
end
