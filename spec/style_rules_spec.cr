require "./spec_helper"

describe DeepL::StyleRuleList do
  sample_json = <<-JSON
    {
      "style_id": "bd0a38f3-1831-440b-a8dd-2c702e2325ab",
      "name": "My Style Rules",
      "creation_time": "2025-01-01T00:00:00Z",
      "updated_time": "2025-01-02T00:00:00Z",
      "language": "en",
      "version": 13,
      "configured_rules": {
        "dates_and_times": {
          "date_format": "use_dd_slash_mm_slash_yyyy"
        },
        "punctuation": {
          "apostrophe": "use_curly_apostrophes"
        }
      },
      "custom_instructions": [
        {
          "label": "Currency",
          "prompt": "Use currency symbol before number",
          "source_language": "en",
          "id": "68fdb803-c013-4e67-b62e-1aad0ab519cd"
        }
      ]
    }
    JSON

  it "can be deserialized from JSON" do
    style_rule = DeepL::StyleRuleList.from_json(sample_json)

    style_rule.style_id.should eq("bd0a38f3-1831-440b-a8dd-2c702e2325ab")
    style_rule.name.should eq("My Style Rules")
    style_rule.language.should eq("en")
    style_rule.version.should eq(13)
    style_rule.creation_time.should eq(Time.parse_iso8601("2025-01-01T00:00:00Z"))
    style_rule.updated_time.should eq(Time.parse_iso8601("2025-01-02T00:00:00Z"))

    configured_rules = style_rule.configured_rules || raise "configured_rules should be present"
    configured_rules.as_h["dates_and_times"].as_h["date_format"].as_s.should eq("use_dd_slash_mm_slash_yyyy")
    custom_instructions = style_rule.custom_instructions || raise "custom_instructions should be present"
    custom_instructions.size.should eq(1)
    custom_instructions.first.label.should eq("Currency")
    custom_instructions.first.id.should eq("68fdb803-c013-4e67-b62e-1aad0ab519cd")
  end

  it "round-trips object-shaped configured rules" do
    style_rule = DeepL::StyleRuleList.from_json(sample_json)
    round_tripped = DeepL::StyleRuleList.from_json(style_rule.to_json)
    configured_rules = round_tripped.configured_rules || raise "configured_rules should be present"

    configured_rules.as_h["dates_and_times"].as_h["date_format"].as_s.should eq("use_dd_slash_mm_slash_yyyy")
    configured_rules.as_h["punctuation"].as_h["apostrophe"].as_s.should eq("use_curly_apostrophes")
  end

  it "can deserialize a list of style rules" do
    list_json = "[#{sample_json}]"

    list = Array(DeepL::StyleRuleList).from_json(list_json)
    list.size.should eq(1)
    list.first.name.should eq("My Style Rules")
  end
end
